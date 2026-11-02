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
        followsSpace(folder) ? folderColor ?? folder.displayColor : folder.displayColor
    }

    /// The color `folder`'s back face is drawn in, when the folder follows the
    /// Space and the Space names one. Nil leaves the artwork to shade the
    /// folder's own color.
    @MainActor
    func folderBackColor(of folder: FolderStateModel) -> BrandColor? {
        followsSpace(folder) ? folderBackColor : nil
    }

    /// The line drawn around `folder`, when the folder follows the Space and
    /// the Space names one.
    @MainActor
    func folderOutlineColor(of folder: FolderStateModel) -> BrandColor? {
        followsSpace(folder) ? folderOutlineColor : nil
    }

    /// Whether `folder` wears this Space's folder colors: it chose none, or
    /// what it holds is the default every folder starts with, which imports
    /// and older builds wrote into folders nobody colored.
    @MainActor
    private func followsSpace(_ folder: FolderStateModel) -> Bool {
        folder.color == nil || folder.color == .folderDefault
    }
}
