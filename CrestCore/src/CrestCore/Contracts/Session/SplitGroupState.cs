using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// <summary>
/// What a person chose for a split: its name, icon and tint, each with the time it
/// last changed so devices merge the fields independently, and <see cref="Layout"/>,
/// how its cards tile the window, or null for one row of columns in member order.
/// Membership stays on the tabs, whose <see cref="TabState.SplitGroupId"/> names
/// this group.
/// </summary>
public sealed record SplitGroupState(
    Guid Id,
    string? CustomTitle = null,
    DateTimeOffset? TitleModifiedAt = null,
    string? CustomIconSymbol = null,
    DateTimeOffset? IconModifiedAt = null,
    BrandColor? Tint = null,
    DateTimeOffset? TintModifiedAt = null,
    SplitLayoutNode? Layout = null,
    DateTimeOffset? LayoutModifiedAt = null) {
    #region Static Variables

    /// The fewest tabs of one split a sidebar or a window shows as a split. A shorter
    /// run keeps its membership, so a staggered sync can bring the rest, and shows as
    /// plain tabs until it does.
    public const int MinimumShownMembers = 2;

    #endregion

    #region Variables

    /// The title a split shows while no one has named it.
    [Localized]
    public string DefaultTitle => "Split View";

    public string DefaultTitleComment => "The title of a split view no one has named.";

    /// <summary>The title a person gave the split, trimmed, or null for a split that shows
    /// <see cref="DefaultTitle"/>. A blank title, however it arrived, is none.</summary>
    [Resolved]
    public string? DisplayTitle => string.IsNullOrWhiteSpace(CustomTitle) ? null : CustomTitle.Trim();

    /// <summary>The emoji the split shows as its icon, or null when it shows none.</summary>
    [Resolved]
    public string? DisplayEmojiIcon => EmojiIcon.Parse(CustomIconSymbol)?.Emoji;

    #endregion

    #region Actions - Layout

    /// The layout the split renders `members`, its tabs in order, with: its
    /// own repaired against them, or one row of columns.
    public SplitLayoutNode ResolvedLayout(IReadOnlyList<Guid> members) => SplitLayoutNode.Resolved(Id, members, Layout);

    /// The record with `layout` as the layout chosen at `now`: a flat layout
    /// is kept as none.
    internal SplitGroupState WithLayout(SplitLayoutNode? layout, DateTimeOffset now) {
        var chosen = layout is { IsFlat: true } ? null : layout;
        return chosen == Layout ? this : this with { Layout = chosen, LayoutModifiedAt = BrowserEditTimestamp.Normalize(now) };
    }

    /// The record with its layout repaired against `members`, the split's
    /// tabs in order, keeping the clock: repair is no one's edit.
    internal SplitGroupState Repaired(IReadOnlyList<Guid> members) {
        if (Layout is null) return this;
        var repaired = Layout.Repaired(Id, members);
        if (repaired is { IsFlat: true }) repaired = null;
        return repaired == Layout ? this : this with { Layout = repaired };
    }

    #endregion

    #region Actions - Repair

    /// One metadata record per split. Repeated records merge field by field, the
    /// later clock winning; the chosen icon stays opaque to the core.
    internal static IReadOnlyList<SplitGroupState> Merged(IReadOnlyList<SplitGroupState> source) {
        var groups = new List<SplitGroupState>();
        foreach (var group in source) {
            var normalized = group with {
                CustomTitle = string.IsNullOrWhiteSpace(group.CustomTitle) ? null : group.CustomTitle.Trim(),
                TitleModifiedAt = Normalized(group.TitleModifiedAt),
                IconModifiedAt = Normalized(group.IconModifiedAt),
                TintModifiedAt = Normalized(group.TintModifiedAt),
                LayoutModifiedAt = Normalized(group.LayoutModifiedAt)
            };
            int index = groups.FindIndex(candidate => candidate.Id == group.Id);
            if (index < 0) { groups.Add(normalized); continue; }
            var previous = groups[index];
            if (PreviousWins(previous.TitleModifiedAt, normalized.TitleModifiedAt))
                normalized = normalized with { CustomTitle = previous.CustomTitle, TitleModifiedAt = previous.TitleModifiedAt };
            if (PreviousWins(previous.IconModifiedAt, normalized.IconModifiedAt))
                normalized = normalized with { CustomIconSymbol = previous.CustomIconSymbol, IconModifiedAt = previous.IconModifiedAt };
            if (PreviousWins(previous.TintModifiedAt, normalized.TintModifiedAt))
                normalized = normalized with { Tint = previous.Tint, TintModifiedAt = previous.TintModifiedAt };
            if (PreviousWins(previous.LayoutModifiedAt, normalized.LayoutModifiedAt))
                normalized = normalized with { Layout = previous.Layout, LayoutModifiedAt = previous.LayoutModifiedAt };
            groups[index] = normalized;
        }
        return [.. groups];
    }

    private static DateTimeOffset? Normalized(DateTimeOffset? clock) => clock is { } value ? BrowserEditTimestamp.Normalize(value) : null;

    /// Whether an earlier record's field wins over a repeated record's.
    private static bool PreviousWins(DateTimeOffset? previous, DateTimeOffset? current) =>
        SyncRecordStamp.Later(current is { } value ? StoredSessionCodec.Seconds(value) : null,
            previous is { } earlier ? StoredSessionCodec.Seconds(earlier) : null) == 1;

    #endregion
}
