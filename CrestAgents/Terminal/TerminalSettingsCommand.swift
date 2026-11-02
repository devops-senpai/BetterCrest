import Foundation

/// `arma settings`: the settings the terminal exposes, by key, and the
/// browser-data file Settings › Advanced exports and imports.
///
/// A key names one setting, such as `appearance.mode`; a key that starts with
/// `space.` is one Space's, chosen with `--space` or the front window's.
/// Values are spelled as `arma settings list` shows them.
enum TerminalSettingsCommand: Codable, Sendable {
    /// Every setting, or those whose key starts with `section`, with their
    /// values; per-Space settings read `space`, or the front window's Space.
    case list(section: String?, space: String?)
    /// One setting's value.
    case get(key: String, space: String?)
    /// Sets one setting to `value`.
    case set(key: String, value: String, space: String?)
    /// Puts one setting back to its default.
    case reset(key: String, space: String?)
    /// Writes the workspace's `format` file to `path`, replacing a file
    /// already there only when `replaces`.
    case export(path: String, format: TerminalExportFormat, replaces: Bool)
    /// Adds the Spaces, tabs and history of the browser-data file at `path`
    /// after this workspace's own; runs only when `confirmed`.
    case importFile(path: String, confirmed: Bool)
}

/// The files `arma settings export` writes, as Settings › Advanced offers them.
enum TerminalExportFormat: String, Codable, Sendable, CaseIterable {
    /// Every Space with its settings, tabs, folders and history, as JSON that
    /// `arma settings import` reads back.
    case browserData = "browser-data"
    /// Pinned and saved tabs as a bookmarks HTML file other browsers read.
    case bookmarks
}
