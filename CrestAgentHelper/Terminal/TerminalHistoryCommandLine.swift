import Foundation

/// `arma history`.
enum TerminalHistoryCommandLine: TerminalSection {
    // MARK: - Static Variables

    static let name = "history"
    static let summary = "Search, list, delete from and clear each Space's history"
    static let switches: Set<String> = ["yes"]
    static let usage = """
        usage: arma history <action> [options]

          search <text> [--space <s>] [--limit <n>] [--since <age>]
                                   entries whose address or title hold every word,
                                   newest first; --since takes 30m, 12h, 7d or 2w
          list [--space <s>] [--limit <n>]
                                   the newest entries
          delete <url> [--space <s>]
                                   remove every visit to <url>, from every Space that has
                                   it unless --space names one
          clear [--space <s>] [--range hour|day|week|month|all] --yes
                                   remove what the Space (the front window's by default)
                                   visited in the range, all of it by default

        Without --space, search and list read every unlocked Space.

        """

    /// The seconds in one of each unit `--since` takes.
    private static let units: [Character: TimeInterval] = ["m": 60, "h": 3600, "d": 86_400, "w": 604_800]

    // MARK: - Actions - Parsing

    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        let space = arguments.option("space")
        switch action {
        case "search", "find":
            var words: [String] = []
            while let word = arguments.takeIfPresent() { words.append(word) }
            guard !words.isEmpty else { throw TerminalArguments.Problem(message: "Give text to search for.") }
            var since: TimeInterval?
            if let text = arguments.option("since") { since = try age(text) }
            return .history(
                .search(
                    text: words.joined(separator: " "), space: space, limit: try limit(arguments), since: since))
        case "list", "ls", "recent":
            return .history(.list(space: space, limit: try limit(arguments)))
        case "delete", "remove", "rm":
            return .history(.delete(url: try arguments.take("an address"), space: space))
        case "clear":
            var range = TerminalHistoryCommand.Period.all
            if let text = arguments.option("range") {
                range = try TerminalArguments.choice(text, as: TerminalHistoryCommand.Period.self, for: "--range")
            }
            guard arguments.has("yes") else {
                throw TerminalArguments.Problem(
                    message: "Clearing history cannot be undone. Add --yes to clear it.")
            }
            return .history(.clear(space: space, range: range))
        default:
            throw TerminalArguments.Problem(message: "arma history has no action '\(action)'.")
        }
    }

    /// `--limit`, a whole number from 1 to 1000, or nil when absent.
    private static func limit(_ arguments: TerminalArguments) throws(TerminalArguments.Problem) -> Int? {
        guard let value = try arguments.number("limit") else { return nil }
        guard value == value.rounded(), (1...1000).contains(value) else {
            throw TerminalArguments.Problem(message: "--limit is a whole number from 1 to 1000.")
        }
        return Int(value)
    }

    /// `text`, such as `7d`, as seconds; a bare number counts days.
    private static func age(_ text: String) throws(TerminalArguments.Problem) -> TimeInterval {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        var unit: TimeInterval = units["d"] ?? 86_400
        var digits = Substring(trimmed)
        if let last = trimmed.last, let seconds = units[last] {
            unit = seconds
            digits = trimmed.dropLast()
        }
        guard let count = Double(digits), count > 0 else {
            throw TerminalArguments.Problem(message: "--since takes an age such as 30m, 12h, 7d or 2w, not '\(text)'.")
        }
        return count * unit
    }
}
