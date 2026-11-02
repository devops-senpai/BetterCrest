using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// Gives a Space a look of its own for dark windows, within the ranges every
/// device draws, or takes it away so the Space wears one look in both
/// appearances.
public sealed record SetSpaceDarkBranding(Guid WorkspaceId, Guid SpaceId, SpaceBranding? Branding) : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) {
        workspace.RequireOwnedSpaces();
        var branding = Branding is { } chosen ? SpaceBranding.Normalized(chosen) : null;
        return workspace.SettingSpace(turn.Basis, workspace.Editable(turn.Basis, SpaceId),
            settings => settings with { DarkBranding = branding }, SyncStaging.Edit);
    }

    #endregion
}
