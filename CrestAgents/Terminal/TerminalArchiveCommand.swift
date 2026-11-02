import Foundation

/// `arma archive`: the tabs each Space archived, which it can bring back as
/// they were, as the core holds them.
enum TerminalArchiveCommand: Codable, Sendable {
    /// The archived tabs whose title or address hold every word of `text`,
    /// newest first: in `space`, or every unlocked Space; archived for a
    /// reason of the `reason` filter group when given; at most `limit`;
    /// archived within the last `since` seconds when given.
    case search(text: String, space: String?, reason: String?, limit: Int?, since: TimeInterval?)
    /// The newest archived tabs of `space`, or of every unlocked Space.
    case list(space: String?, reason: String?, limit: Int?)
    /// Brings the archived tab `entry` names back as an open tab and shows it.
    case restore(entry: String)
    /// Removes the archived tab `entry` names for good.
    case delete(entry: String)
    /// Removes what `space`, or every unlocked Space, archived within
    /// `range`. The helper sends it only once the person confirmed it.
    case clear(space: String?, range: TerminalHistoryCommand.Period)
}
