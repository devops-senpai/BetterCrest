using CrestCore.Application;

namespace CrestCore.Contracts;

/// Removes one tab from a Space's archive for good, so it can no longer be
/// restored. Refused with `UnknownArchivedTab` when the archive holds none
/// with `TabId`.
public sealed record RemoveArchivedTab(Guid WorkspaceId, Guid SpaceId, Guid TabId) : SessionIntent(WorkspaceId) {
    #region Actions - Session

    /// Drops the archived tab from the Space's archive.
    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) {
        var space = workspace.Editable(turn.Basis, SpaceId);
        if (!space.ArchivedTabs.Any(archived => archived.Tab.Id == TabId)) throw new Rejected(new UnknownArchivedTab(TabId));
        var remaining = space with { ArchivedTabs = [.. space.ArchivedTabs.Where(archived => archived.Tab.Id != TabId)] };
        return new(turn.Basis.Replacing([remaining]), SyncStaging.Deletion);
    }

    #endregion
}
