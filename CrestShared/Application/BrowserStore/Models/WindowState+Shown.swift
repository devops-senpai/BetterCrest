import Foundation

/// What a window shows, in the identities the browser uses. The core owns it;
/// these only read it.
extension WindowState {
    var shownSpace: UUID { shownSpaceID }

    /// The tab the window shows in a Space, or nil when it shows none there.
    func shownTabID(in spaceID: UUID) -> UUID? {
        shownTabs.first { $0.spaceID == spaceID }?.tabID
    }

    /// The shares the window keeps for each branch of a split group's layout
    /// it resized, by branch.
    func splitColumnFractions(for groupID: UUID) -> [UUID: [Double]] {
        splitColumnShares.filter { $0.groupID == groupID }
            .reduce(into: [:]) { result, shares in result[shares.branchID] = shares.shares }
    }

    /// A window that shows `spaceID`, on `tabs` in the Spaces they name, for a
    /// preview no core window backs.
    static func preview(showing spaceID: UUID, tabs: [UUID: UUID] = [:]) -> WindowState {
        WindowState(
            id: UUID(), workspaceID: UUID(), shownSpaceID: spaceID,
            shownTabs: tabs.map { ShownTab(spaceID: $0.key, tabID: $0.value) },
            splitColumnShares: [],
            cards: tabs.map { ShownCards(spaceID: $0.key, tabIDs: [$0.value], splitGroupID: nil) },
            unavailableCommands: [])
    }
}
