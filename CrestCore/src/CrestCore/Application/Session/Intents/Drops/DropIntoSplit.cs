using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// Drops the lift on the cards a window shows, joining the split of
/// `TargetTabId`, one of them, where `Landing` says, or as the card at
/// `Index` or after the others when no landing is named. One tab joins as
/// `JoinSplit` joins it; any other lift as `SplitTabs` joins it. Refused with
/// `PinnedTabsStayPut` for a lift of several pinned tabs.
public sealed record DropIntoSplit(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection, Guid TargetTabId, int? Index,
    SplitLanding? Landing) : SidebarDrop(WorkspaceId, WindowId, SpaceId, Selection) {
    #region Actions - Session

    internal override SessionIntent Committed(NativeSessionAuthority.Lift lift, IIdSource ids) {
        if (lift.Alone is { } tab) return new JoinSplit(WorkspaceId, WindowId, SpaceId, tab.Id, TargetTabId, Index, Landing);
        return lift.PinsOnly
            ? throw new Rejected(new PinnedTabsStayPut())
            : new SplitTabs(WorkspaceId, WindowId, SpaceId, Selection, TargetTabId, Index, Landing);
    }

    #endregion
}
