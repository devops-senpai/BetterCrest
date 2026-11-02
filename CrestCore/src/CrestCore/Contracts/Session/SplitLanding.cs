namespace CrestCore.Contracts;

/// Where a tab lands in a split's layout: on `Side` of the node `NodeId`, a
/// card, which is one member tab, or a branch, which a window's content shows
/// as the cards it tiles together. Landing beside a split's outer branch puts
/// the tab beside the whole split, the full height or width of it. With no
/// side, a member of the split changes places with the card `NodeId`.
public sealed record SplitLanding(Guid NodeId, SplitSide? Side);
