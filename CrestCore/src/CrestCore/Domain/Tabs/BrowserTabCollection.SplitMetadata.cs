using CrestCore.Contracts;

namespace CrestCore.Domain;

public sealed partial class BrowserTabCollection {
    #region Actions - Split metadata

    /// A split copied into new tabs keeps its name, icon and tint, each recorded
    /// as chosen now so the copy's fields win over nothing older, and its layout
    /// over the copies `renamed` names, or the layout the copy already chose.
    public void CopySplitMetadata(Guid source, Guid copy, DateTimeOffset now, IReadOnlyDictionary<Guid, Guid>? renamed = null) {
        if (splitGroups.FirstOrDefault(group => group.Id == source) is not { } metadata) return;
        var changedAt = BrowserEditTimestamp.Normalize(now);
        int index = splitGroups.FindIndex(group => group.Id == copy);
        var existing = index < 0 ? new SplitGroupState(copy) : splitGroups[index];
        var copied = existing with {
            CustomTitle = metadata.CustomTitle,
            TitleModifiedAt = changedAt,
            CustomIconSymbol = metadata.CustomIconSymbol,
            IconModifiedAt = changedAt,
            Tint = metadata.Tint,
            TintModifiedAt = changedAt
        };
        if (renamed is not null && metadata.Layout is { } layout)
            copied = copied.WithLayout(layout.Renamed(id => renamed.GetValueOrDefault(id, id)), now);
        if (index < 0) splitGroups.Add(copied);
        else splitGroups[index] = copied;
    }

    /// Drops what was chosen for splits no tab belongs to any longer.
    public void PruneSplitMetadata() {
        var retained = tabs.Where(tab => tab.SplitGroupId is not null).Select(tab => tab.SplitGroupId!.Value).ToHashSet();
        splitGroups.RemoveAll(group => !retained.Contains(group.Id));
    }

    #endregion
}
