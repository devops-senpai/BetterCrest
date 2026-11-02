using CrestCore.Domain;

namespace CrestCore.Contracts;

/// A ready-made layout for a split of `MemberCount` tabs: `Groups` runs of
/// cards along `Axis`, each run of more than one card stacked the other way.
/// The members keep their order and fill the runs in turn. An arrangement
/// travels as its index in `All`, so `All` is append-only.
public sealed class SplitArrangement {
    #region Static Variables

    public static readonly SplitArrangement TwoAcross = new(name: "two-across", title: "Side by Side", SplitAxis.Horizontal, [1, 1]);
    public static readonly SplitArrangement TwoStacked = new(name: "two-stacked", title: "Stacked", SplitAxis.Vertical, [1, 1]);
    public static readonly SplitArrangement ThreeAcross = new(name: "three-across", title: "Three Across", SplitAxis.Horizontal, [1, 1, 1]);
    public static readonly SplitArrangement ThreeStacked = new(name: "three-stacked", title: "Three Stacked", SplitAxis.Vertical, [1, 1, 1]);
    public static readonly SplitArrangement OneThenTwoStacked = new(name: "one-then-two-stacked", title: "One Left, Two Stacked Right",
        SplitAxis.Horizontal, [1, 2]);
    public static readonly SplitArrangement TwoStackedThenOne = new(name: "two-stacked-then-one", title: "Two Stacked Left, One Right",
        SplitAxis.Horizontal, [2, 1]);
    public static readonly SplitArrangement OneThenTwoAcross = new(name: "one-then-two-across", title: "One Above, Two Below",
        SplitAxis.Vertical, [1, 2]);
    public static readonly SplitArrangement TwoAcrossThenOne = new(name: "two-across-then-one", title: "Two Above, One Below",
        SplitAxis.Vertical, [2, 1]);
    public static readonly SplitArrangement FourAcross = new(name: "four-across", title: "Four Across", SplitAxis.Horizontal, [1, 1, 1, 1]);
    public static readonly SplitArrangement FourStacked = new(name: "four-stacked", title: "Four Stacked", SplitAxis.Vertical, [1, 1, 1, 1]);
    public static readonly SplitArrangement Grid = new(name: "grid", title: "Grid", SplitAxis.Vertical, [2, 2]);
    public static readonly SplitArrangement OneThenThreeStacked = new(name: "one-then-three-stacked", title: "One Left, Three Stacked Right",
        SplitAxis.Horizontal, [1, 3]);
    public static readonly SplitArrangement ThreeStackedThenOne = new(name: "three-stacked-then-one", title: "Three Stacked Left, One Right",
        SplitAxis.Horizontal, [3, 1]);
    public static readonly SplitArrangement OneThenThreeAcross = new(name: "one-then-three-across", title: "One Above, Three Below",
        SplitAxis.Vertical, [1, 3]);
    public static readonly SplitArrangement ThreeAcrossThenOne = new(name: "three-across-then-one", title: "Three Above, One Below",
        SplitAxis.Vertical, [3, 1]);
    public static readonly SplitArrangement TwoStackedThenTwo = new(name: "two-stacked-then-two", title: "Two Stacked Left, Two Across Right",
        SplitAxis.Horizontal, [2, 1, 1]);
    public static readonly SplitArrangement TwoThenTwoStacked = new(name: "two-then-two-stacked", title: "Two Across Left, Two Stacked Right",
        SplitAxis.Horizontal, [1, 1, 2]);

    public static IReadOnlyList<SplitArrangement> All { get; } = [
        TwoAcross, TwoStacked, ThreeAcross, ThreeStacked, OneThenTwoStacked, TwoStackedThenOne, OneThenTwoAcross, TwoAcrossThenOne,
        FourAcross, FourStacked, Grid, OneThenThreeStacked, ThreeStackedThenOne, OneThenThreeAcross, ThreeAcrossThenOne,
        TwoStackedThenTwo, TwoThenTwoStacked
    ];

    #endregion

    #region Variables

    public string Name { get; }

    /// What the person calls the arrangement.
    [Localized]
    public string Title { get; }

    /// The axis the runs lie along.
    public SplitAxis Axis { get; }

    /// How many cards each run holds, in order along the axis.
    public IReadOnlyList<int> Groups { get; }

    /// How many tabs the arrangement lays out.
    public int MemberCount { get; }

    #endregion

    #region Constructors

    private SplitArrangement(string name, string title, SplitAxis axis, IReadOnlyList<int> groups) {
        Name = name;
        Title = title;
        Axis = axis;
        Groups = groups;
        MemberCount = groups.Sum();
    }

    #endregion

    #region Actions - Lookup

    public static SplitArrangement? Named(string? name) => All.FirstOrDefault(arrangement => arrangement.Name == name);

    #endregion

    #region Actions - Layout

    /// The layout the arrangement gives `members`, the split's tabs in order,
    /// named `groupId`; inner runs take names from `ids`.
    internal SplitLayoutNode Layout(Guid groupId, IReadOnlyList<Guid> members, IIdSource ids) {
        ArgumentNullException.ThrowIfNull(members);
        ArgumentNullException.ThrowIfNull(ids);
        var inner = Axis == SplitAxis.Horizontal ? SplitAxis.Vertical : SplitAxis.Horizontal;
        var children = new List<SplitLayoutNode>();
        int next = 0;
        foreach (int size in Groups) {
            var run = members.Skip(next).Take(size).Select(SplitLayoutNode.Card).ToArray();
            next += size;
            if (run.Length == 1) children.Add(run[0]);
            else children.Add(SplitLayoutNode.Branch(ids.Next(), inner, run));
        }
        return SplitLayoutNode.Branch(groupId, Axis, children);
    }

    #endregion
}
