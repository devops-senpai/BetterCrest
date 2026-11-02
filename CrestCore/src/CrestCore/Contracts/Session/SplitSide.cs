namespace CrestCore.Contracts;

/// The side of a split card a tab lands on when it joins beside that card:
/// the two sides along each axis. Landing on a side puts the newcomer next to
/// the card along `Axis`, before it or after it. A side travels as its index
/// in `All`, so `All` is append-only.
public sealed class SplitSide {
    #region Static Variables

    public static readonly SplitSide Leading = new(name: "leading", axis: SplitAxis.Horizontal, isAfter: false);
    public static readonly SplitSide Trailing = new(name: "trailing", axis: SplitAxis.Horizontal, isAfter: true);
    public static readonly SplitSide Above = new(name: "above", axis: SplitAxis.Vertical, isAfter: false);
    public static readonly SplitSide Below = new(name: "below", axis: SplitAxis.Vertical, isAfter: true);

    public static IReadOnlyList<SplitSide> All { get; } = [Leading, Trailing, Above, Below];

    #endregion

    #region Variables

    public string Name { get; }

    /// The axis the newcomer and the card share once it has landed.
    public SplitAxis Axis { get; }

    /// The newcomer comes after the card along the axis: to its right, or
    /// below it.
    public bool IsAfter { get; }

    #endregion

    #region Constructors

    private SplitSide(string name, SplitAxis axis, bool isAfter) {
        Name = name;
        Axis = axis;
        IsAfter = isAfter;
    }

    #endregion

    #region Actions - Lookup

    public static SplitSide? Named(string? name) => All.FirstOrDefault(side => side.Name == name);

    #endregion
}
