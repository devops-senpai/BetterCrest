using System.Text.Json.Nodes;

using CrestCore.Application;
using CrestCore.Contracts;
using CrestCore.Domain;

using Xunit;

namespace CrestCore.Tests;

public sealed class SplitLayoutContractsTests {
    private static readonly DateTimeOffset Now = DateTimeOffset.Parse("2026-10-31T12:00:00Z");
    private static TabState Tab(string title) => new(Guid.NewGuid(), title, "https://example.com/" + title, null, null, "globe", null, null,
        null, TabPlacement.Current, null, null, Now, null, null, null, false);
    private static BrowserTabCollection Space(params TabState[] tabs) => BrowserTabCollection.Restore(tabs, [], []);
    private static string[] Titles(BrowserTabCollection space, Guid member) => [.. space.SplitMembers(member).Select(tab => tab.Title)];
    private static SplitGroupState Group(BrowserTabCollection space, Guid member) =>
        space.SplitGroups.Single(group => group.Id == space.Tab(member).SplitGroupId);

    [Fact]
    public void LandingBelowThenBesideTheSplitTilesQuadrantsAndOrdersTheMembersAsTheLayoutReads() {
        var a = Tab("a"); var b = Tab("b"); var c = Tab("c");
        var space = Space(a, b, c);
        var ids = new SystemIdSource();

        space.JoinSplit(b.Id, a.Id, null, new SplitLanding(a.Id, SplitSide.Below), ids, Now);
        var stacked = Group(space, a.Id).Layout!;
        Assert.Equal(SplitAxis.Vertical, stacked.Axis);
        Assert.Equal([a.Id, b.Id], stacked.Cards);
        Assert.Equal(["a", "b"], Titles(space, a.Id));

        space.JoinSplit(c.Id, a.Id, null, new SplitLanding(stacked.Id, SplitSide.Trailing), ids, Now.AddMinutes(1));
        var tiled = Group(space, a.Id).Layout!;
        Assert.Equal(SplitAxis.Horizontal, tiled.Axis);
        Assert.Equal(stacked, tiled.Children[0]);
        Assert.Equal(SplitLayoutNode.Card(c.Id), tiled.Children[1]);
        Assert.Equal(["a", "b", "c"], Titles(space, a.Id));

        Assert.True(space.TileSplitMember(a.Id, new SplitLanding(c.Id, SplitSide.Below), ids, Now.AddMinutes(2)));
        var moved = Group(space, a.Id).Layout!;
        Assert.Equal([b.Id, c.Id, a.Id], moved.Cards);
        Assert.Equal(SplitLayoutNode.Card(b.Id), moved.Children[0]);
        Assert.Equal(SplitAxis.Vertical, moved.Children[1].Axis);
        Assert.Equal(["b", "c", "a"], Titles(space, b.Id));
        Assert.False(space.TileSplitMember(a.Id, new SplitLanding(c.Id, SplitSide.Below), ids, Now.AddMinutes(3)));

        // A landing without a side changes places with that card.
        Assert.True(space.TileSplitMember(b.Id, new SplitLanding(a.Id, null), ids, Now.AddMinutes(3)));
        Assert.Equal(["a", "c", "b"], Titles(space, b.Id));
        Assert.Equal(SplitLayoutNode.Card(a.Id), Group(space, b.Id).Layout!.Children[0]);

        // An arrangement lays the members out in their order.
        space.ArrangeSplit(Group(space, b.Id).Id, SplitArrangement.TwoStackedThenOne, ids, Now.AddMinutes(4));
        var arranged = Group(space, b.Id).Layout!;
        Assert.Equal(SplitAxis.Horizontal, arranged.Axis);
        Assert.Equal([a.Id, c.Id], arranged.Children[0].Cards);
        Assert.Equal(SplitLayoutNode.Card(b.Id), arranged.Children[1]);
        Assert.IsType<ArrangementNeedsMembers>(Assert.Throws<Rejected>(() =>
            space.ArrangeSplit(arranged.Id, SplitArrangement.Grid, ids, Now.AddMinutes(5))).Rejection);

        // A row of columns in member order is no layout at all.
        space.ArrangeSplit(arranged.Id, SplitArrangement.ThreeAcross, ids, Now.AddMinutes(6));
        Assert.Null(Group(space, b.Id).Layout);
        space.LeaveSplit(a.Id, Now.AddMinutes(7));
        Assert.Null(Group(space, b.Id).Layout);
        Assert.Equal(["c", "b"], Titles(space, b.Id));
    }

    [Fact]
    public void MovingAColumnOfASplitWithNoRecordReordersItsMembers() {
        var a = Tab("a"); var b = Tab("b"); var c = Tab("c");
        var space = Space(a, b, c);
        var ids = new SystemIdSource();
        space.JoinSplit(b.Id, a.Id, null, null, ids, Now);
        space.JoinSplit(c.Id, a.Id, null, null, ids, Now);
        Assert.Equal(["a", "b", "c"], Titles(space, a.Id));

        Assert.True(space.TileSplitMember(c.Id, new SplitLanding(b.Id, SplitSide.Leading), ids, Now.AddMinutes(1)));
        Assert.Equal(["a", "c", "b"], Titles(space, a.Id));
    }

    [Fact]
    public void LayoutsSurviveTheStoredSessionAndTheSyncedRecordAndRepairAgainstTheMembers() {
        var a = Tab("a"); var b = Tab("b"); var c = Tab("c"); var gone = Guid.NewGuid();
        var branch = Guid.NewGuid();
        var layout = SplitLayoutNode.Branch(branch, SplitAxis.Vertical, [SplitLayoutNode.Card(a.Id), SplitLayoutNode.Card(gone),
            SplitLayoutNode.Card(b.Id)]);
        var group = new SplitGroupState(Guid.NewGuid(), Layout: layout, LayoutModifiedAt: Now);

        Assert.Equal(group, StoredSessionCodec.DecodeSplitGroup(StoredSessionCodec.Encode(group)));
        foreach (var form in SyncPayloadForm.All) {
            var payload = SplitGroupPayload.Normalized(new JsonArray(StoredSessionCodec.Encode(group)), form).Single();
            Assert.Equal(layout, payload.Layout);
            Assert.Equal(layout, SplitGroupPayload.Normalized(new JsonArray(payload.Encode(form)), form).Single().Layout);
        }

        // The tab the layout no longer has leaves, the member it never placed joins as a column beside the whole
        // stack, in a row named by the split, and the clock stays.
        var space = BrowserTabCollection.Restore([c with { SplitGroupId = group.Id }, a with { SplitGroupId = group.Id },
            b with { SplitGroupId = group.Id }], [], [group]);
        var repaired = space.SplitGroups.Single();
        Assert.Equal(Now, repaired.LayoutModifiedAt);
        Assert.Equal(SplitLayoutNode.Branch(group.Id, SplitAxis.Horizontal, [
            SplitLayoutNode.Branch(branch, SplitAxis.Vertical, [SplitLayoutNode.Card(a.Id), SplitLayoutNode.Card(b.Id)]),
            SplitLayoutNode.Card(c.Id)
        ]), repaired.Layout);
        Assert.Equal(["a", "b", "c"], space.Tabs.Select(tab => tab.Title));
    }
}
