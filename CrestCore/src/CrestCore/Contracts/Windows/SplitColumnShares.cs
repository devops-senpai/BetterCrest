namespace CrestCore.Contracts;

/// The share of a branch of a split group's layout each of its children
/// takes in a window, in child order, summing to one. `BranchId` names the
/// branch; a split without a layout has one branch, named by the split.
public sealed record SplitColumnShares(Guid GroupId, Guid BranchId, IReadOnlyList<double> Shares) {
    #region Actions - Equality

    public bool Equals(SplitColumnShares? other) => other is not null && GroupId == other.GroupId && BranchId == other.BranchId
        && Shares.SequenceEqual(other.Shares);

    public override int GetHashCode() => HashCode.Combine(GroupId, BranchId, Shares.Count);

    #endregion
}
