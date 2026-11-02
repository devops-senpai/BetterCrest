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

    /// The color `folder` in `space` is drawn in: its path's override, else
    /// its own, else this Space's folder color, else the default every
    /// folder starts with.
    @MainActor
    func folderColor(of folder: FolderStateModel, in space: SpaceModel) -> BrandColor {
        if let color = folderOverride(of: folder, in: space)?.color { return color }
        return followsSpace(folder) ? folderColor ?? folder.displayColor : folder.displayColor
    }

    /// The color `folder`'s back face is drawn in: its path's override, else
    /// this Space's back color when the folder follows the Space. Nil leaves
    /// the artwork to shade the folder's color.
    @MainActor
    func folderBackColor(of folder: FolderStateModel, in space: SpaceModel) -> BrandColor? {
        folderOverride(of: folder, in: space)?.backColor ?? (followsSpace(folder) ? folderBackColor : nil)
    }

    /// The line drawn around `folder`: its path's override, else this
    /// Space's outline when the folder follows the Space.
    @MainActor
    func folderOutlineColor(of folder: FolderStateModel, in space: SpaceModel) -> BrandColor? {
        folderOverride(of: folder, in: space)?.outlineColor ?? (followsSpace(folder) ? folderOutlineColor : nil)
    }

    /// The colors this look gives `folder` in place of the Space's, named by
    /// the folder's path.
    @MainActor
    func folderOverride(of folder: FolderStateModel, in space: SpaceModel) -> FolderColorOverride? {
        let path = space.folderPath(of: folder)
        return folderOverrides?.overrides.first { $0.path == path }
    }

    /// This look with the override for `path` changed as `change` says; an
    /// override left with no color is removed.
    func withFolderOverride(_ path: String, _ change: (inout FolderColorOverride) -> Void) -> SpaceBranding {
        var entries = folderOverrides?.overrides ?? []
        var entry =
            entries.first { $0.path == path }
            ?? FolderColorOverride(path: path, color: nil, backColor: nil, outlineColor: nil)
        change(&entry)
        entries.removeAll { $0.path == path }
        if entry.color != nil || entry.backColor != nil || entry.outlineColor != nil { entries.append(entry) }
        var look = self
        look.folderOverrides = entries.isEmpty ? nil : FolderColorOverrides(overrides: entries)
        return look
    }

    /// Whether `folder` wears this Space's folder colors: it chose none, or
    /// what it holds is the default every folder starts with, which imports
    /// and older builds wrote into folders nobody colored.
    @MainActor
    private func followsSpace(_ folder: FolderStateModel) -> Bool {
        folder.color == nil || folder.color == .folderDefault
    }
}

extension SpaceModel {
    // MARK: - Actions - Folder Paths

    /// The path a folder's colors are named by: a dot and each folder's
    /// title from the top level down, such as `.HomeLab.proxmox`.
    @MainActor
    func folderPath(of folder: FolderStateModel) -> String {
        var titles = [folder.title]
        var parentID = folder.parentID
        var visited: Set<UUID> = [folder.id]
        while let id = parentID, visited.insert(id).inserted, let parent = folders.model(id) {
            titles.insert(parent.title, at: 0)
            parentID = parent.parentID
        }
        return "." + titles.joined(separator: ".")
    }
}
