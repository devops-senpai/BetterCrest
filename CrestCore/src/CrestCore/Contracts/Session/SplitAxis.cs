namespace CrestCore.Contracts;

/// Which way a branch of a split's layout lays its children out: side by
/// side, or one above the other. The stored session and the synced split
/// records spell an axis as its `Name`, so a name never changes. An axis
/// travels as its index in `All`, so `All` is append-only.
public sealed class SplitAxis {
    #region Static Variables

    public static readonly SplitAxis Horizontal = new(name: "horizontal", isHorizontal: true);
    public static readonly SplitAxis Vertical = new(name: "vertical", isHorizontal: false);

    public static IReadOnlyList<SplitAxis> All { get; } = [Horizontal, Vertical];

    #endregion

    #region Variables

    public string Name { get; }

    /// The children run across the branch, each a column of it; otherwise
    /// they stack down it, each a row.
    public bool IsHorizontal { get; }

    #endregion

    #region Constructors

    private SplitAxis(string name, bool isHorizontal) {
        Name = name;
        IsHorizontal = isHorizontal;
    }

    #endregion

    #region Actions - Lookup

    public static SplitAxis? Named(string? name) => All.FirstOrDefault(axis => axis.Name == name);

    #endregion
}
