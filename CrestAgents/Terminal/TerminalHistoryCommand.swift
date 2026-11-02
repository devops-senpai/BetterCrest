import Foundation

/// `arma history`: the addresses each Space's history keeps, as the core
/// holds them.
enum TerminalHistoryCommand: Codable, Sendable {
    // MARK: - Types

    /// How far back `arma history clear` reaches.
    enum Period: String, Codable, Sendable, CaseIterable {
        case hour
        case day
        case week
        case month
        case all
    }

    /// The entries whose address or title hold every word of `text`, newest
    /// first: in `space`, or every unlocked Space; at most `limit`; visited
    /// within the last `since` seconds when given.
    case search(text: String, space: String?, limit: Int?, since: TimeInterval?)
    /// The newest entries of `space`, or of every unlocked Space.
    case list(space: String?, limit: Int?)
    /// Removes every visit to `url` from `space`, or from every unlocked
    /// Space that has it.
    case delete(url: String, space: String?)
    /// Removes what `space`, or the front window's Space, visited within
    /// `range`. The helper sends it only once the person confirmed it.
    case clear(space: String?, range: Period)
}
