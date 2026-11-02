using CrestCore.Domain;

namespace CrestCore.Contracts;

/// <summary>
/// One node of a split's layout, which tiles the split's cards: a card, which is
/// one member tab and whose <see cref="Id"/> is that tab's, or a branch, whose
/// <see cref="Children"/> run along <see cref="Axis"/> and whose <see cref="Id"/>
/// names it for the column shares a window keeps. A split without a layout is one
/// branch across, its members in order, named by the split's own id. Reading a
/// layout in order visits the cards in the order the Space keeps the members.
/// </summary>
public sealed record SplitLayoutNode(Guid Id, SplitAxis? Axis, IReadOnlyList<SplitLayoutNode> Children) {
    #region Static Variables

    /// The most nodes a layout holds: every card and every branch between them.
    public const int MaximumNodes = 2 * BrowserTabCollection.MaximumSplitMembers;

    #endregion

    #region Variables

    public IReadOnlyList<SplitLayoutNode> Children {
        get;
        init => field = [.. value];
    } = [.. Children];

    /// The node is a card: one member tab.
    public bool IsCard => Axis is null;

    /// The cards the node tiles, in order.
    public IReadOnlyList<Guid> Cards => IsCard ? [Id] : [.. Children.SelectMany(child => child.Cards)];

    /// Every branch of the node, itself first.
    public IEnumerable<SplitLayoutNode> Branches => IsCard ? [] : [this, .. Children.SelectMany(child => child.Branches)];

    /// Every node, itself included.
    public int Count => 1 + Children.Sum(child => child.Count);

    #endregion

    #region Actions - Making

    public static SplitLayoutNode Card(Guid tabId) => new(tabId, null, []);

    public static SplitLayoutNode Branch(Guid id, SplitAxis axis, IEnumerable<SplitLayoutNode> children) => new(id, axis, [.. children]);

    /// The layout of a split without one: one branch across, named by the
    /// split, its members in order.
    public static SplitLayoutNode Flat(Guid groupId, IEnumerable<Guid> members) => Branch(groupId, SplitAxis.Horizontal, members.Select(Card));

    /// The layout a split renders with: `layout` repaired against `members`,
    /// the split's tabs in order, or the flat layout when it has none or
    /// nothing of it survives.
    public static SplitLayoutNode Resolved(Guid groupId, IReadOnlyList<Guid> members, SplitLayoutNode? layout) {
        ArgumentNullException.ThrowIfNull(members);
        return layout?.Repaired(groupId, members) ?? Flat(groupId, members);
    }

    /// A branch id that no node of `layout` uses: the split's own, else one
    /// derived from it, the same on every device.
    public static Guid FreeId(Guid groupId, SplitLayoutNode? layout) {
        var id = groupId;
        while (layout?.Holds(id) == true) id = Derived(id);
        return id;
    }

    /// Whether the layout is one row of columns, which a split keeps as no
    /// layout at all, whatever the row is named.
    public bool IsFlat => Axis == SplitAxis.Horizontal && Children.All(child => child.IsCard);

    private static Guid Derived(Guid seed) {
        var bytes = seed.ToByteArray();
        for (int index = 0; index < bytes.Length; index++) bytes[index] = (byte)(bytes[index] ^ (0x5A + index));
        return new Guid(bytes);
    }

    #endregion

    #region Actions - Reading

    /// Whether a node of the layout, card or branch, has the id.
    public bool Holds(Guid id) => Id == id || Children.Any(child => child.Holds(id));

    /// Whether the layout tiles the same cards the same way as `other`,
    /// whatever its branches are named.
    public bool Tiles(SplitLayoutNode other) {
        ArgumentNullException.ThrowIfNull(other);
        if (IsCard || other.IsCard) return IsCard && other.IsCard && Id == other.Id;
        return Axis == other.Axis && Children.Count == other.Children.Count
            && Children.Zip(other.Children).All(pair => pair.First.Tiles(pair.Second));
    }

    #endregion

    #region Actions - Editing

    /// The layout with `tabId` landed on `side` of the node `nodeId`, a card
    /// or a branch: beside it in the branch that already runs that way, or in
    /// a new branch, named by `ids`, that takes the node's place. A node not
    /// in the layout leaves it unchanged.
    public SplitLayoutNode Inserting(Guid tabId, Guid nodeId, SplitSide side, IIdSource ids) {
        ArgumentNullException.ThrowIfNull(side);
        ArgumentNullException.ThrowIfNull(ids);
        if (Id == nodeId) return Branch(ids.Next(), side.Axis, side.IsAfter ? [this, Card(tabId)] : [Card(tabId), this]);
        if (IsCard) return this;
        int index = Children.ToList().FindIndex(child => child.Id == nodeId);
        if (index < 0) return this with { Children = [.. Children.Select(child => child.Inserting(tabId, nodeId, side, ids))] };
        var children = Children.ToList();
        if (Axis == side.Axis) children.Insert(side.IsAfter ? index + 1 : index, Card(tabId));
        else children[index] = children[index].Inserting(tabId, nodeId, side, ids);
        return this with { Children = children };
    }

    /// The layout with `tabId` landed as `landing` says, or beside `fallback`
    /// when the landing names a node the layout no longer has, or beside the
    /// whole layout when it has neither. A landing with no side, which means
    /// changing places with a card, lands after the node instead.
    public SplitLayoutNode Landing(Guid tabId, SplitLanding landing, Guid fallback, IIdSource ids) {
        ArgumentNullException.ThrowIfNull(landing);
        var node = Holds(landing.NodeId) ? landing.NodeId : Holds(fallback) ? fallback : Id;
        return Inserting(tabId, node, landing.Side ?? SplitSide.Trailing, ids);
    }

    /// The layout with `tabId` as a column of its outer branch at `index`,
    /// or after the others: beside the branch across, or beside the whole
    /// layout in a new branch across, named by `groupId` when free.
    public SplitLayoutNode InsertingColumn(Guid tabId, int? index, Guid groupId) {
        if (Axis == SplitAxis.Horizontal) {
            var children = Children.ToList();
            children.Insert(Math.Clamp(index ?? children.Count, 0, children.Count), Card(tabId));
            return this with { Children = children };
        }
        return Branch(FreeId(groupId, this), SplitAxis.Horizontal, index == 0 ? [Card(tabId), this] : [this, Card(tabId)]);
    }

    /// The layout without the card, every branch it empties closed; null for
    /// a layout that held nothing else.
    public SplitLayoutNode? Removing(Guid tabId) => Pruned(card => card != tabId, []);

    /// The layout with every branch of one child given way to it, every
    /// branch inside one that runs the same way merged into it, and a card
    /// named twice kept once.
    public SplitLayoutNode Normalized() => Pruned(_ => true, []) ?? this;

    /// The layout with the two cards' places exchanged.
    public SplitLayoutNode Swapping(Guid first, Guid second) => IsCard
        ? Id == first ? Card(second) : Id == second ? Card(first) : this
        : this with { Children = [.. Children.Select(child => child.Swapping(first, second))] };

    /// The layout with each card renamed as `rename` answers, for a split
    /// copied into new tabs.
    public SplitLayoutNode Renamed(Func<Guid, Guid> rename) {
        ArgumentNullException.ThrowIfNull(rename);
        return IsCard ? Card(rename(Id)) : this with { Children = [.. Children.Select(child => child.Renamed(rename))] };
    }

    #endregion

    #region Actions - Repair

    /// The layout as a split of `members` renders it: cards that are not
    /// members leave, a card named twice stays once, a branch with one child
    /// gives way to it, a branch inside one that runs the same way merges into
    /// it, and members the layout does not place join its outer branch across
    /// as columns. Null when fewer than two members remain, which a split then
    /// keeps as no layout.
    public SplitLayoutNode? Repaired(Guid groupId, IReadOnlyList<Guid> members) {
        ArgumentNullException.ThrowIfNull(members);
        var kept = members.ToHashSet();
        var pruned = Pruned(kept.Contains, []);
        var placed = pruned?.Cards.ToHashSet() ?? [];
        var missing = members.Where(member => !placed.Contains(member)).ToArray();
        var repaired = pruned;
        foreach (var member in missing) repaired = repaired is null ? Card(member) : repaired.InsertingColumn(member, null, groupId);
        return repaired is null || repaired.IsCard ? null : repaired;
    }

    /// The node with only the cards `keeps` answers for and `seen` has not
    /// met, normalized; null when none remain.
    private SplitLayoutNode? Pruned(Func<Guid, bool> keeps, HashSet<Guid> seen) {
        if (IsCard) return keeps(Id) && seen.Add(Id) ? this : null;
        var children = new List<SplitLayoutNode>();
        foreach (var child in Children) {
            if (child.Pruned(keeps, seen) is not { } kept) continue;
            if (!kept.IsCard && kept.Axis == Axis) children.AddRange(kept.Children);
            else children.Add(kept);
        }
        return children.Count switch {
            0 => null,
            1 => children[0],
            _ => this with { Children = children }
        };
    }

    #endregion

    #region Actions - Equality

    public bool Equals(SplitLayoutNode? other) => other is not null && Id == other.Id && Axis == other.Axis
        && Children.SequenceEqual(other.Children);

    public override int GetHashCode() => HashCode.Combine(Id, Axis, Children.Count);

    #endregion
}
