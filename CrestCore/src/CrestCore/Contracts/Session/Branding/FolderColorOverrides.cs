namespace CrestCore.Contracts;

/// <summary>The colors one folder wears in place of its Space's, named by its
/// path: a dot and each folder's title from the top level down, such as
/// <c>.HomeLab.proxmox</c>. A color left null follows the Space's.</summary>
public sealed record FolderColorOverride(string Path, BrandColor? Color, BrandColor? BackColor, BrandColor? OutlineColor);

/// <summary>A Space look's folder overrides, at most one for each path, equal to
/// another that holds the same overrides in the same order.</summary>
public sealed record FolderColorOverrides(IReadOnlyList<FolderColorOverride> Overrides) {
    #region Static Variables

    /// The most overrides a look keeps, so a synced Space record stays small.
    public const int MaximumCount = 200;

    /// The longest path a look keeps, in characters.
    public const int MaximumPathLength = 512;

    #endregion

    #region Variables

    /// The set owns its overrides, including when a copy replaces them.
    public IReadOnlyList<FolderColorOverride> Overrides {
        get;
        init => field = [.. value];
    } = [.. Overrides];

    #endregion

    #region Actions - Reading

    /// The override for `path`, or null.
    public FolderColorOverride? For(string path) => Overrides.FirstOrDefault(entry => entry.Path == path);

    #endregion

    #region Actions - Equality

    public bool Equals(FolderColorOverrides? other) => other is not null && Overrides.SequenceEqual(other.Overrides);

    public override int GetHashCode() => Overrides.Aggregate(Overrides.Count, HashCode.Combine);

    #endregion
}
