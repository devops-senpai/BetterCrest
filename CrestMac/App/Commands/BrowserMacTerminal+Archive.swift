import Foundation

/// `arma archive`, run in the app over the tabs the core keeps in each
/// Space's archive, through the same intents the sidebar's Archive list and
/// Reopen Closed Tab send.
extension TerminalArchiveCommand {
    // MARK: - Types

    private typealias Refusal = BrowserMacTerminal.Refusal

    private struct EntryRow: Encodable {
        let id: UUID
        let space: String
        let title: String
        let url: String?
        let reason: String
        let archivedAt: Date
    }

    /// One archived tab, found by its reference, with its Space.
    private struct FoundEntry {
        let space: SpaceModel
        let entry: ArchivedTabState
    }

    /// The entries `list` and `search` print when no `--limit` is given.
    private static let defaultLimit = 25

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        switch self {
        case .search(let text, let space, let reason, let limit, let since):
            let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
            let earliest = since.map { Date.now.addingTimeInterval(-$0) }
            return try entries(space: space, reason: reason, limit: limit, in: terminal) { archived in
                let haystack = archived.tab.shownTitle + " " + (archived.tab.url ?? "")
                return words.allSatisfy { haystack.localizedStandardContains($0) }
                    && earliest.map { archived.archivedAt >= $0 } ?? true
            }
        case .list(let space, let reason, let limit):
            return try entries(space: space, reason: reason, limit: limit, in: terminal) { _ in true }
        case .restore(let reference):
            return try restore(try Self.entry(reference, in: terminal), in: terminal)
        case .delete(let reference):
            let found = try Self.entry(reference, in: terminal)
            guard terminal.browser.removeArchivedTab(found.entry.tab.id, in: found.space.id) else {
                throw Refusal("Arma could not remove that tab from the archive.")
            }
            return TerminalOutput(
                text: "Removed \(found.entry.tab.shownTitle) from \(found.space.settings.name)'s archive.")
        case .clear(let name, let period):
            let space = try name.map { name throws(Refusal) in try terminal.unlocked(try terminal.space(name)) }
            guard terminal.browser.clearArchive(in: space?.id, range: period.range) else {
                throw Refusal("There was nothing to clear.")
            }
            let reach = period == .all ? "all of" : "the last \(period.rawValue) of"
            let owner = space.map { "\($0.settings.name)'s" } ?? "every unlocked Space's"
            return TerminalOutput(text: "Cleared \(reach) \(owner) archive.")
        }
    }

    // MARK: - Actions - Reading

    /// The newest archived tabs `included` keeps, from the Space `name` names
    /// or every unlocked Space, archived for a reason of the `reason` group.
    @MainActor
    private func entries(
        space name: String?, reason: String?, limit: Int?, in terminal: BrowserMacTerminal,
        including included: (ArchivedTabState) -> Bool
    ) throws(Refusal) -> TerminalOutput {
        let group = try reason.map { text throws(Refusal) in try Self.group(text) }
        var rows: [EntryRow] = []
        for space in try Self.spaces(name, in: terminal) {
            rows += space.archive.entries
                .filter { archived in group.map { archived.reason.filterGroup == $0 } ?? true }
                .filter(included)
                .map { archived in
                    EntryRow(
                        id: archived.tab.id, space: space.settings.name, title: archived.tab.shownTitle,
                        url: archived.tab.url, reason: archived.reason.filterGroup.name,
                        archivedAt: archived.archivedAt)
                }
        }
        rows.sort { $0.archivedAt > $1.archivedAt }
        rows = Array(rows.prefix(limit ?? Self.defaultLimit))
        let format = Date.FormatStyle(date: .abbreviated, time: .shortened)
        let text =
            rows.isEmpty
            ? "No archived tabs."
            : BrowserMacTerminal.table(
                ["ARCHIVED", "ID", "SPACE", "REASON", "TITLE", "ADDRESS"],
                rows.map { row in
                    [
                        row.archivedAt.formatted(format), BrowserMacTerminal.short(row.id), row.space, row.reason,
                        String(row.title.prefix(50)), row.url ?? "",
                    ]
                })
        return TerminalOutput(text: text, value: ["entries": rows])
    }

    /// The Space `name` names, or every unlocked Space.
    @MainActor
    private static func spaces(_ name: String?, in terminal: BrowserMacTerminal) throws(Refusal) -> [SpaceModel] {
        if let name { return [try terminal.unlocked(try terminal.space(name))] }
        return terminal.spaces.filter { !terminal.application.spaceAccess.isLocked($0) }
    }

    /// The filter group `text` names, in any case.
    private static func group(_ text: String) throws(Refusal) -> ArchiveFilterGroup {
        if let group = ArchiveFilterGroup.all.first(where: {
            $0.name.compare(text, options: .caseInsensitive) == .orderedSame
        }) {
            return group
        }
        let names = ArchiveFilterGroup.all.map(\.name).joined(separator: ", ")
        throw Refusal("--reason takes \(names), not '\(text)'.")
    }

    /// The archived tab `reference` names: its identifier, or the start of
    /// one, across every unlocked Space.
    @MainActor
    private static func entry(_ reference: String, in terminal: BrowserMacTerminal) throws(Refusal) -> FoundEntry {
        let wanted = reference.trimmingCharacters(in: .whitespaces).lowercased()
        guard wanted.count >= 4 else { throw Refusal("Give at least 4 characters of the archived tab's id.") }
        var matches: [FoundEntry] = []
        for space in try spaces(nil, in: terminal) {
            for entry in space.archive.entries where entry.tab.id.uuidString.lowercased().hasPrefix(wanted) {
                matches.append(FoundEntry(space: space, entry: entry))
            }
        }
        switch matches.count {
        case 1: return matches[0]
        case 0: throw Refusal("No archived tab's id starts with '\(reference)'. Run arma archive list.")
        default: throw Refusal("\(matches.count) archived tabs' ids start with '\(reference)'. Give more of it.")
        }
    }

    // MARK: - Actions - Restoring

    /// Brings `found` back as an open tab of its Space, which the front window
    /// over that Space shows; with no window open it waits in the sidebar.
    @MainActor
    private func restore(_ found: FoundEntry, in terminal: BrowserMacTerminal) throws(Refusal) -> TerminalOutput {
        let window = terminal.frontWindow(over: found.space)
        window?.browser.selectSpace(found.space.id)
        guard (window?.browser ?? terminal.browser).restoreArchivedTab(found.entry.tab.id, in: found.space.id) else {
            throw Refusal("Arma could not restore that tab.")
        }
        if let window { terminal.bringForward(window) }
        return TerminalOutput(
            text: "Restored \(found.entry.tab.shownTitle) to \(found.space.settings.name).",
            value: ["tab": found.entry.tab.id])
    }
}
