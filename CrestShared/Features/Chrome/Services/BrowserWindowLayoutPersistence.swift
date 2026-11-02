import CoreGraphics
import Foundation

@MainActor
struct BrowserWindowLayoutPersistence {
    let windowState: BrowserWindowStateStore?

    func restoreSidebarWidth(_ width: CGFloat, transaction: inout BrowserSidebarWidthTransaction) {
        guard windowState == nil, width != transaction.persistedWidth else { return }
        transaction.restore(persistedWidth: width)
    }

    /// Returns a fallback preference only when no per-window store is available.
    func commitSidebarWidth(_ width: CGFloat, transaction: inout BrowserSidebarWidthTransaction) -> CGFloat? {
        transaction.resize(to: width)
        guard let committedWidth = transaction.commit() else { return nil }
        guard let windowState else { return committedWidth }
        windowState.captureSidebar(width: Double(committedWidth))
        return nil
    }

    /// Starts the split on show from the shares the window kept for its
    /// branches; a branch without any spreads its children equally.
    func seedSplitLayout(groupID: UUID?, transaction: inout BrowserSplitLayoutTransaction) {
        transaction.begin(fractions: groupID.flatMap { windowState?.splitColumnFractions(for: $0) } ?? [:])
    }

    func commitSplitLayout(_ fractions: [Double], branchID: UUID, groupID: UUID?) {
        guard let windowState, let groupID else { return }
        windowState.captureSplitLayout(fractions: fractions, branchID: branchID, for: groupID)
    }
}
