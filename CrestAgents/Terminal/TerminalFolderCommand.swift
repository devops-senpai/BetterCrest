import Foundation

/// `arma folder`: the folders of a Space's sidebar, in its saved section and
/// its open-tabs section.
///
/// A folder is named by its path in its Space: folder names joined with `/`,
/// such as `Work/Clients`, or one name anywhere in the Space when it is
/// unique. Each action acts on the front window's Space unless `space` names
/// another.
enum TerminalFolderCommand: Codable, Sendable {
    /// The folders of `space`, or of every Space, as a tree with the tabs
    /// each holds.
    case list(space: String?)
    /// Makes a folder `name`, inside folder `parent` when given, in the saved
    /// section, or in the open-tabs section when `open`.
    case create(name: String, space: String?, parent: String?, open: Bool)
    /// Renames folder `folder` to `name`.
    case rename(folder: String, name: String, space: String?)
    /// Deletes folder `folder`. Its tabs stay in its section, and the folders
    /// inside it move up one level.
    case delete(folder: String, space: String?)
    /// Files `tabs` into folder `folder`.
    case add(tabs: [String], folder: String, space: String?)
    /// Expands folder `folder` in the sidebar, or collapses it when not
    /// `expanded`.
    case expand(folder: String, space: String?, expanded: Bool)
    /// Gives folder `folder` the color `hex`, or lets it wear its Space's
    /// folder colors again when `hex` is nil.
    case color(folder: String, hex: String?, space: String?)
}
