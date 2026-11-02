import SwiftUI

/// Crest's split-view layout manager: the cards a window shows, tiled as the
/// split's layout says, the gaps between them, and the dividers in those gaps.
///
/// The view owns geometry and nothing else. Frames come from
/// `BrowserSplitTileLayout`, membership and the layout come from the session,
/// and what a card actually shows comes from `content` — which is what lets
/// macOS hand it live web views and iPadOS hand it its own hosts without either
/// platform re-deriving a tile. The single-card case is deliberately not
/// special: a window presenting one tab is a lone card with no dividers and no
/// focus ring.
///
/// Four conventions the callers depend on:
///
/// - The outer page insets are applied here, once, so a card can wrap itself in
///   `BrowserRootContentSurface` with zero insets of its own and the tiles still
///   read as the single evenly inset page surface they replace. Breathing room
///   between cards is the gap, never a card's padding.
/// - A drag's drop placeholder is a tile, not an ornament. Members and
///   placeholder are one `BrowserSplitColumnSlot` list laid out by one tile,
///   so the slot under the pointer is already the exact frame the card that
///   lands in it will have.
/// - Every card is positioned by frame in one `ZStack`, never nested in stacks
///   that follow the tree. `ForEach` identity is the card's tab, so a focus
///   change, a resize, a neighbour arriving, a branch opening around a card,
///   or the drop itself updates the card's host rather than remounting it. A
///   remounted host would hand a live `WKWebView` to a second superview.
/// - A card carried out of the tiles on the pointer is *not* a fourth kind of
///   slot. It is still its own member, at whichever landing the carry has
///   reached, and it simply stops drawing. That is what lets a whole move
///   happen with the lifted card's host, and the live web view inside it,
///   untouched — and it is why the tiles are already in the shape the drop
///   commits before the session has heard about it.
///
/// The tiles are also the coordinate space every divider drag is measured in.
/// They declare `BrowserSplitResizeSpace` here, once, because they are the last
/// thing in the hierarchy that stays put while fractions change: the handles
/// below are positioned from those fractions and travel with the boundaries
/// they move. A resize also writes without an implicit animation — the settle
/// animation below belongs to a tile opening or closing, not to pointer
/// tracking, which has to land on the frame it was measured for.
struct BrowserSplitTilesView<Member: Identifiable, Content: View, Panel: View>: View where Member.ID == UUID {
    /// The presented cards, in session member order.
    let members: [Member]
    /// How the cards tile: the core's layout for the split on show, or nil for
    /// one row of columns.
    let layout: SplitLayoutNode?
    /// The split the cards belong to, which names its outer row; nil for a
    /// lone card.
    let groupID: UUID?
    /// The one card browser chrome speaks for.
    let focusedTabID: UUID?
    /// The page insets the whole row sits inside, leading-zeroed when the row
    /// adjoins a docked sidebar.
    let frameInsets: EdgeInsets
    /// The Space accent the focus ring is drawn in.
    let accent: Color
    /// Where a drag in flight would land a card, or nil to lay the tiles out
    /// with no placeholder.
    let placeholder: BrowserSplitDropLanding?
    /// The member a drag from the sidebar is, when it is one: its card leaves
    /// its own tile for the placeholder, so the preview shows the move the
    /// drop makes rather than a card more than the split will have.
    var placeholderMover: UUID? = nil
    /// The member currently carried on the pointer, if any, and where the
    /// carry has taken it. The tiles draw that member there as the gap — an
    /// empty tile of exactly the size and position the card will drop back
    /// into.
    let lift: (tabID: UUID, landing: BrowserSplitDropLanding)?
    @Binding var layoutTransaction: BrowserSplitLayoutTransaction
    /// The shares a completed divider drag settled on, worth persisting.
    let onResizeCommit: (UUID, [Double]) -> Void
    /// A request to make one card the focused one.
    let onFocus: (UUID) -> Void
    let usesTransparentInnerSurface: (Member) -> Bool
    @ViewBuilder let content: (Member, Bool) -> Content
    let panel: BrowserSplitPanelColumn?
    let onPanelResizeCommit: (CGFloat) -> Void
    @ViewBuilder let panelContent: Panel

    @Environment(\.browserWindowCornerRadius) private var windowCornerRadius
    @Environment(\.browserSplitUsesBorderlessFrame) private var borderless
    @Environment(\.browserSplitInterCardGap) private var interCardGap
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var panelWidthTransaction = BrowserSplitPanelWidthTransaction()

    private var appearance: BrowserChromeAppearance { .device(windowCornerRadius: windowCornerRadius) }

    var body: some View {
        GeometryReader { proxy in
            tiles(containerSize: proxy.size)
        }
        .padding(frameInsets)
        // Keyed on the tile rather than on membership alone, so the drop tile
        // opening, moving between landings, and closing again all settle with
        // the same motion a member joining or leaving does.
        .animation(
            CrestMotion.collection.unlessReducingMotion(reduceMotion),
            value: displayTile
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Split View Columns")
        .onChange(of: panel) {
            panelWidthTransaction = BrowserSplitPanelWidthTransaction()
        }
        .onChange(of: displayTile) { _, tile in
            DiagnosticLog.splits.notice(
                "Split tiles \(tile.summary) for \(members.count) member(s), placeholder: \(placeholder != nil), "
                    + "lift: \(lift?.tabID.uuidString.prefix(8) ?? "none")")
        }
    }

    private func tiles(containerSize: CGSize) -> some View {
        let memberWidth = memberContainerWidth(containerWidth: containerSize.width)
        let frames = BrowserSplitTileLayout.frames(
            of: displayTile,
            in: CGRect(x: 0, y: 0, width: memberWidth, height: containerSize.height),
            fractions: layoutTransaction.fractions(for:),
            gap: interCardGap
        )
        let panelWidth = resolvedPanelWidth(containerWidth: containerSize.width)
        return ZStack(alignment: .topLeading) {
            Color.clear
                .onChange(of: frames, initial: true) { _, settled in
                    let cards = settled.cards.map { card in
                        "\(card.key.uuidString.prefix(8))=\(Int(card.value.minX)),\(Int(card.value.minY)) "
                            + "\(Int(card.value.width))x\(Int(card.value.height))"
                    }
                    DiagnosticLog.splits.notice(
                        "Split frames in \(Int(containerSize.width))x\(Int(containerSize.height)): "
                            + cards.sorted().joined(separator: "; "))
                }
            ForEach(slots, id: \.id) { slot in
                let frame = self.frame(
                    of: slot, in: frames, panelWidth: panelWidth, containerSize: containerSize,
                    memberWidth: memberWidth)
                columnSlot(slot, frame: mirrored(frame, in: containerSize.width))
                    .zIndex(cardZIndex(for: slot))
            }
            if showsDividers {
                ForEach(frames.dividers) { divider in
                    dividerHandle(divider, frame: mirrored(divider.frame, in: containerSize.width))
                }
                if panel != nil, panelWidth > 0 {
                    let handleWidth = BrowserSplitLayoutMetrics.resizeHandleHitWidth
                    panelDivider(
                        frame: mirrored(
                            CGRect(
                                x: memberWidth + interCardGap / 2 - handleWidth / 2, y: 0,
                                width: handleWidth, height: containerSize.height),
                            in: containerSize.width),
                        panelWidth: panelWidth)
                }
            }
        }
        .coordinateSpace(BrowserSplitResizeSpace.coordinateSpace)
    }

    /// One slot: the shared page surface, at the frame the tiles gave it, with
    /// the adornments only a real member carries.
    @ViewBuilder
    private func columnSlot(_ slot: BrowserSplitColumnSlot<Member>, frame: CGRect) -> some View {
        let surface = slotSurface(slot).frame(width: max(frame.width, 0), height: max(frame.height, 0))
            .offset(x: frame.minX, y: frame.minY)

        switch slot {
        case .member(let member):
            // One view type whether the card is on show or is the gap a carry
            // left, so picking a card up and putting it down never changes
            // the identity of its host: a remounted host would hand the live
            // page view to a second superview, and an engine that was told to
            // hide and show the page in one frame can leave it blank. The gap
            // wears none of the adornments of a card that is present — no
            // focus ring around an empty tile, no invitation to focus a card
            // nobody can see — and leaves the accessibility tree for as long
            // as the carry lasts.
            let isGap = member.id == lift?.tabID
            surface
                .overlay {
                    if !isGap, members.count > 1 {
                        BrowserSplitCardFocusIndicator(
                            isFocused: member.id == focusedTabID,
                            accent: accent,
                            cornerRadius: borderless ? 0 : appearance.framedPageCornerRadius
                        )
                        .frame(width: max(frame.width, 0), height: max(frame.height, 0))
                        .offset(x: frame.minX, y: frame.minY)
                    }
                }
                .accessibilityHidden(isGap)
                .accessibilityAction(named: "Focus This Split View Card") {
                    if !isGap { onFocus(member.id) }
                }
        case .placeholder:
            surface
                // The drag that summoned it owns every event, so the tile
                // neither hit-tests nor announces itself twice.
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Add to Split View")
        case .panel:
            surface
        }
    }

    /// The page surface every tile wears, member or not. A drop placeholder
    /// that borrowed a border of its own would read as a different kind of thing
    /// from the card about to replace it; this is that card's surface, already
    /// drawn.
    private func slotSurface(_ slot: BrowserSplitColumnSlot<Member>) -> some View {
        let isGap = slot.member.map { $0.id == lift?.tabID } ?? false
        return BrowserRootContentSurface(
            // Every card shares the radius of the cards in the window's
            // corners, so the tiles read as one set of pages.
            cornerRadius: borderless ? 0 : appearance.framedPageCornerRadius,
            seamWidth: borderless ? 0 : appearance.seamWidth,
            frameInsets: EdgeInsets(),
            usesTransparentInnerSurface: isGap
                // An empty tile is not a page that draws its own atmosphere,
                // whether it is empty because nothing has arrived yet or because
                // its card is out on the pointer.
                ? false
                : slot.member.map(usesTransparentInnerSurface) ?? false,
            showsBoundary: !borderless
        ) {
            switch slot {
            case .member(let member):
                // Transparent rather than removed, and deliberately not
                // `hidden()`. The card has to keep its host — a remount would
                // hand a live `WKWebView` to a second superview — and a web view
                // AppKit considers hidden reports itself hidden to the page as
                // well, which would pause its media and fire a visibility change
                // every time somebody rearranged a tile.
                content(member, member.id == focusedTabID)
                    .opacity(isGap ? 0 : 1)
            case .placeholder:
                BrowserSplitPlaceholderCard()
            case .panel:
                panelContent
            }
        }
    }

    private func dividerHandle(_ divider: BrowserSplitTileLayout.Divider, frame: CGRect) -> some View {
        let pair = divider.leadingSize + divider.trailingSize
        let leadingPercent = pair > 0 ? Int((divider.leadingSize / pair * 100).rounded()) : 50
        return BrowserSplitCardResizeHandle(
            dividerIndex: divider.index,
            axis: divider.axis,
            resize: { delta in
                resize(divider, delta: delta)
            },
            commit: {
                guard let committed = layoutTransaction.commit() else { return }
                onResizeCommit(committed.branchID, committed.fractions)
            },
            accessibilityTitle: divider.axis.isHorizontal
                ? "Resize Split View Columns" : "Resize Split View Rows",
            accessibilityMeasurement: String(
                localized: "\(leadingPercent) percent and \(100 - leadingPercent) percent")
        )
        .frame(width: frame.width, height: frame.height)
        .offset(x: frame.minX, y: frame.minY)
    }

    /// Moves one boundary to where the pointer has taken it, this frame.
    ///
    /// Explicitly unanimated. The tiles carry a settle animation for slots
    /// arriving and leaving, and while that animation is keyed on the tile
    /// rather than on frames, an inherited transaction from anywhere above
    /// would interpolate the boundary toward a pointer that has already moved
    /// on. A drag has to land on the geometry it was measured against.
    private func resize(_ divider: BrowserSplitTileLayout.Divider, delta: CGFloat) {
        guard let count = displayTile.branches.first(where: { $0.id == divider.branchID })?.count else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            layoutTransaction.resize(
                branchID: divider.branchID, childCount: count, axis: divider.axis, dividerIndex: divider.index,
                delta: delta, extent: divider.extent, gap: interCardGap,
                pairMinimums: (divider.leadingMinimum, divider.trailingMinimum))
        }
    }

    private func panelDivider(frame: CGRect, panelWidth: CGFloat) -> some View {
        BrowserSplitCardResizeHandle(
            dividerIndex: members.count - 1,
            axis: .horizontal,
            resize: resizePanel,
            commit: commitPanelResize,
            accessibilityTitle: "Resize Extension Side Panel",
            accessibilityMeasurement: "\(Int(panelWidth)) points",
            accessibilityDirection: -1
        )
        .frame(width: frame.width, height: frame.height)
        .offset(x: frame.minX, y: frame.minY)
    }

    private func resizePanel(delta: CGFloat) {
        guard let panel else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            panelWidthTransaction.resize(startingAt: panel.requestedWidth, delta: delta)
        }
    }

    private func commitPanelResize() {
        guard let width = panelWidthTransaction.commit() else { return }
        onPanelResizeCommit(width)
    }

    /// Whether the gaps carry dividers.
    ///
    /// A gesture in flight has none. The pointer already belongs to that gesture
    /// — a drag from the sidebar, or a card being carried between its neighbours
    /// — and a handle offered under a pointer that is busy is a resize nobody can
    /// start. The drop placeholder has moved every boundary as well.
    private var showsDividers: Bool {
        placeholder == nil && lift == nil && members.count > 1 || placeholder == nil && lift == nil && panel != nil
    }

    private var slots: [BrowserSplitColumnSlot<Member>] {
        BrowserSplitColumnSlot.slots(
            members: members,
            includesPlaceholder: displayTile.holdsPlaceholder,
            includesPanel: panel != nil
        )
    }

    /// The tile as it is drawn: the session's layout over the members, with a
    /// carried card moved to the landing it has reached, and the drop
    /// placeholder opened where a drag would land.
    ///
    /// The carried card stays in the tile, at its own identity, which is what
    /// keeps its host — and the live `WKWebView` inside it — alive through a
    /// whole move. Once the release settles, the session's own layout is the
    /// shape already on screen.
    private var displayTile: BrowserSplitTile {
        var tile = BrowserSplitTile.resolved(layout: layout, groupID: groupID, members: members.map(\.id))
        if let lift, tile.holds(lift.tabID) {
            if case .swapping(let lifted, let other) = lift.landing {
                tile = tile.swapping(lifted, other)
            } else if let without = tile.removing(lift.tabID) {
                tile = without.inserting(.card(lift.tabID), at: lift.landing)
            }
        }
        if let placeholder {
            if case .swapping(let lifted, let other) = placeholder {
                tile = tile.swapping(lifted, other)
            } else if let mover = placeholderMover, tile.holds(mover), let without = tile.removing(mover) {
                tile = without.inserting(.placeholder, at: placeholder)
            } else {
                tile = tile.inserting(.placeholder, at: placeholder)
            }
        }
        return tile
    }

    private func frame(
        of slot: BrowserSplitColumnSlot<Member>, in frames: BrowserSplitTileLayout.Frames, panelWidth: CGFloat,
        containerSize: CGSize, memberWidth: CGFloat
    ) -> CGRect {
        switch slot {
        case .member(let member): frames.cards[member.id] ?? .zero
        case .placeholder: frames.placeholder ?? .zero
        case .panel: CGRect(x: memberWidth + interCardGap, y: 0, width: panelWidth, height: containerSize.height)
        }
    }

    /// Frames are laid out in reading order from the leading edge; a mirrored
    /// layout draws the first member at the trailing edge.
    private func mirrored(_ frame: CGRect, in containerWidth: CGFloat) -> CGRect {
        guard layoutDirection == .rightToLeft else { return frame }
        return CGRect(x: containerWidth - frame.maxX, y: frame.minY, width: frame.width, height: frame.height)
    }

    private func memberContainerWidth(containerWidth: CGFloat) -> CGFloat {
        guard panel != nil else { return containerWidth }
        return BrowserSplitPanelLayout.memberContainerWidth(
            containerWidth: containerWidth,
            panelWidth: resolvedPanelWidth(containerWidth: containerWidth),
            gap: interCardGap
        )
    }

    private func resolvedPanelWidth(containerWidth: CGFloat) -> CGFloat {
        guard panel != nil else { return 0 }
        return BrowserSplitPanelLayout.resolvedWidth(
            requestedWidth: panelWidthTransaction.width ?? panel?.requestedWidth
                ?? BrowserSplitPanelLayoutMetrics.defaultWidth,
            containerWidth: containerWidth,
            memberCount: members.count + (placeholder == nil ? 0 : 1),
            gap: interCardGap
        )
    }

    private func cardZIndex(for slot: BrowserSplitColumnSlot<Member>) -> Double {
        guard case .member(let member) = slot,
            member.id == focusedTabID
        else { return BrowserSplitLayoutMetrics.restingCardZIndex }
        return BrowserSplitLayoutMetrics.focusedCardZIndex
    }
}

extension BrowserSplitTilesView where Panel == EmptyView {
    init(
        members: [Member], layout: SplitLayoutNode?, groupID: UUID?, focusedTabID: UUID?, frameInsets: EdgeInsets,
        accent: Color, placeholder: BrowserSplitDropLanding?, placeholderMover: UUID? = nil,
        lift: (tabID: UUID, landing: BrowserSplitDropLanding)?,
        layoutTransaction: Binding<BrowserSplitLayoutTransaction>,
        onResizeCommit: @escaping (UUID, [Double]) -> Void,
        onFocus: @escaping (UUID) -> Void,
        usesTransparentInnerSurface: @escaping (Member) -> Bool,
        @ViewBuilder content: @escaping (Member, Bool) -> Content
    ) {
        self.init(
            members: members, layout: layout, groupID: groupID, focusedTabID: focusedTabID, frameInsets: frameInsets,
            accent: accent, placeholder: placeholder, placeholderMover: placeholderMover, lift: lift,
            layoutTransaction: layoutTransaction, onResizeCommit: onResizeCommit,
            onFocus: onFocus, usesTransparentInnerSurface: usesTransparentInnerSurface,
            content: content, panel: nil, onPanelResizeCommit: { _ in },
            panelContent: { EmptyView() }
        )
    }
}

// Default preserves the mobile and embedded split presentation.
extension EnvironmentValues {
    @Entry var browserSplitUsesBorderlessFrame = false
    /// The space between cards: wider where a display's fold runs between
    /// them, so neither page reaches into the crease.
    @Entry var browserSplitInterCardGap = BrowserSplitLayoutMetrics.interCardGap
}
