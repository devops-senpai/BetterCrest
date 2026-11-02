import Foundation

/// `arma archive`.
enum TerminalArchiveCommandLine: TerminalSection {
    // MARK: - Static Variables

    static let name = "archive"
    static let summary = "Search, restore, delete from and clear the tabs each Space archived"
    static let switches: Set<String> = ["yes"]
    static let usage = """
        usage: arma archive <action> [options]

          search <text> [--space <s>] [--reason <r>] [--limit <n>] [--since <age>]
                                   archived tabs whose title or address hold every
                                   word, newest first; --since takes 30m, 12h, 7d or 2w
          list [--space <s>] [--reason <r>] [--limit <n>]
                                   the newest archived tabs
          restore <entry>          bring the tab back as an open tab, with its own
                                   back and forward history, and show it
          delete <entry>           remove the tab from the archive for good
          clear [--space <s>] [--range hour|day|week|month|all] --yes
                                   remove what the Space archived in the range, all
                                   of it by default; every unlocked Space without --space

        An entry is the archived tab's id, or the start of it, from arma archive list.
        --reason takes closed, automatic, synced or quickWindow.
        Without --space, search and list read every unlocked Space.

        """

    // MARK: - Actions - Parsing

    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        let space = arguments.option("space")
        let reason = arguments.option("reason")
        switch action {
        case "search", "find":
            var words: [String] = []
            while let word = arguments.takeIfPresent() { words.append(word) }
            guard !words.isEmpty else { throw TerminalArguments.Problem(message: "Give text to search for.") }
            var since: TimeInterval?
            if let text = arguments.option("since") { since = try TerminalHistoryCommandLine.age(text) }
            return .archive(
                .search(
                    text: words.joined(separator: " "), space: space, reason: reason,
                    limit: try TerminalHistoryCommandLine.limit(arguments), since: since))
        case "list", "ls":
            return .archive(.list(space: space, reason: reason, limit: try TerminalHistoryCommandLine.limit(arguments)))
        case "restore", "reopen", "open":
            return .archive(.restore(entry: try arguments.take("an archived tab")))
        case "delete", "remove", "rm":
            return .archive(.delete(entry: try arguments.take("an archived tab")))
        case "clear":
            var range = TerminalHistoryCommand.Period.all
            if let text = arguments.option("range") {
                range = try TerminalArguments.choice(text, as: TerminalHistoryCommand.Period.self, for: "--range")
            }
            guard arguments.has("yes") else {
                throw TerminalArguments.Problem(
                    message: "Clearing the archive cannot be undone. Add --yes to clear it.")
            }
            return .archive(.clear(space: space, range: range))
        default:
            throw TerminalArguments.Problem(message: "arma archive has no action '\(action)'.")
        }
    }
}
