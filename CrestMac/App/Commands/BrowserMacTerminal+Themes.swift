import Foundation

/// `arma theme`, run in the app on the saved theme library Settings › Themes
/// shows.
extension TerminalThemeCommand {
    // MARK: - Types

    private struct Listed: Encodable {
        let id: UUID
        let name: String
        let looks: String
        let spaces: [String]
        let shown: Bool
    }

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        let library = BrowserThemeLibrary.shared
        let browser = terminal.browser
        switch self {
        case .list:
            return list(library, in: terminal)
        case .show(let name):
            let entry = try Self.entry(name, in: library)
            return Self.document(entry.theme)
        case .create(let name, let spaceName, let look):
            var theme = CrestTheme(look: .neutral)
            if let spaceName {
                theme = BrowserThemeLibrary.theme(of: try terminal.space(spaceName), named: name)
            }
            if var look {
                look.name = nil
                theme = theme.merging(look)
                if let image = look.backgroundImage { theme.backgroundImage = image }
            }
            theme.name = name
            try Self.validate(theme, in: terminal)
            let id = library.add(theme)
            return TerminalOutput(text: "Saved the theme \(name).", value: ["id": id.uuidString, "name": name])
        case .duplicate(let name, let copyName):
            let entry = try Self.entry(name, in: library)
            guard let copy = library.duplicate(entry.id) else { throw .init("Arma could not copy \(entry.name).") }
            if let copyName { library.rename(copy, to: copyName) }
            let named = library.entry(copy)?.name ?? ""
            return TerminalOutput(text: "Saved \(named).", value: ["id": copy.uuidString, "name": named])
        case .rename(let name, let newName):
            let entry = try Self.entry(name, in: library)
            library.rename(entry.id, to: newName)
            return TerminalOutput(text: "Renamed \(entry.name) to \(newName).")
        case .delete(let name):
            let entry = try Self.entry(name, in: library)
            let wearers = library.spaces(wearing: entry.id, in: browser).map(\.settings.name)
            guard wearers.isEmpty else {
                throw .init(
                    "\(wearers.formatted(.list(type: .and))) uses \(entry.name). Pick another theme for it first: "
                        + "arma theme use <theme> --space <space>.")
            }
            library.remove(entry.id)
            return TerminalOutput(text: "Deleted \(entry.name).")
        case .edit(let name, let spaceName, let look, let dark, let unpairDark):
            let entry: BrowserThemeLibrary.Entry
            if let name {
                entry = try Self.entry(name, in: library)
            } else {
                let space = try terminal.space(spaceName)
                guard let id = library.themeID(of: space.id), let worn = library.entry(id) else {
                    throw .init("\(space.settings.name) uses no saved theme yet. Open its Appearance page once.")
                }
                entry = worn
            }
            var theme = entry.theme
            if unpairDark { theme.dark = nil }
            if var look {
                look.name = nil
                if dark {
                    theme.dark = (theme.dark ?? theme.sections).merging(look.sections)
                } else {
                    theme = theme.merging(look)
                }
                if let image = look.backgroundImage { theme.backgroundImage = image }
            }
            try Self.validate(theme, in: terminal)
            library.edit(entry.id, in: browser) { $0 = theme }
            let wearers = library.spaces(wearing: entry.id, in: browser).map(\.settings.name)
            let reach = wearers.isEmpty ? "" : " Used by \(wearers.formatted(.list(type: .and)))."
            return TerminalOutput(text: "Changed \(entry.name).\(reach)")
        case .use(let name, let spaceName):
            let entry = try Self.entry(name, in: library)
            let space = try terminal.unlocked(try terminal.space(spaceName))
            if let problem = library.choose(entry.id, for: space.id, in: browser) { throw .init(problem) }
            return TerminalOutput(text: "\(space.settings.name) uses \(entry.name).")
        }
    }

    @MainActor
    private func list(_ library: BrowserThemeLibrary, in terminal: BrowserMacTerminal) -> TerminalOutput {
        let shownID = (try? terminal.space(nil)).flatMap { library.themeID(of: $0.id) }
        let listed = library.entries.map { entry in
            Listed(
                id: entry.id, name: entry.name, looks: entry.theme.dark == nil ? "one" : "light and dark",
                spaces: library.spaces(wearing: entry.id, in: terminal.browser).map(\.settings.name),
                shown: entry.id == shownID)
        }
        let rows = listed.map { theme in
            [
                theme.shown ? "*" : "", theme.name, theme.looks,
                theme.spaces.isEmpty ? "-" : theme.spaces.joined(separator: ", "),
            ]
        }
        let text =
            listed.isEmpty ? "No saved themes." : BrowserMacTerminal.table(["", "THEME", "LOOKS", "USED BY"], rows)
        return TerminalOutput(text: text, value: listed)
    }

    // MARK: - Actions - Finding

    /// The saved theme named `name`, in any case, or whose identity starts with it.
    @MainActor
    private static func entry(_ name: String, in library: BrowserThemeLibrary) throws(BrowserMacTerminal.Refusal)
        -> BrowserThemeLibrary.Entry
    {
        let wanted = name.lowercased()
        if let entry = library.entries.first(where: { $0.name.lowercased() == wanted }) { return entry }
        let byID = library.entries.filter { wanted.count >= 4 && $0.id.uuidString.lowercased().hasPrefix(wanted) }
        if byID.count == 1 { return byID[0] }
        let names = library.entries.map(\.name).formatted(.list(type: .and))
        throw .init("There is no theme named '\(name)'. The themes are \(names).")
    }

    /// Refuses a theme whose words or colors no look can wear.
    @MainActor
    private static func validate(_ theme: CrestTheme, in terminal: BrowserMacTerminal)
        throws(BrowserMacTerminal.Refusal)
    {
        do {
            _ = try SpaceBranding.neutral.dressed(in: theme, dark: nil)
        } catch {
            throw .init(error.message)
        }
    }

    /// `theme` as a theme file, which is both what the person reads and its JSON.
    private static func document(_ theme: CrestTheme) -> TerminalOutput {
        let text = (try? theme.json()).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return TerminalOutput(text: text, json: text)
    }
}
