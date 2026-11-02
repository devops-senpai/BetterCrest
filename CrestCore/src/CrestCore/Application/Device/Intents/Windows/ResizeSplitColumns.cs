using CrestCore.Application;

namespace CrestCore.Contracts;

/// Records the share each child of `BranchId`, a branch of a split group's
/// layout, takes of it in one window. Shares that drift from summing to one
/// are normalized; a list that cannot describe columns is refused with
/// `InvalidSplitColumnShares`.
public sealed record ResizeSplitColumns(Guid WindowId, Guid GroupId, Guid BranchId, IReadOnlyList<double> Shares) : WindowIntent {
    #region Actions - Device

    internal override void Apply(Device device, DeviceTurn turn) {
        var window = device.Opened(WindowId);
        var session = device.Workspace(window.WorkspaceId).Current;
        if (Window.SplitShares(Shares) is null) throw new Rejected(new InvalidSplitColumnShares());
        lock (device.Gate) Device.Publish(device.Changing([window], resized => {
            resized.Resize(GroupId, BranchId, Shares);
            resized.Repair(session);
        }, session), turn.Changes);
    }

    #endregion
}
