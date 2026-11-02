import Foundation

/// `arma command`: the commands of the menu bar and the command palette, run
/// in the front window as if the person picked them there.
///
/// A command is named by its id, such as `new-tab`, or by its title, such as
/// `New Tab`, in any case.
enum TerminalMenuCommand: Codable, Sendable {
    /// The commands the palette offers, only those whose id or title holds
    /// `search` when given.
    case list(search: String?)
    /// Runs command `name` in the front window.
    case run(name: String)
}
