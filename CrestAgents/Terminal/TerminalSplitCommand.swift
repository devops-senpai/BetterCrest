import Foundation

/// `arma split`: the Split Views of a Space, which show two or more of its
/// tabs side by side in one window.
///
/// Tabs are named as `arma tab` names them: `current`, an identifier, or the
/// start of one.
enum TerminalSplitCommand: Codable, Sendable {
    /// The splits of `space`, or of every Space, with their tabs.
    case list(space: String?)
    /// Shows `tabs` together in a new Split View, in columns, or in stacked
    /// rows when `rows`.
    case create(tabs: [String], rows: Bool)
    /// Adds tab `tab` to the split tab `target` is in, or makes the two a
    /// split when `target` is in none.
    case add(tab: String, target: String)
    /// Takes tab `tab` out of its split.
    case remove(tab: String)
    /// Ends the split tab `tab` is in; its tabs stay, each on its own.
    case dissolve(tab: String)
    /// Lays out the split tab `tab` is in as layout `layout`, such as
    /// `two-stacked` or `grid`.
    case arrange(tab: String, layout: String)
}
