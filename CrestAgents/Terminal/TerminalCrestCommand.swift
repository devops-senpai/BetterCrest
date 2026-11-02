import Foundation

/// `arma crest`: a Space's own crest or icon, its shape and its colors,
/// which no theme carries and which color nothing else in the window.
enum TerminalCrestCommand: Codable, Sendable {
    /// A Space's crest, or the shown Space's: its parts and their colors.
    case show(space: String?)
    /// Changes a Space's crest, or the shown Space's.
    case set(space: String?, changes: TerminalCrestChanges)
    /// Gives a Space's crest, or the shown Space's, new parts and colors.
    case shuffle(space: String?)
}

/// The parts and colors `arma crest set` names, each by its word; nil leaves
/// a part as it is.
struct TerminalCrestChanges: Codable, Sendable {
    /// `crest`, or `icon` for a symbol or emoji alone.
    var style: String?
    var shape: String?
    var field: String?
    var band: String?
    /// The crest's figure.
    var emblem: String?
    var border: String?
    var finish: String?
    /// The SF Symbol an icon shows.
    var symbol: String?
    /// The emoji an icon shows.
    var emoji: String?
    /// Each crest layer's color by its word: field, second-field, band,
    /// emblem, border or edge.
    var colors: [String: String] = [:]
    /// The icon's color.
    var iconColor: String?

    var isEmpty: Bool {
        [style, shape, field, band, emblem, border, finish, symbol, emoji, iconColor].allSatisfy { $0 == nil }
            && colors.isEmpty
    }
}
