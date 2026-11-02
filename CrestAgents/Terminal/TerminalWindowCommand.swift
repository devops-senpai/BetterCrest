import Foundation

/// `arma window`: Arma's browser windows on screen. A window is named by its
/// number in `arma window list`, `front` for the frontmost, or its identifier.
enum TerminalWindowCommand: Codable, Sendable {
    /// The browser windows, front to back, with their frames and screens.
    case list
    /// Brings `window` forward and Arma with it.
    case focus(window: String)
    /// Moves `window`'s top-left corner to `x`, `y` in points from the top
    /// left of its screen, or of screen `screen` when given.
    case move(window: String, x: Double, y: Double, screen: Int?)
    /// Gives `window` a frame `width` by `height` points.
    case resize(window: String, width: Double, height: Double)
    /// Fills a part of `window`'s screen.
    case tile(window: String, region: TerminalWindowRegion)
    case center(window: String)
    case minimize(window: String)
    case restore(window: String)
    /// Zooms `window` to fill its screen, or back.
    case zoom(window: String)
    case fullScreen(window: String)
    /// Opens a new browser window, over `space` when given.
    case open(space: String?)
    case close(window: String)
}

/// A part of the screen a window can fill.
enum TerminalWindowRegion: String, Codable, Sendable, CaseIterable {
    case left
    case right
    case top
    case bottom
    case topLeft = "top-left"
    case topRight = "top-right"
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"
    case full
}
