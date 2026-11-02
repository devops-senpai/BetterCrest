import Foundation

// What the helper and the Crest it ships inside say over the commands
// socket, one JSON object per line: the commands a person runs from their own
// terminal, such as theming a Space. The socket is open whenever Crest runs
// and admits only this Crest's own helper running as the same user; it never
// carries an agent's work, which goes over the agent socket and its consent.

// MARK: - Types

/// What the helper asks Crest to do for the person at the terminal.
enum CommandLinkRequest: Codable, Sendable {
    /// Dress the Space named `space` (by name or identifier) in `changes` after
    /// putting the `resets` sections back to the Space's starting look, take
    /// away its dark look when `removeDark`, and answer its theme when
    /// `export`, else what changed.
    case theme(
        version: Int, space: String, changes: CrestTheme?, resets: [CrestThemeSection], removeDark: Bool, export: Bool)
}

/// What Crest answers.
enum CommandLinkResponse: Codable, Sendable {
    /// The command ran; `summary` says what it did, for the terminal.
    case applied(summary: String)
    /// The Space's theme, as asked.
    case theme(CrestTheme)
    /// Crest did not run the command, for the reason `message` gives.
    case refused(message: String)
}

extension CommandLinkRequest {
    /// The link's revision; a helper and a Crest of different revisions never
    /// talk.
    static let version = 1
    /// The longest line a helper sends over this socket.
    static let maximumBytes = 1 << 20
}
