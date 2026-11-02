import Foundation

/// `arma page`: what happens inside one tab's page, as the person would do
/// it: read it as text or an outline, capture it, run a script, click, hover,
/// type, fill, press keys, scroll, wait, answer its dialog, and read its
/// console and network activity. The tab is named as `arma tab` names it.
/// Arma runs these only while Settings › Agents › Command-line page control
/// is on.
struct TerminalPageCommand: Codable, Sendable {
    // MARK: - Types

    /// Where input lands: the element an outline's uid names, or a point in
    /// the page's viewport, in CSS pixels from its top left.
    enum Target: Codable, Sendable {
        case element(uid: String)
        case point(x: Double, y: Double)
    }

    /// A key held while another is pressed.
    enum Modifier: String, Codable, Sendable, CaseIterable {
        case command
        case shift
        case option
        case control

        /// The modifier `name` names, or one of its short names, such as cmd.
        static func named(_ name: String) -> Self? {
            let shortNames: [String: Self] = ["cmd": .command, "alt": .option, "opt": .option, "ctrl": .control]
            let lowered = name.lowercased()
            return Self(rawValue: lowered) ?? shortNames[lowered]
        }
    }

    /// An end of the page to scroll to.
    enum Edge: String, Codable, Sendable, CaseIterable {
        case top
        case bottom
    }

    /// How far to scroll.
    enum Scroll: Codable, Sendable {
        /// By `dx` and `dy` CSS pixels, as a trackpad would.
        case by(dx: Double, dy: Double)
        /// To an end of the page.
        case to(Edge)
    }

    /// What to wait for.
    enum Wait: Codable, Sendable {
        /// Until the page shows `text`, for up to `timeout` seconds.
        case text(String, timeout: Double)
        /// Until the tab's address contains `url`, for up to `timeout` seconds.
        case url(String, timeout: Double)
        /// For `seconds`.
        case seconds(Double)
    }

    /// One thing to do in the page.
    enum Action: Codable, Sendable {
        /// The page's address, title, engine, loading state and zoom.
        case info
        /// The page's readable text, within `limit` characters.
        case text(limit: Int)
        /// The page as an outline whose elements carry uids.
        case snapshot
        /// A PNG of what the page shows, or of all of it when `fullPage`, or
        /// of the element `uid` names, written to `path` or a new temporary
        /// file.
        case screenshot(path: String?, fullPage: Bool, uid: String?)
        /// Runs `source` in the page's own world: an expression, or the body
        /// of an async function that returns its result.
        case eval(source: String)
        /// Clicks `target`, twice when `double`.
        case click(Target, double: Bool)
        /// Moves the pointer over `target`.
        case hover(Target)
        /// Types `text` into the focused element.
        case type(text: String)
        /// Replaces what element `uid` holds with `text`, or picks the menu
        /// option `text` names.
        case fill(uid: String, text: String)
        /// Presses `key`, a KeyboardEvent key such as Enter or a, with
        /// `modifiers` held.
        case key(String, modifiers: [Modifier])
        case scroll(Scroll)
        case wait(Wait)
        /// Accepts or dismisses the page's alert, confirm or prompt, with
        /// `text` as a prompt's reply.
        case dialog(accept: Bool, text: String?)
        /// The console messages kept after sequence `since`.
        case console(since: Int64)
        /// The network requests kept after sequence `since`.
        case network(since: Int64)
    }

    // MARK: - Variables

    /// The tab: `current`, its identifier, or the start of one.
    let tab: String
    let action: Action
}
