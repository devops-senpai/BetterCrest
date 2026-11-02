import Foundation

/// `arma download`: the downloads of the unlocked Spaces, as the core
/// records them.
///
/// A download is named by its identifier or the start of it that
/// `arma download list` prints.
enum TerminalDownloadCommand: Codable, Sendable {
    /// Every download with its state, progress, size and Space.
    case list
    /// Opens finished download `download`'s file.
    case open(download: String)
    /// Shows finished download `download`'s file in Finder.
    case reveal(download: String)
    /// Cancels download `download` while it runs.
    case cancel(download: String)
    /// Downloads `download` again, when the site's choices blocked it.
    case retry(download: String)
    /// Removes every download that ended from the list; files stay.
    case clear
}
