import Foundation

/// What this window shows, read from the core's read model: the Space on
/// screen and the tab it shows there. Each reads only the slots it names.
extension BrowserStore {
    // MARK: - Variables

    /// The Space this window shows, or showed last once the core closed the
    /// window; nil while it is being deleted or once the core no longer holds
    /// it.
    var shownSpace: SpaceModel? {
        let spaceID = windowModel?.shownSpaceID ?? selectedSpaceID
        guard !isDeleting(spaceID) else { return nil }
        return spaceModel(spaceID)
    }

    /// The tab this window shows in the Space it shows, or nil for none: one
    /// the Space holds, or a pinned tab its group shares.
    var shownTab: TabStateModel? {
        guard let space = shownSpace, let tabID = selectedTabID(in: space.id) else { return nil }
        return space.shownTab(tabID)
    }

    /// The Spaces of this window's workspace, in order.
    var spaceModels: [SpaceModel] {
        workspaceModel?.spaces.models ?? []
    }

    /// The tabs this window's content shows side by side, in column order.
    var shownCards: [TabStateModel] {
        guard let space = shownSpace else { return [] }
        return cards(in: space)
    }

    /// Where the tab this window shows lives, for the page and palette
    /// actions that name a tab by its Space and profile.
    var shownTabAssignment: BrowserTabRuntimeAssignment? {
        guard let space = shownSpace, let tab = shownTab else { return nil }
        return BrowserTabRuntimeAssignment(tabID: tab.id, spaceID: space.id, profileID: space.profileID)
    }

    // MARK: - Actions - Reading

    /// The tabs this window's content shows side by side in `space`, in
    /// column order, or none where it shows no tab there.
    func cards(in space: SpaceModel) -> [TabStateModel] {
        (windowModel?.cards(in: space.id)?.tabIDs ?? []).compactMap { space.shownTab($0) }
    }

    /// The split the window shows in `space`, or nil for a tab shown alone.
    func shownSplitGroupID(in space: SpaceModel) -> UUID? {
        windowModel?.cards(in: space.id)?.splitGroupID
    }

    /// How the split the window shows in `space` tiles its cards, as the core
    /// keeps it, or nil for one row of columns or a tab shown alone.
    func shownSplitLayout(in space: SpaceModel) -> SplitLayoutNode? {
        guard let groupID = shownSplitGroupID(in: space) else { return nil }
        return space.splitGroups.first { $0.id == groupID }?.layout
    }

    /// The tile the window's content draws for `space`: the shown split's
    /// layout over its cards, or the lone card.
    func shownSplitTile(in space: SpaceModel) -> BrowserSplitTile {
        BrowserSplitTile.resolved(
            layout: shownSplitLayout(in: space), groupID: shownSplitGroupID(in: space),
            members: windowModel?.cards(in: space.id)?.tabIDs ?? [])
    }

    /// The landing `drop` names among the cards shown in `space`, as the core
    /// takes it: beside the card, or beside the whole split's outer node.
    func splitLanding(for drop: BrowserSplitDropLanding, in space: SpaceModel) -> SplitLanding? {
        switch drop {
        case .beside(let nodeID, let side):
            return SplitLanding(nodeID: nodeID, side: side)
        case .outside(let side):
            guard let nodeID = shownSplitTile(in: space).nodeID else { return nil }
            return SplitLanding(nodeID: nodeID, side: side)
        case .swapping(_, let nodeID):
            return SplitLanding(nodeID: nodeID, side: nil)
        }
    }

    /// The Space `assignment` names, while this device is not deleting it and
    /// it keeps that profile.
    func spaceModel(matching assignment: BrowserSpaceRuntimeAssignment) -> SpaceModel? {
        guard !isDeleting(assignment.spaceID), let space = spaceModel(assignment.spaceID),
            space.profileID == assignment.profileID
        else { return nil }
        return space
    }

    /// The Spaces this device is deleting, here or in the core.
    var deletingSpaceIDs: Set<UUID> {
        family.locallyDeletingSpaceIDs.union(workspaceModel?.spaceDeletions.map(\.spaceID) ?? [])
    }

    /// Whether this device is deleting the Space, here or in the core.
    func isDeleting(_ spaceID: UUID) -> Bool {
        family.locallyDeletingSpaceIDs.contains(spaceID)
            || workspaceModel?.spaceDeletions.contains { $0.spaceID == spaceID } == true
    }

    /// Whether this window can run `command` now by what it shows. Commands
    /// that act on a page also ask the page's engine.
    func allows(_ command: ShortcutCommand) -> Bool {
        windowModel?.unavailableCommands.contains(command) == false
    }
}
