import Foundation

/// One part of Arma the terminal acts on, as `arma <name> <action> ...`:
/// its words, and how they become a `TerminalCommand`.
protocol TerminalSection {
    /// The word that names the section, such as `tab`.
    static var name: String { get }
    /// One line on what the section does, for `arma help`.
    static var summary: String { get }
    /// The section's full usage, for `arma <name> help`.
    static var usage: String { get }
    /// The options that stand alone rather than take a value.
    static var switches: Set<String> { get }
    /// The command `action` and the words after it spell.
    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
}

/// `arma <section> <action>`: parses the words into a command, sends it to
/// the running Arma over the commands socket, and prints what Arma answers,
/// as text, or as JSON with `--json`.
enum TerminalCommandLine {
    // MARK: - Static Variables

    /// Every section the helper knows, in the order `arma help` lists them.
    static let sections: [any TerminalSection.Type] = [
        TerminalSpaceCommandLine.self, TerminalTabCommandLine.self, TerminalWindowCommandLine.self,
        TerminalFolderCommandLine.self, TerminalSplitCommandLine.self, TerminalMenuCommandLine.self,
        TerminalExtensionCommandLine.self, TerminalHistoryCommandLine.self, TerminalArchiveCommandLine.self,
        TerminalDownloadCommandLine.self,
        TerminalPageCommandLine.self, TerminalAutomationCommandLine.self,
        TerminalSettingsCommandLine.self, TerminalSiteCommandLine.self, TerminalThemeCommandLine.self,
        TerminalCrestCommandLine.self,
    ]

    /// The words every section accepts.
    private static let globalSwitches: Set<String> = ["json", "help"]

    static var usage: String {
        var entries: [(name: String, summary: String)] = []
        for section in sections { entries.append((section.name, section.summary)) }
        entries.append(("mcp", "Serve Arma's tools to a coding agent over MCP"))
        let width = entries.map { $0.name.count }.max() ?? 0
        let lines = entries.map { entry in
            "  " + entry.name.padding(toLength: width, withPad: " ", startingAt: 0) + "  " + entry.summary
        }
        return "usage: arma <section> <action> [options]\n\nManage the running Arma from the terminal.\n\n"
            + lines.joined(separator: "\n")
            + "\n\nEvery section takes --json to print its result as JSON.\n"
            + "Run arma <section> help for a section's actions.\n"
    }

    // MARK: - Actions - Running

    /// The section `name` names, or nil.
    static func section(named name: String) -> (any TerminalSection.Type)? {
        for section in sections where section.name == name { return section }
        return nil
    }

    /// Runs `words`, the arguments after `arma`, against the Arma `link`
    /// reaches; answers the exit status.
    static func run(_ words: [String], over link: CommandAppLink) async -> Int32 {
        guard let name = words.first, let section = section(named: name) else {
            let asked = words.first.map { ["help", "--help", "-h"].contains($0) } ?? false
            write(usage, toError: !asked)
            return asked ? 0 : 64
        }
        var rest = Array(words.dropFirst())
        if let socket = rest.firstIndex(of: "--socket") {
            rest.removeSubrange(socket...min(socket + 1, rest.count - 1))
        }
        let wantsHelp = rest.first == "help" || rest.contains("--help") || rest.contains("-h")
        guard !wantsHelp, !rest.isEmpty else {
            write(section.usage, toError: !wantsHelp)
            return wantsHelp ? 0 : 64
        }
        let command: TerminalCommand
        let json: Bool
        do throws(TerminalArguments.Problem) {
            var arguments = try TerminalArguments(rest, switches: section.switches.union(globalSwitches))
            json = arguments.has("json")
            let action = try arguments.take("an action")
            command = try section.command(action: action, &arguments)
            try arguments.finish()
        } catch {
            write(error.message + "\n\n" + section.usage, toError: true)
            return 64
        }
        do {
            let response = try await link.send(.terminal(version: CommandLinkRequest.version, command: command))
            switch response {
            case .output(let output):
                let text = json ? (output.json ?? "null") : output.text
                if !text.isEmpty { write(text.hasSuffix("\n") ? text : text + "\n", toError: false) }
                return 0
            case .refused(let message):
                write(message + "\n", toError: true)
                return 1
            case .applied(let summary):
                write(summary + "\n", toError: false)
                return 0
            case .theme:
                return 0
            }
        } catch let failure as CommandAppLink.Failure {
            write(failure.message + "\n", toError: true)
            return 69
        } catch {
            write("\(error)\n", toError: true)
            return 1
        }
    }

    private static func write(_ text: String, toError: Bool) {
        (toError ? FileHandle.standardError : FileHandle.standardOutput).write(Data(text.utf8))
    }
}
