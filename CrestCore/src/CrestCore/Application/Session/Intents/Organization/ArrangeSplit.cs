using CrestCore.Application;

namespace CrestCore.Contracts;

/// Lays the split `GroupId` out as `Arrangement` says, its members in their
/// order. Refused with `UnknownSplitGroup` for a split of fewer than two
/// tabs, and with `ArrangementNeedsMembers` for one whose member count the
/// arrangement does not lay out.
public sealed record ArrangeSplit(Guid WorkspaceId, Guid SpaceId, Guid GroupId, SplitArrangement Arrangement) : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) =>
        workspace.Organizing(turn.Basis, SpaceId, SyncStaging.Edit, edited => edited.ArrangeSplit(GroupId, Arrangement, turn.Ids, turn.Now));

    #endregion
}
