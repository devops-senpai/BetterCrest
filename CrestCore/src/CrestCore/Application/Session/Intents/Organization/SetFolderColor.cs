using CrestCore.Application;

namespace CrestCore.Contracts;

/// Gives a folder the color its icon wears, or with no color lets it wear
/// its Space's folder colors again.
public sealed record SetFolderColor(Guid WorkspaceId, Guid SpaceId, Guid FolderId, BrandColor? Color) : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) =>
        workspace.Organizing(turn.Basis, SpaceId, SyncStaging.Edit, edited => edited.SetFolderColor(FolderId, Color));

    #endregion
}
