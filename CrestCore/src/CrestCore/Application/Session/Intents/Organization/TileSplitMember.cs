using CrestCore.Application;

namespace CrestCore.Contracts;

/// Moves a tab to where `Landing` says in its split's layout: beside another
/// of the split's cards, or beside one of its branches, along a branch that
/// already runs that way or in a new branch that takes the node's place.
/// Refused with `NotSplitMembers` when the tab is in no split or the landing
/// names nothing of its split, and with `NoSplitStep` when the move would
/// change nothing.
public sealed record TileSplitMember(Guid WorkspaceId, Guid SpaceId, Guid TabId, SplitLanding Landing) : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) =>
        workspace.Organizing(turn.Basis, SpaceId, SyncStaging.Edit, edited => {
            if (!edited.TileSplitMember(TabId, Landing, turn.Ids, turn.Now)) throw new Rejected(new NoSplitStep(TabId, 0));
        });

    #endregion
}
