import Foundation

/// `arma history`, run in the app over the history the core keeps for each
/// Space, through the same intents the sidebar's history and the Clear
/// Browsing Data section send.
extension TerminalHistoryCommand {
    // MARK: - Types

    private typealias Refusal = BrowserMacTerminal.Refusal

    private struct EntryRow: Encodable {
        let id: UUID
        let space: String
        let url: String
        let title: String
        let lastVisitedAt: Date
        let visitCount: Int
    }

    /// The entries `list` and `search` print when no `--limit` is given.
    private static let defaultLimit = 25

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        switch self {
        case .search(let text, let space, let limit, let since):
            let words = text.lowercased().split(whereSeparator: \.isWhitespace)
            let earliest = since.map { Date.now.addingTimeInterval(-$0) }
            return try entries(space: space, limit: limit, in: terminal) { entry in
                let haystack = (entry.url + " " + entry.title).lowercased()
                return words.allSatisfy { haystack.contains($0) } && earliest.map { entry.lastVisitedAt >= $0 } ?? true
            }
        case .list(let space, let limit):
            return try entries(space: space, limit: limit, in: terminal) { _ in true }
        case .delete(let url, let space):
            return try delete(url, space: space, in: terminal)
        case .clear(let name, let period):
            let space = try terminal.unlocked(try terminal.space(name))
            guard terminal.browser.clearHistory(in: space.id, range: Self.range(of: period)) else {
                throw Refusal("Arma could not clear \(space.settings.name)'s history.")
            }
            let reach = period == .all ? "all of" : "the last \(period.rawValue) of"
            return TerminalOutput(text: "Cleared \(reach) \(space.settings.name)'s history.")
        }
    }

    // MARK: - Actions - Reading

    /// The newest entries `included` keeps, from the Space `name` names or
    /// every unlocked Space.
    @MainActor
    private func entries(
        space name: String?, limit: Int?, in terminal: BrowserMacTerminal,
        including included: (HistoryEntryState) -> Bool
    ) throws(Refusal) -> TerminalOutput {
        var rows: [EntryRow] = []
        for (space, entries) in try Self.histories(name, in: terminal) {
            rows += entries.filter(included).map { entry in
                EntryRow(
                    id: entry.id, space: space.settings.name, url: entry.url, title: entry.title,
                    lastVisitedAt: entry.lastVisitedAt, visitCount: entry.visitCount)
            }
        }
        rows.sort { $0.lastVisitedAt > $1.lastVisitedAt }
        rows = Array(rows.prefix(limit ?? Self.defaultLimit))
        let format = Date.FormatStyle(date: .abbreviated, time: .shortened)
        let text =
            rows.isEmpty
            ? "No history."
            : BrowserMacTerminal.table(
                ["VISITED", "SPACE", "TITLE", "ADDRESS"],
                rows.map { row in
                    [row.lastVisitedAt.formatted(format), row.space, String(row.title.prefix(50)), row.url]
                })
        return TerminalOutput(text: text, value: ["entries": rows])
    }

    /// Each Space's history: the group's for the Space `name` names, or each
    /// unlocked Space's own, so a group's shared history is read once.
    @MainActor
    private static func histories(_ name: String?, in terminal: BrowserMacTerminal) throws(Refusal)
        -> [(space: SpaceModel, entries: [HistoryEntryState])]
    {
        if let name {
            let space = try terminal.unlocked(try terminal.space(name))
            return [(space, space.groupHistory)]
        }
        return terminal.spaces.filter { !terminal.application.spaceAccess.isLocked($0) }.map {
            ($0, $0.history.entries)
        }
    }

    // MARK: - Actions - Removing

    @MainActor
    private func delete(_ text: String, space name: String?, in terminal: BrowserMacTerminal) throws(Refusal)
        -> TerminalOutput
    {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let candidates = Set(
            [trimmed, (try? TerminalTabCommand.address(trimmed).absoluteString) ?? trimmed].map(Self.comparable))
        var removed: [String] = []
        for (space, entries) in try Self.histories(name, in: terminal) {
            guard let entry = entries.first(where: { candidates.contains(Self.comparable($0.url)) }) else { continue }
            if terminal.browser.removeHistoryAddress(entry.url, in: space.id) { removed.append(space.settings.name) }
        }
        guard !removed.isEmpty else {
            throw Refusal("No history\(name.map { " in \($0)" } ?? "") holds \(trimmed).")
        }
        return TerminalOutput(
            text: "Removed \(trimmed) from \(removed.joined(separator: ", "))'s history.", value: ["spaces": removed])
    }

    /// `address` as history compares it: without its fragment, as the core
    /// keeps it, and with the root path a bare host such as `example.com`
    /// leaves out.
    private static func comparable(_ address: String) -> String {
        let kept = String(address.prefix { $0 != "#" })
        guard var parts = URLComponents(string: kept), parts.host != nil else { return kept }
        if parts.path.isEmpty { parts.path = "/" }
        parts.scheme = parts.scheme?.lowercased()
        parts.host = parts.host?.lowercased()
        return parts.string ?? kept
    }

    /// The core's range for `period`.
    private static func range(of period: Period) -> BrowsingDataRange {
        switch period {
        case .hour: .lastHour
        case .day: .lastDay
        case .week: .lastWeek
        case .month: .lastFourWeeks
        case .all: .allTime
        }
    }
}
