import SwiftUI

/// The whole of "Fancy Move": when a Split View card can be picked up, and
/// where the gap it leaves is standing while somebody is carrying one.
///
/// Every decision is arithmetic over frames and booleans, for the same reason
/// the surface's focus guards are: the gesture itself is a local `NSEvent`
/// monitor no unit test can drive, so what *is* testable has to be the answers
/// it asks for rather than the asking.
extension BrowserSplitCardLift {
    // MARK: - Static Variables

    /// The modifiers that turn a press into a carry: the same pair that moves a
    /// card by keyboard.
    ///
    /// ⇧⌘← and ⇧⌘→ already mean "move this card one place"; ⇧⌘ and the pointer
    /// means "move this card to wherever I put it". One idea, one binding,
    /// reached two ways.
    static let carryModifiers: BrowserKeyboardModifierFlags = [.command, .shift]

    // MARK: - Actions - Carrying

    /// Whether a modified mouse-down lifts the card it landed in.
    ///
    /// The guards, in the order they read:
    ///
    /// - **⇧⌘, and nothing else.** The bare click is how focus moves between
    ///   cards, and how web content receives every click somebody makes;
    ///   reordering has to ask for itself. The match is exact rather than a
    ///   containment test, so ⌥⇧⌘ and ⌃⇧⌘ stay available to the page and to
    ///   whatever else may want them.
    /// - **Inside a card.** The insets around the row, and the row's own gaps,
    ///   are not cards.
    /// - **Not a divider.** The handles overhang the cards they separate, so a
    ///   point a few units inside a card's edge is both inside that card and
    ///   under the control that resizes it. The resize wins: it is the older
    ///   affordance and the one already under the pointer's own cursor.
    /// - **More than one card.** A lone card has nowhere to go.
    /// - **No sidebar drag, no command palette.** Both already own the pointer,
    ///   exactly as they do for click-to-focus.
    ///
    /// Focus is deliberately absent from this list, and the omission is the
    /// point: the card somebody is pointing at is the card they may pick up,
    /// whether or not the chrome is currently speaking for it. Nothing here can
    /// tell the focused card apart from any other.
    static func picksUp(
        modifiers: BrowserKeyboardModifierFlags,
        isInsideCard: Bool,
        isOverDivider: Bool,
        memberCount: Int,
        isDraggingSidebarItem: Bool,
        isCommandPalettePresented: Bool
    ) -> Bool {
        modifiers == carryModifiers
            && isInsideCard
            && !isOverDivider
            && memberCount > 1
            && !isDraggingSidebarItem
            && !isCommandPalettePresented
    }

    /// The card `point` landed in, resolved against the row's own membership.
    ///
    /// The registry is keyed by tab and outlives the cards in it: a member the
    /// row is animating out keeps its frame until SwiftUI runs its
    /// disappearance, and a frame left behind by a card that has gone overlaps
    /// the cards that closed up around it. A lookup over the registry alone
    /// therefore has two ways to answer wrongly — with a tab that is no longer a
    /// member, or with whichever of two overlapping frames a dictionary happened
    /// to visit first — and a pickup that resolved a stranger simply refused,
    /// silently, leaving the press to be an ordinary click.
    ///
    /// Asking the members first removes both. Membership is the row's order, the
    /// answer carries the slot as well as the tab, and a frame belonging to
    /// nobody on show is not a card anybody can be pointing at.
    static func card<Member: Identifiable>(
        at point: CGPoint,
        members: [Member],
        cardFrames: [UUID: CGRect]
    ) -> (tabID: UUID, index: Int, frame: CGRect)? where Member.ID == UUID {
        for (index, member) in members.enumerated() {
            guard let frame = cardFrames[member.id],
                !frame.isEmpty,
                frame.contains(point)
            else { continue }
            return (member.id, index, frame)
        }
        return nil
    }

    /// Whether `point` belongs to the divider between two cards rather than to
    /// the card whose frame contains it.
    ///
    /// Measured from the cards themselves rather than from a handle's frame, for
    /// the same reason a divider drag is: the handles are positioned from the
    /// frames the tiles are drawing, so the cards are the only geometry that is
    /// true before the handle has been laid out. Restricted to members for the
    /// same reason `card(at:members:cardFrames:)` is: a frame left behind by a
    /// departing card sits between two that are still there.
    static func isOverDivider<Member: Identifiable>(
        _ point: CGPoint,
        members: [Member],
        cardFrames: [UUID: CGRect],
        panelFrame: CGRect? = nil
    ) -> Bool where Member.ID == UUID {
        BrowserSplitTileLayout.isOverDivider(
            point, cardFrames: members.compactMap { cardFrames[$0.id] } + (panelFrame.map { [$0] } ?? []))
    }

    /// Where the carried card would land, from where the pointer is and where
    /// the cards stood when it was picked up.
    ///
    /// The frames are the ones from pickup, never the tiles as the gap has
    /// rearranged them: measured against cards that stepped aside for the
    /// gap, the pointer would aim somewhere else and the gap would chase it
    /// back and forth with every sample. Over the card's own place, it goes
    /// back to `origin`. Elsewhere the card is excluded and the same aim a
    /// drag from the sidebar uses runs over the others; the landing the gap
    /// is drawn at is the landing the release commits. Nil beyond the outer
    /// band around every card, or with no other card measured, which keeps
    /// the gap where it was — so a card carried from a menu keeps its place
    /// until the pointer first reaches the tiles.
    static func landing(
        at point: CGPoint,
        cardFrames: [UUID: CGRect],
        lifted liftedTabID: UUID,
        origin: BrowserSplitDropLanding,
        rightToLeft: Bool = false
    ) -> BrowserSplitDropLanding? {
        let frames = cardFrames.values.filter { !$0.isEmpty }
        if let own = cardFrames[liftedTabID], !own.isEmpty, own.contains(point) { return origin }
        let band = BrowserSplitDropLanding.outerBand
        let reach = frames.reduce(CGRect.null) { $0.union($1) }.insetBy(dx: -band, dy: -band)
        guard !reach.isNull, reach.contains(point) else { return nil }
        return BrowserSplitDropLanding.aimed(
            at: point, cardFrames: cardFrames, member: liftedTabID, rightToLeft: rightToLeft)
    }

    /// Where inside the card the pointer took hold, as a fraction of it on each
    /// axis.
    ///
    /// The preview is scaled about this point rather than about its centre, so
    /// the pixel somebody grabbed stays under the cursor for the whole carry
    /// however far the card rises.
    static func grabFraction(pointer: CGPoint, in cardFrame: CGRect) -> CGPoint {
        CGPoint(
            x: fraction(pointer.x - cardFrame.minX, of: cardFrame.width),
            y: fraction(pointer.y - cardFrame.minY, of: cardFrame.height)
        )
    }

    /// A degenerate card is grabbed in the middle, which is the one answer that
    /// cannot put the preview somewhere absurd.
    private static func fraction(
        _ distance: CGFloat,
        of extent: CGFloat
    ) -> CGFloat {
        guard extent > 0, distance.isFinite else { return 0.5 }
        return min(max(distance / extent, 0), 1)
    }
}
