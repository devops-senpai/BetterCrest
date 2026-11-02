import AppKit

/// `arma command`, run in the app: the commands the command palette offers,
/// performed through the front window's `BrowserCommandActions`, as the menu
/// bar and the palette perform them.
extension TerminalMenuCommand {
    // MARK: - Types

    private struct CommandRow: Encodable {
        let id: String
        let title: String
        let ready: Bool
    }

    private typealias Refusal = BrowserMacTerminal.Refusal

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        let window = terminal.frontWindow
        let actions = window.map { Self.actions(in: $0, of: terminal) }
        switch self {
        case .list(let search):
            let wanted = search?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
            let rows = Self.commands(in: terminal).compactMap { command -> CommandRow? in
                let row = CommandRow(
                    id: Self.id(of: command), title: Self.title(of: command, in: actions),
                    ready: actions?.canPerform(command) == true)
                guard wanted.isEmpty || row.id.contains(wanted) || row.title.lowercased().contains(wanted) else {
                    return nil
                }
                return row
            }
            guard !rows.isEmpty else { return TerminalOutput(text: "No commands.", value: ["commands": rows]) }
            let text = BrowserMacTerminal.table(
                ["ID", "READY", "TITLE"], rows.map { [$0.id, $0.ready ? "yes" : "-", $0.title] })
            return TerminalOutput(text: text, value: ["commands": rows])
        case .run(let name):
            let command = try Self.command(named: name, in: terminal, actions: actions)
            guard let window, let actions else { throw Refusal("No Arma window is open. Run arma window open.") }
            let title = Self.title(of: command, in: actions)
            guard actions.canPerform(command) else { throw Refusal("\(title) can't run in the front window now.") }
            terminal.bringForward(window)
            actions.perform(command)
            return TerminalOutput(text: "Ran \(title).", value: ["command": Self.id(of: command)])
        }
    }

    // MARK: - Actions - Finding

    /// The commands the palette offers in this Arma, in the core's order.
    @MainActor
    private static func commands(in terminal: BrowserMacTerminal) -> [ShortcutCommand] {
        BrowserCommandActions.paletteCommands.filter { $0.isOffered(in: terminal.browser.core.state) }
    }

    /// The command `name` names: its id or its title, in any case.
    @MainActor
    private static func command(
        named name: String, in terminal: BrowserMacTerminal, actions: BrowserCommandActions?
    ) throws(Refusal) -> ShortcutCommand {
        let wanted = name.trimmingCharacters(in: .whitespaces).lowercased()
        let match = commands(in: terminal).first { command in
            id(of: command) == wanted || command.name.lowercased() == wanted
                || String(localized: command.title).lowercased() == wanted
                || title(of: command, in: actions).lowercased() == wanted
        }
        guard let match else {
            throw Refusal("There is no command '\(name)'. Run arma command list to see them.")
        }
        return match
    }

    // MARK: - Actions - Values

    /// The front window's commands, as the menu bar builds them for the key
    /// window.
    @MainActor
    private static func actions(in window: BrowserMacWindowModel, of terminal: BrowserMacTerminal)
        -> BrowserCommandActions
    {
        BrowserCommandActions(
            browser: window.browser, pages: window.pages, chrome: window.chrome, windows: terminal.windows,
            spaceAccess: terminal.application.spaceAccess, targetWindowID: window.id)
    }

    /// `command`'s name in kebab case, such as `new-tab` or `select-tab-1`.
    private static func id(of command: ShortcutCommand) -> String {
        var id = ""
        var previous: Character?
        for character in command.name {
            let startsWord =
                character.isUppercase || (character.isNumber && previous?.isNumber == false)
            if startsWord, !id.isEmpty, id.last != "-" { id.append("-") }
            id.append(character == "_" ? "-" : Character(character.lowercased()))
            previous = character
        }
        return id
    }

    /// What the menu bar calls `command` now, or its own title.
    @MainActor
    private static func title(of command: ShortcutCommand, in actions: BrowserCommandActions?) -> String {
        String(localized: actions?.menuTitle(of: command) ?? command.title)
    }
}
