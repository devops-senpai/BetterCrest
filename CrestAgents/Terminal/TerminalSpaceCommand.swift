import Foundation

/// `arma space`: the Spaces, and which one a window shows.
enum TerminalSpaceCommand: Codable, Sendable {
    /// Every Space, with the one the front window shows marked.
    case list
    /// One Space, or the front window's: its tabs by placement and its folders.
    case show(space: String?)
    /// Shows `space` in the front window.
    case switchTo(space: String)
}
