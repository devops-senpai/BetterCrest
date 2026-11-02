import AppKit

/// `arma extension`, run in the app: Chromium's extensions through the
/// engine's own per-Space store and install review, Servo's through the
/// add-on store its settings section uses.
extension TerminalExtensionCommand {
    // MARK: - Types

    private typealias Refusal = BrowserMacTerminal.Refusal

    /// One Chromium extension as one Space's profile has it.
    private struct Placement {
        let space: BrowserSpaceIdentity
        let installed: InstalledExtension
    }

    /// The extension a reference names, in the engine that runs it.
    private enum Target {
        case chromium(id: String, placements: [Placement])
        case servo(ServoExtension)
    }

    private struct ExtensionRow: Encodable {
        let id: String
        let name: String
        let version: String
        let engine: String
        /// Whether it is on in every Space listed.
        let enabled: Bool
        /// The Spaces it is in, or nil for every Space.
        let spaces: [String]?
        /// The Spaces it is in but turned off.
        let disabledIn: [String]
        let description: String?
        let permissions: [String]
        let fromWebStore: Bool?
        let folder: String?
        let runsOnlyContentScripts: Bool?
    }

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) async throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        switch self {
        case .list(let space, let engine):
            return try await list(space: space, engine: engine, in: terminal)
        case .install(.webStore(let id), let space):
            return try review(id, space: space, in: terminal)
        case .install(.file(let path), let space):
            return try install(URL(fileURLWithPath: path), ignoring: space)
        case .remove(let reference, let space):
            return try await change(.remove, reference, space: space, in: terminal)
        case .enable(let reference, let space):
            return try await change(.enable, reference, space: space, in: terminal)
        case .disable(let reference, let space):
            return try await change(.disable, reference, space: space, in: terminal)
        case .info(let reference):
            return try await info(reference, in: terminal)
        }
    }

    // MARK: - Actions - Listing

    @MainActor
    private func list(space name: String?, engine: TerminalEngine?, in terminal: BrowserMacTerminal)
        async throws(Refusal) -> TerminalOutput
    {
        if engine == .chromium, terminal.windows.extensionManager == nil { throw Self.noChromium }
        var rows: [ExtensionRow] = []
        if engine != .servo {
            let placements = try await Self.placements(in: try Self.spaces(name, in: terminal), in: terminal)
            rows += Self.grouped(placements).map(Self.row)
        }
        if engine != .chromium { rows += ServoExtensionStore.shared.extensions.map(Self.row) }
        let text =
            rows.isEmpty
            ? "No extensions."
            : BrowserMacTerminal.table(
                ["ID", "NAME", "VERSION", "ON", "ENGINE", "SPACES"],
                rows.map { row in
                    [
                        row.id, String(row.name.prefix(40)), row.version,
                        row.enabled ? "yes" : (row.disabledIn.count == row.spaces?.count ? "no" : "some"),
                        row.engine, row.spaces?.joined(separator: ", ") ?? "every Space",
                    ]
                })
        return TerminalOutput(text: text, value: ["extensions": rows])
    }

    @MainActor
    private func info(_ reference: String, in terminal: BrowserMacTerminal) async throws(Refusal) -> TerminalOutput {
        let row =
            switch try await Self.target(reference, in: try Self.spaces(nil, in: terminal), terminal: terminal) {
            case .chromium(let id, let placements): Self.row(id: id, placements)
            case .servo(let servoExtension): Self.row(servoExtension)
            }
        var lines = [
            "Name:     \(row.name)", "ID:       \(row.id)", "Version:  \(row.version.isEmpty ? "-" : row.version)",
            "Engine:   \(row.engine)",
        ]
        if let spaces = row.spaces {
            let marked = spaces.map { row.disabledIn.contains($0) ? "\($0) (off)" : $0 }
            lines.append("Spaces:   \(marked.joined(separator: ", "))")
        } else {
            lines.append("Spaces:   every Space")
        }
        if let fromWebStore = row.fromWebStore {
            lines.append("Source:   \(fromWebStore ? "Chrome Web Store" : "outside the Chrome Web Store")")
        }
        if let folder = row.folder { lines.append("Folder:   \(folder)") }
        if row.runsOnlyContentScripts == true {
            lines.append("Runs:     its page scripts only; Servo runs no background script or popup")
        }
        if !row.permissions.isEmpty { lines.append("Asks for: \(row.permissions.joined(separator: ", "))") }
        if let description = row.description, !description.isEmpty { lines += ["", description] }
        return TerminalOutput(text: lines.joined(separator: "\n"), value: row)
    }

    // MARK: - Actions - Installing

    /// Starts the Web Store install review for `id` in the Space's window,
    /// where the person confirms the extension and what it asks for.
    @MainActor
    private func review(_ id: String, space name: String?, in terminal: BrowserMacTerminal) throws(Refusal)
        -> TerminalOutput
    {
        guard let manager = terminal.windows.extensionManager else { throw Self.noChromium }
        let space = try terminal.unlocked(try terminal.space(name))
        guard let window = terminal.frontWindow(over: space) else {
            throw Refusal("No Arma window is open to review it in. Run arma window open.")
        }
        window.browser.selectSpace(space.id)
        terminal.bringForward(window)
        guard manager.reviewInstall(of: id, in: space.identity) else {
            throw Refusal(
                "Arma could not start the review. Finish or close the install review it shows, then try again.")
        }
        return TerminalOutput(
            text:
                "Arma is showing the install review for \(id). Confirm it there to install it into \(space.settings.name).",
            value: ["review": id, "space": space.settings.name])
    }

    /// Installs the Firefox add-on or unpacked extension at `source` into
    /// Servo, which runs it in every Space.
    @MainActor
    private func install(_ source: URL, ignoring space: String?) throws(Refusal) -> TerminalOutput {
        let isFolder = (try? source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let kind = source.pathExtension.lowercased()
        guard kind != "crx" else {
            throw Refusal(
                "Arma installs Chromium extensions from the Chrome Web Store only. Give its id or listing address.")
        }
        guard isFolder || kind == "xpi" else {
            throw Refusal("Give an .xpi add-on, an unpacked extension's folder, or a Chrome Web Store id.")
        }
        let store = ServoExtensionStore.shared
        guard store.canInstall else { throw Refusal("This Arma launch keeps no extensions.") }
        let installed: ServoExtension
        do {
            installed = try store.install(from: source)
        } catch {
            throw Refusal(error.localizedDescription)
        }
        var lines = [
            "Installed \(installed.name) \(installed.version) into Servo as \(installed.id). It runs in Servo pages that load from now on, in every Space."
        ]
        if installed.isPartial {
            lines.append("Servo runs only its page scripts, not its background script or popups.")
        }
        if space != nil { lines.append("Servo add-ons are not per Space, so --space changed nothing.") }
        return TerminalOutput(text: lines.joined(separator: " "), value: Self.row(installed))
    }

    // MARK: - Actions - Changing

    @MainActor
    private func change(
        _ change: ExtensionChange, _ reference: String, space name: String?, in terminal: BrowserMacTerminal
    ) async throws(Refusal) -> TerminalOutput {
        let spaces = try Self.spaces(name, in: terminal)
        switch try await Self.target(reference, in: spaces, terminal: terminal) {
        case .servo(let servoExtension):
            guard change == .remove else {
                throw Refusal("Servo runs an add-on while it is installed. Remove it to stop it.")
            }
            ServoExtensionStore.shared.remove(servoExtension)
            return TerminalOutput(
                text: "Removed \(servoExtension.name) from Servo. Pages stop running it once Servo next starts.")
        case .chromium(let id, let placements):
            guard let manager = terminal.windows.extensionManager else { throw Self.noChromium }
            let name = placements.first?.installed.name ?? id
            var changed: Set<UUID> = []
            var refused: Set<UUID> = []
            // A group's Spaces share one profile, so each profile changes once.
            for placement in placements where !changed.contains(placement.space.profileID) {
                if manager.change(change, extensionID: id, in: placement.space) {
                    changed.insert(placement.space.profileID)
                } else {
                    refused.insert(placement.space.profileID)
                }
            }
            let done = placements.filter { changed.contains($0.space.profileID) }.map(\.space.name)
            guard !done.isEmpty else { throw Refusal("Arma could not change \(name).") }
            let verb =
                switch change {
                case .remove: "Removed"
                case .enable: "Turned on"
                default: "Turned off"
                }
            var text = "\(verb) \(name) in \(done.joined(separator: ", "))."
            let missed = placements.filter { refused.contains($0.space.profileID) }.map(\.space.name)
            if !missed.isEmpty { text += " Arma could not change it in \(missed.joined(separator: ", "))." }
            return TerminalOutput(text: text, value: ["extension": id, "spaces": done.joined(separator: ", ")])
        }
    }

    // MARK: - Actions - Finding

    private static var noChromium: Refusal {
        Refusal("This Arma has no Chromium engine, so it runs no Chromium extensions.")
    }

    /// The Space `name` names, or every Space whose extensions this Arma may
    /// manage.
    @MainActor
    private static func spaces(_ name: String?, in terminal: BrowserMacTerminal) throws(Refusal)
        -> [BrowserSpaceIdentity]
    {
        guard let name else { return terminal.application.extensionSpaces }
        return [try terminal.unlocked(try terminal.space(name)).identity]
    }

    /// Each Chromium extension each of `spaces` has, in order.
    @MainActor
    private static func placements(in spaces: [BrowserSpaceIdentity], in terminal: BrowserMacTerminal)
        async throws(Refusal) -> [Placement]
    {
        guard let manager = terminal.windows.extensionManager else { return [] }
        var placements: [Placement] = []
        for space in spaces {
            guard let installed = await manager.installedExtensions(in: space) else { continue }
            placements += installed.map { Placement(space: space, installed: $0) }
        }
        return placements
    }

    /// `placements` by extension, in the order each first appears.
    private static func grouped(_ placements: [Placement]) -> [(id: String, placements: [Placement])] {
        var order: [String] = []
        var groups: [String: [Placement]] = [:]
        for placement in placements {
            if groups[placement.installed.id] == nil { order.append(placement.installed.id) }
            groups[placement.installed.id, default: []].append(placement)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    /// The one extension `reference` names in `spaces` or in Servo: its id,
    /// the start of its id, or its name.
    @MainActor
    private static func target(
        _ reference: String, in spaces: [BrowserSpaceIdentity], terminal: BrowserMacTerminal
    ) async throws(Refusal) -> Target {
        let wanted = reference.trimmingCharacters(in: .whitespaces)
        func matches(id: String, name: String) -> Bool {
            id.compare(wanted, options: .caseInsensitive) == .orderedSame
                || name.compare(wanted, options: .caseInsensitive) == .orderedSame
                || (wanted.count >= 4 && id.lowercased().hasPrefix(wanted.lowercased()))
        }
        var targets: [Target] = []
        var names: [String] = []
        for group in grouped(try await placements(in: spaces, in: terminal)) {
            guard let first = group.placements.first, matches(id: group.id, name: first.installed.name) else {
                continue
            }
            targets.append(.chromium(id: group.id, placements: group.placements))
            names.append("\(first.installed.name) (\(group.id))")
        }
        for servoExtension in ServoExtensionStore.shared.extensions
        where matches(id: servoExtension.id, name: servoExtension.name) {
            targets.append(.servo(servoExtension))
            names.append("\(servoExtension.name) (Servo, \(servoExtension.id))")
        }
        switch targets.count {
        case 1: return targets[0]
        case 0:
            let place = spaces.count == 1 ? " in \(spaces[0].name)" : ""
            throw Refusal("No extension\(place) is named '\(reference)'. Run arma extension list.")
        default:
            throw Refusal(
                "'\(reference)' names \(targets.count) extensions: \(names.joined(separator: "; ")). Give its id.")
        }
    }

    // MARK: - Actions - Rows

    private static func row(id: String, _ placements: [Placement]) -> ExtensionRow {
        let installed = placements.first?.installed
        let disabled = placements.filter { !$0.installed.enabled }.map(\.space.name)
        return ExtensionRow(
            id: id, name: installed?.name.isEmpty == false ? installed?.name ?? id : id,
            version: installed?.version ?? "", engine: TerminalEngine.chromium.rawValue, enabled: disabled.isEmpty,
            spaces: placements.map(\.space.name), disabledIn: disabled, description: installed?.description,
            permissions: installed?.permissions ?? [], fromWebStore: installed?.fromWebStore, folder: nil,
            runsOnlyContentScripts: nil)
    }

    private static func row(_ group: (id: String, placements: [Placement])) -> ExtensionRow {
        row(id: group.id, group.placements)
    }

    private static func row(_ servoExtension: ServoExtension) -> ExtensionRow {
        ExtensionRow(
            id: servoExtension.id, name: servoExtension.name, version: servoExtension.version,
            engine: TerminalEngine.servo.rawValue, enabled: true, spaces: nil, disabledIn: [], description: nil,
            permissions: [], fromWebStore: nil, folder: servoExtension.folder.path,
            runsOnlyContentScripts: servoExtension.isPartial)
    }
}
