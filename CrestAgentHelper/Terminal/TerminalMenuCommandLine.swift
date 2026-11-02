import Foundation

/// `arma command`.
enum TerminalMenuCommandLine: TerminalSection {
    static let name = "command"
    static let summary = "List and run the menu and command palette's commands"
    static let switches: Set<String> = []
    static let usage = """
        usage: arma command <action> [options]

          list [--search <text>]   the commands, with their id and whether the front
                                   window can run them now
          run <command>            run a command in the front window, as the menu or
                                   palette would

        A command is its id, such as new-tab, or its title, such as "New Tab", in
        any case.

        """

    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        switch action {
        case "list", "ls":
            var search = arguments.option("search")
            if search == nil, let word = arguments.takeIfPresent() {
                var words = [word]
                while let next = arguments.takeIfPresent() { words.append(next) }
                search = words.joined(separator: " ")
            }
            return .command(.list(search: search))
        case "run", "do":
            var words = [try arguments.take("a command")]
            while let word = arguments.takeIfPresent() { words.append(word) }
            return .command(.run(name: words.joined(separator: " ")))
        default:
            throw TerminalArguments.Problem(message: "arma command has no action '\(action)'.")
        }
    }
}
