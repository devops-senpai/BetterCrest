import Foundation

/// The colors a Space's folders wear: each folder's own, or the Space's
/// folder colors for one that chose none.
extension SpaceBranding {
    // MARK: - Variables

    /// The folder color the Space's own folders show: the chosen one, or the
    /// default a folder starts with.
    var resolvedFolderColor: BrandColor {
        folderColor ?? .folderDefault
    }

    /// The back face the Space's own folders show: the chosen one, or the
    /// resolved folder color shaded as the artwork shades it.
    var resolvedFolderBackColor: BrandColor {
        folderBackColor ?? resolvedFolderColor.folderBackShade
    }

    // MARK: - Actions - Folder Colors

    /// The color `folder` is drawn in: its own, else this Space's folder
    /// color, else the default every folder starts with.
    @MainActor
    func folderColor(of folder: FolderStateModel) -> BrandColor {
        folder.color ?? folderColor ?? folder.displayColor
    }

    /// The color `folder`'s back face is drawn in, when the folder follows the
    /// Space and the Space names one. Nil leaves the artwork to shade the
    /// folder's own color.
    @MainActor
    func folderBackColor(of folder: FolderStateModel) -> BrandColor? {
        folder.color == nil ? folderBackColor : nil
    }
}
