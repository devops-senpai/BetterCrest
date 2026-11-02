import Foundation

/// Keeps a Space's folder overrides, which its looks name by folder path,
/// with their folders when a rename or a move changes those paths.
extension BrowserStore {
    // MARK: - Actions - Folder Overrides

    /// Runs `change`, a rename or move of folders in `spaceID`, and when it
    /// changed anything moves each override to its folder's new path, in the
    /// Space's look and its look for dark windows. Answers what `change` did.
    @discardableResult
    func keepingFolderOverrides(in spaceID: UUID, _ change: () -> Bool) -> Bool {
        guard let space = spaceModel(spaceID) else { return change() }
        let before = Dictionary(
            space.folders.models.map { (space.folderPath(of: $0), $0.id) }, uniquingKeysWith: { first, _ in first })
        guard change(), let after = spaceModel(spaceID) else { return false }
        let renamed: (String) -> String? = { path in
            before[path].flatMap(after.folders.model).map(after.folderPath(of:))
        }
        let look = after.settings.look
        if let moved = look.movingFolderOverrides(renamed), moved != look {
            updateSpaceBranding(moved.normalized(), in: spaceID)
        }
        if let dark = after.settings.darkBranding, let moved = dark.movingFolderOverrides(renamed), moved != dark {
            updateSpaceDarkBranding(moved.normalized(), in: spaceID)
        }
        return true
    }
}

extension SpaceBranding {
    // MARK: - Actions - Folder Overrides

    /// This look with each override's path replaced by what `renamed` says
    /// it is now, or nil for a look without overrides. An override whose
    /// folder is gone keeps its path.
    func movingFolderOverrides(_ renamed: (String) -> String?) -> SpaceBranding? {
        guard let overrides = folderOverrides?.overrides, !overrides.isEmpty else { return nil }
        var look = self
        look.folderOverrides = FolderColorOverrides(
            overrides: overrides.map { entry in
                var entry = entry
                entry.path = renamed(entry.path) ?? entry.path
                return entry
            })
        return look
    }
}
