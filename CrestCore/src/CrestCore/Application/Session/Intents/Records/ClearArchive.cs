using CrestCore.Application;

namespace CrestCore.Contracts;

/// Removes every tab a Space archived within `Range`, ending now, for good.
/// Without a Space it clears every Space this process may read, passing over
/// one that is locked or being deleted.
public sealed record ClearArchive(Guid WorkspaceId, Guid? SpaceId, BrowsingDataRange Range) : SessionIntent(WorkspaceId) {
    #region Actions - Session

    /// Drops the archived tabs within the range from each Space it reaches.
    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) {
        IEnumerable<SpaceState> spaces = SpaceId is { } spaceId
            ? [workspace.Editable(turn.Basis, spaceId)] : workspace.EditableSpaces(turn.Basis);
        var since = Range.Since(turn.Now);
        var cleared = spaces.Select(space => space with {
            ArchivedTabs = [.. space.ArchivedTabs.Where(archived => since is not null && archived.ArchivedAt < since)]
        });
        return new(turn.Basis.Replacing([.. cleared]), SyncStaging.Deletion);
    }

    #endregion
}
