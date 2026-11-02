import AppKit

/// `arma settings`, run in the app: each setting through the stores and core
/// intents Settings binds, and the browser-data file through the core's
/// export and archive reading that Settings › Advanced uses.
extension TerminalSettingsCommand {
    // MARK: - Types

    private struct SettingRow: Encodable {
        let key: String
        let title: String
        let value: String
        let allowed: [String]
        let defaultValue: String?
        let location: String
        let space: String?

        private enum CodingKeys: String, CodingKey {
            case key, title, value, allowed, location, space
            case defaultValue = "default"
        }
    }

    private struct SettingChange: Encodable {
        let key: String
        let from: String
        let to: String
        let space: String?
    }

    private struct ExportResult: Encodable {
        let path: String
        let format: String
        let bytes: Int
    }

    private struct ImportResult: Encodable {
        let spaces: Int
        let tabs: Int
        let history: Int
    }

    private typealias Refusal = BrowserMacTerminal.Refusal
    private typealias Setting = BrowserTerminalSetting

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) async throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        switch self {
        case .list(let section, let space):
            return try list(section: section, space: space, in: terminal)
        case .get(let key, let space):
            let (setting, target) = try Self.resolve(key, space: space, in: terminal)
            let row = Self.row(setting, target)
            return TerminalOutput(text: row.value, value: row)
        case .set(let key, let value, let space):
            let (setting, target) = try Self.resolve(key, space: space, in: terminal)
            return try Self.change(setting, to: value, in: target)
        case .reset(let key, let space):
            let (setting, target) = try Self.resolve(key, space: space, in: terminal)
            guard let name = setting.defaultName(target) else {
                throw Refusal("\(setting.key) has no default to go back to. Set it with arma settings set.")
            }
            return try Self.change(setting, to: name, in: target)
        case .export(let path, let format, let replaces):
            return try await export(to: path, format: format, replaces: replaces, in: terminal)
        case .importFile(let path, let confirmed):
            guard confirmed else { throw Refusal("Add --yes to import.") }
            return try await importArchive(at: path, in: terminal)
        }
    }

    // MARK: - Actions - Settings

    /// The setting `key` names and what it acts on: its Space for a
    /// per-Space setting, the one `--space` names for another.
    @MainActor
    private static func resolve(_ key: String, space name: String?, in terminal: BrowserMacTerminal)
        throws(Refusal) -> (Setting, Setting.Target)
    {
        guard let setting = Setting.named(key) else {
            throw Refusal("There is no setting '\(key)'. Run arma settings list.")
        }
        var space: SpaceModel?
        if setting.isPerSpace || name != nil { space = try terminal.unlocked(try terminal.space(name)) }
        return (setting, Setting.Target(terminal: terminal, space: space))
    }

    @MainActor
    private static func row(_ setting: Setting, _ target: Setting.Target) -> SettingRow {
        SettingRow(
            key: setting.key, title: setting.title, value: setting.read(target), allowed: setting.allowed(target),
            defaultValue: setting.defaultName(target), location: "Settings › " + setting.location,
            space: setting.isPerSpace ? target.space?.settings.name : nil)
    }

    /// Sets `setting` to the value `word` names, and refuses when the core
    /// kept the value it had.
    @MainActor
    private static func change(_ setting: Setting, to word: String, in target: Setting.Target)
        throws(Refusal) -> TerminalOutput
    {
        let before = setting.read(target)
        let wanted = try setting.write(target, word)
        let after = setting.read(target)
        guard after == wanted else {
            throw Refusal("Arma kept \(setting.key) at \(after).")
        }
        let space = setting.isPerSpace ? target.space?.settings.name : nil
        let change = SettingChange(key: setting.key, from: before, to: after, space: space)
        let scope = space.map { " in \($0)" } ?? ""
        let text =
            before == after
            ? "\(setting.key) is already \(after)\(scope)." : "\(setting.key): \(before) → \(after)\(scope)."
        return TerminalOutput(text: text, value: change)
    }

    @MainActor
    private func list(section: String?, space name: String?, in terminal: BrowserMacTerminal) throws(Refusal)
        -> TerminalOutput
    {
        let wanted = section?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let settings = Setting.all.filter { setting in
            guard let wanted, !wanted.isEmpty else { return true }
            return setting.key == wanted || setting.key.hasPrefix(wanted + ".")
        }
        guard !settings.isEmpty else {
            let sections = Setting.all.map(\.section).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            throw Refusal(
                "There is no section '\(section ?? "")'. The sections are \(sections.joined(separator: ", ")).")
        }
        // A per-Space setting reads a Space: the one named, else the front
        // window's. Listing everything leaves them out when there is none.
        var space: SpaceModel?
        var note: String?
        if settings.contains(where: \.isPerSpace) {
            do throws(Refusal) {
                space = try terminal.unlocked(try terminal.space(name))
            } catch {
                guard name == nil, settings.contains(where: { !$0.isPerSpace }) else { throw error }
                note = "Space settings are left out: \(error.message)"
            }
        }
        let rows = settings.compactMap { setting -> SettingRow? in
            guard !setting.isPerSpace || space != nil else { return nil }
            return Self.row(setting, Setting.Target(terminal: terminal, space: setting.isPerSpace ? space : nil))
        }
        var text = BrowserMacTerminal.table(
            ["KEY", "VALUE", "ALLOWED", "LOCATION"],
            rows.map { row in
                [
                    row.key, row.value, row.allowed.joined(separator: "|"),
                    row.location + (row.space.map { " (\($0))" } ?? ""),
                ]
            })
        if let space, rows.contains(where: { $0.space != nil }) {
            text += "\n\nspace.* settings are \(space.settings.name)'s; name another with --space."
        }
        if let note { text += "\n\n" + note }
        return TerminalOutput(text: text, value: ["settings": rows])
    }

    // MARK: - Actions - Browser data

    /// Writes the workspace's `format` file to `path`, as Export in
    /// Settings › Advanced does. A locked Space keeps it from being written.
    @MainActor
    private func export(to path: String, format: TerminalExportFormat, replaces: Bool, in terminal: BrowserMacTerminal)
        async throws(Refusal) -> TerminalOutput
    {
        let browser = terminal.browser
        let locked = (browser.workspaceModel?.spaces.models ?? []).filter(terminal.application.spaceAccess.isLocked)
        guard locked.isEmpty else {
            let names = locked.map { "'\($0.settings.name)'" }.joined(separator: ", ")
            throw Refusal("Unlock \(names) in Arma first; a locked Space keeps the export from being written.")
        }
        guard let exportFormat = ExportFormat.all.first(where: { Setting.kebab($0.name) == format.rawValue }) else {
            throw Refusal("Arma cannot export \(format.rawValue).")
        }
        guard replaces || !FileManager.default.fileExists(atPath: path) else {
            throw Refusal("\(path) already exists. Add --force to replace it.")
        }
        let core = browser.core
        let query = ExportWorkspace(workspaceID: browser.family.workspaceID, format: exportFormat)
        let document: ExportedDocument
        do {
            document = try await Task.detached(priority: .userInitiated) { try core.query(query) }.value
        } catch {
            throw Refusal(error.personFacingDescription)
        }
        do {
            try document.contents.write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
            throw Refusal("Arma could not write \(path): \(error.localizedDescription)")
        }
        let result = ExportResult(path: path, format: format.rawValue, bytes: document.contents.count)
        return TerminalOutput(text: "\(String(localized: exportFormat.savedMessage)) \(path)", value: result)
    }

    /// Adds the Spaces, tabs and history of the browser-data file at `path`
    /// after this workspace's own, as Import in Settings › Advanced does.
    @MainActor
    private func importArchive(at path: String, in terminal: BrowserMacTerminal) async throws(Refusal)
        -> TerminalOutput
    {
        guard FileManager.default.isReadableFile(atPath: path) else { throw Refusal("Arma cannot read \(path).") }
        let browser = terminal.browser
        let core = browser.core
        let imported: ImportedSpaces
        do {
            imported = try await Task.detached(priority: .userInitiated) { try core.query(ReadArchive(path: path)) }
                .value
        } catch {
            throw Refusal(error.personFacingDescription)
        }
        do {
            try browser.importSpaces(imported.spaces)
        } catch {
            throw Refusal(error.explanation)
        }
        let result = ImportResult(
            spaces: imported.spaces.count, tabs: imported.spaces.reduce(0) { $0 + $1.tabs.count },
            history: imported.spaces.reduce(0) { $0 + $1.history.count })
        return TerminalOutput(
            text: "Imported \(result.spaces) Spaces, \(result.tabs) tabs and \(result.history) history entries.",
            value: result)
    }
}
