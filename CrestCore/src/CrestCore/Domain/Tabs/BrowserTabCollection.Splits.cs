using CrestCore.Contracts;

namespace CrestCore.Domain;

public sealed partial class BrowserTabCollection {
    #region Variables

    public const int MaximumSplitMembers = 4;

    #endregion

    #region Actions - Splits

    private BrowserTab CopyTab(BrowserTab source, Guid id, DateTimeOffset now) => BrowserTab.Restore(source.State with {
        Id = id,
        Placement = TabPlacement.Current,
        FolderId = null,
        SplitGroupId = null,
        SavedUrl = null,
        LastActivatedAt = now,
        PositionModifiedAt = BrowserEditTimestamp.Normalize(now),
        TitleModifiedAt = source.CustomTitle is null ? null : BrowserEditTimestamp.Normalize(now),
        KeepsPageLoaded = false
    });

    public BrowserTab DuplicateTab(Guid sourceId, IIdSource ids, DateTimeOffset now,
        TabPlacement? placement = null, int? requestedIndex = null) {
        var source = Tab(sourceId);
        if (tabs.Count >= MaximumTabs) throw new Rejected(new TabLimitReached(MaximumTabs));
        var copy = CopyTab(source, ids.Next(), now);
        copy.Place(placement ?? TabPlacement.Current, null, now);
        InsertTab(copy, requestedIndex, duplicate: true);
        return copy;
    }

    // Saved and pinned tabs remain durable shortcuts. Joining them creates
    // current copies; the entire join is validated before changing either run.
    // The joiner lands where `landing` says in the split's layout, or as a
    // column at `memberIndex` of its outer row when no landing is named.
    public SplitJoin JoinSplit(Guid sourceId, Guid targetId, int? memberIndex, SplitLanding? landing, IIdSource ids, DateTimeOffset now) {
        var source = Tab(sourceId); var target = Tab(targetId);
        if (sourceId == targetId) throw new Rejected(new AlreadyInSplit(sourceId));
        var originalGroup = target.SplitGroupId;
        if (source.Content.IsStartPage || target.Content.IsStartPage)
            throw new Rejected(new WebPagesOnly(source.Content.IsStartPage ? sourceId : targetId));
        var targetMembers = SplitMembers(targetId);
        bool sameGroup = targetMembers.Any(t => t.Id == sourceId);
        if (sameGroup && memberIndex is null) throw new Rejected(new AlreadyInSplit(sourceId));
        if (!sameGroup && targetMembers.Count >= MaximumSplitMembers) throw new Rejected(new SplitLimitReached(MaximumSplitMembers));
        bool copyTarget = target.Placement.IsDurable && !sameGroup;
        bool copySource = source.Placement.IsDurable && !sameGroup;
        int copyCount = (copyTarget ? targetMembers.Count : 0) + (copySource ? 1 : 0);
        if (tabs.Count + copyCount > MaximumTabs) throw new Rejected(new TabLimitReached(MaximumTabs));

        var copies = new List<(Guid Source, Guid Copy)>();
        var members = new List<BrowserTab>();
        BrowserTab joiner = source;
        foreach (var member in targetMembers) {
            var resolved = copyTarget ? CopyTab(member, ids.Next(), now) : member;
            if (copyTarget) copies.Add((member.Id, resolved.Id));
            if (member.Id == sourceId) joiner = resolved;
            else members.Add(resolved);
        }
        if (copySource) {
            joiner = CopyTab(source, ids.Next(), now);
            copies.Add((source.Id, joiner.Id));
        }
        int slot = memberIndex is { } requested ? Math.Clamp(requested, 0, members.Count) : members.Count;
        members.Insert(slot, joiner);
        var group = copyTarget ? ids.Next() : target.SplitGroupId ?? ids.Next();
        var folder = copyTarget ? null : target.FolderId;
        var moving = members.Select(t => t.Id).ToHashSet();
        // Preserve empty folder positions when a current member leaves its old folder.
        var nextFolders = new FolderTree(folders).PreserveOrder(moving, tabs);
        var remaining = tabs.Where(t => !moving.Contains(t.Id)).ToList();
        int insertion;
        if (copyTarget) {
            insertion = remaining.FindIndex(t => !t.Placement.IsDurable);
            if (insertion < 0) insertion = remaining.Count;
        } else {
            int first = tabs.IndexOf(targetMembers[0]);
            insertion = tabs.Take(first).Count(t => !moving.Contains(t.Id));
        }
        foreach (var member in members) {
            member.Place(copyTarget ? TabPlacement.Current : target.Placement, folder, now, preservesSplit: true);
            member.SetSplit(group); member.MarkPosition(now);
        }
        remaining.InsertRange(insertion, members);
        tabs.Replace(remaining); folders.Clear(); folders.AddRange(nextFolders);
        NormalizeSplits(now);
        // The layout the target's split had, over the tabs that now hold it, with the joiner landed.
        var renamed = copies.ToDictionary(pair => pair.Source, pair => pair.Copy);
        var before = members.Where(member => member.Id != joiner.Id).Select(member => member.Id).ToArray();
        var layout = originalGroup is { } previous ? LayoutOf(previous)?.Renamed(id => renamed.GetValueOrDefault(id, id)) : null;
        var tree = SplitLayoutNode.Resolved(group, before, layout);
        SplitLayoutNode landed;
        if (landing is { Side: null } swap && sameGroup) {
            // A member dropped on another member's card changes places with it.
            landed = SplitLayoutNode.Resolved(group, [.. members.Select(member => member.Id)], layout)
                .Swapping(joiner.Id, renamed.GetValueOrDefault(swap.NodeId, swap.NodeId));
        } else if (landing is { } chosen) {
            landed = tree.Landing(joiner.Id, chosen with { NodeId = renamed.GetValueOrDefault(chosen.NodeId, chosen.NodeId) },
                renamed.GetValueOrDefault(targetId, targetId), ids);
        } else {
            landed = tree.InsertingColumn(joiner.Id, slot, group);
        }
        SetLayout(group, landed, now);
        return new(joiner.Id, copies);
    }

    /// Moves a member of a split to where `landing` says in the split's
    /// layout: beside one of its other cards, beside one of its branches, or,
    /// with no side, into another card's place, which takes its own. Refused
    /// with `NotSplitMembers` for a tab in no split or a landing on nothing of
    /// its split. Answers false when the move changes nothing.
    public bool TileSplitMember(Guid id, SplitLanding landing, IIdSource ids, DateTimeOffset now) {
        ArgumentNullException.ThrowIfNull(landing);
        var tab = Tab(id);
        if (tab.SplitGroupId is not { } group) throw new Rejected(new NotSplitMembers(id, landing.NodeId));
        var tree = ResolvedLayout(group);
        if (landing.NodeId == id || !tree.Holds(landing.NodeId)) throw new Rejected(new NotSplitMembers(id, landing.NodeId));
        SplitLayoutNode landed;
        if (landing.Side is null) {
            if (!tree.Cards.Contains(landing.NodeId)) throw new Rejected(new NotSplitMembers(id, landing.NodeId));
            landed = tree.Swapping(id, landing.NodeId);
        } else {
            var without = tree.Removing(id) ?? throw new Rejected(new NotSplitMembers(id, landing.NodeId));
            landed = without.Landing(id, landing, without.Id, ids);
        }
        if (landed.Normalized().Tiles(tree)) return false;
        SetLayout(group, landed, now);
        return true;
    }

    /// Lays the split out as `arrangement` says, its members in order.
    /// Refused with `UnknownSplitGroup` for a split of fewer than two tabs and
    /// `ArrangementNeedsMembers` for one the arrangement does not fit.
    public void ArrangeSplit(Guid group, SplitArrangement arrangement, IIdSource ids, DateTimeOffset now) {
        ArgumentNullException.ThrowIfNull(arrangement);
        var members = Run(group).Select(tab => tab.Id).ToArray();
        if (members.Length < 2) throw new Rejected(new UnknownSplitGroup(group));
        if (members.Length != arrangement.MemberCount) throw new Rejected(new ArrangementNeedsMembers(group, arrangement.MemberCount));
        SetLayout(group, arrangement.Layout(group, members, ids), now);
    }

    public void LeaveSplit(Guid id, DateTimeOffset now) {
        var tab = Tab(id);
        if (tab.SplitGroupId is not { } group) return;
        var members = SplitMembers(id);
        if (members.Count > 2 && members[^1] != tab) {
            tabs.Remove(tab);
            tabs.Insert(tabs.IndexOf(members[^1]) + 1, tab);
        }
        tab.SetSplit(null); tab.MarkPosition(now);
        if (LayoutOf(group) is { } layout) SetLayout(group, layout.Removing(id), now);
        NormalizeSplits(now);
    }

    public bool StepSplitMember(Guid id, int offset, DateTimeOffset now) {
        var members = SplitMembers(id);
        int current = members.ToList().FindIndex(t => t.Id == id);
        long destination = (long)current + offset;
        return offset != 0 && destination >= 0 && destination < members.Count
            && MoveSplitMember(id, (int)destination, now);
    }

    public bool DissolveSplit(Guid id, DateTimeOffset now) {
        var members = tabs.Where(t => t.SplitGroupId == id).ToArray();
        foreach (var tab in members) { tab.SetSplit(null); tab.MarkPosition(now); }
        return members.Length > 0;
    }

    internal void RepairSplitMembership() {
        var groups = SplitMember.Repair(tabs.Select(t => new SplitMember(t.SplitGroupId, t.Placement, t.FolderId)).ToArray());
        for (int index = 0; index < tabs.Count; index++) tabs[index].SetSplit(groups[index]);
        RepairSplitLayouts();
    }

    /// Each split's layout as its members render it, and the members in the
    /// order the layout reads them. A split whose run is too short to render
    /// keeps its layout, since the rest of a sync batch may not have arrived.
    private void RepairSplitLayouts() {
        for (int index = 0; index < splitGroups.Count; index++) {
            var group = splitGroups[index];
            if (group.Layout is null) continue;
            var members = Run(group.Id);
            if (members.Count < 2) continue;
            var repaired = group.Repaired([.. members.Select(tab => tab.Id)]);
            splitGroups[index] = repaired;
            if (repaired.Layout is { } layout) Reorder(group.Id, layout.Cards, null);
        }
    }

    #endregion

    #region Actions - Layout

    /// The layout a split keeps, or null for one row of columns.
    private SplitLayoutNode? LayoutOf(Guid group) => splitGroups.FirstOrDefault(candidate => candidate.Id == group)?.Layout;

    /// The layout a split renders with over its run.
    private SplitLayoutNode ResolvedLayout(Guid group) =>
        SplitLayoutNode.Resolved(group, [.. Run(group).Select(tab => tab.Id)], LayoutOf(group));

    /// Keeps `layout` as the split's, chosen now, and puts the members in the
    /// order it reads them. A flat layout is kept as none, and a split that
    /// has no record gets none for it.
    private void SetLayout(Guid group, SplitLayoutNode? layout, DateTimeOffset now) {
        var normalized = layout?.Normalized();
        int index = splitGroups.FindIndex(candidate => candidate.Id == group);
        if (index < 0) {
            // A row of columns needs no record, but its members still move.
            if (normalized is not null && !normalized.IsFlat) splitGroups.Add(new SplitGroupState(group).WithLayout(normalized, now));
        } else {
            splitGroups[index] = splitGroups[index].WithLayout(normalized, now);
        }
        if (normalized is not null) Reorder(group, normalized.Cards, now);
    }

    /// The first run of the split's tabs, in order.
    private List<BrowserTab> Run(Guid group) {
        int first = tabs.FindIndex(tab => tab.SplitGroupId == group);
        if (first < 0) return [];
        return tabs.Skip(first).TakeWhile(tab => tab.SplitGroupId == group).ToList();
    }

    /// Puts the split's run in `order`, marking the tabs that move at `now`
    /// when given. A run that is not exactly those tabs stays as it is.
    private void Reorder(Guid group, IReadOnlyList<Guid> order, DateTimeOffset? now) {
        var run = Run(group);
        if (run.Count != order.Count || !run.Select(tab => tab.Id).ToHashSet().SetEquals(order)) return;
        int first = tabs.IndexOf(run[0]);
        var ordered = order.Select(id => run.First(tab => tab.Id == id)).ToList();
        if (ordered.SequenceEqual(run)) return;
        var positions = run.ToDictionary(tab => tab.Id, tabs.IndexOf);
        var replaced = tabs.Where(tab => tab.SplitGroupId != group).ToList();
        replaced.InsertRange(first, ordered);
        tabs.Replace(replaced);
        if (now is not { } changedAt) return;
        foreach (var tab in run)
            if (tabs.IndexOf(tab) != positions[tab.Id]) tab.MarkPosition(changedAt);
    }

    #endregion

    #region Mutators

    public IReadOnlyList<BrowserTab> SplitMembers(Guid id) {
        var tab = Tab(id);
        if (tab.SplitGroupId is not { } group) return [tab];
        int index = tabs.IndexOf(tab), first = index, last = index;
        while (first > 0 && tabs[first - 1].SplitGroupId == group) first--;
        while (last + 1 < tabs.Count && tabs[last + 1].SplitGroupId == group) last++;
        return tabs.GetRange(first, last - first + 1);
    }

    #endregion
}
