import SwiftUI

/// The macOS content area when it is presenting more than one card.
///
/// This is the split half of `BrowserRootPageSurface`'s branch: it composes the
/// shared columns layout with macOS cards and re-establishes, at row level, the
/// two things the single-surface path attaches to its one surface — the
/// utility-fan dismissal on web-content interaction, and the per-card decision
/// about a transparent interior that the start page depends on.
///
/// It also owns everything the pointer does to the row, because both of those
/// things are properties of the row rather than of any one card:
///
/// - **Focus.** One `BrowserSplitCardPointerMonitor` for the window. Cards
///   register their bounds in `cardFrames`, the monitor turns a mouse-down into
///   one of them, and the event continues to the page untouched. The hover path
///   is gated by the Follow Mouse preference and evaluated only when a pointer
///   actually arrives. Both funnel through `focusSplitCard`, which is an ordinary
///   selection change and no-ops on the card that already has focus, so the two
///   inputs can never fight.
/// - **The carry.** A ⇧⌘-held press picks a card up: the same monitor keeps the
///   events, the row draws that member's column as the gap wherever the pointer
///   has taken it, and the release commits the slot the gap is standing in.
///   Nothing is mutated until then — a carry that is cancelled leaves no trace
///   in the session at all.
struct BrowserSplitPageSurface: View {
    let model: BrowserRootModel
    let space: SpaceModel
    /// The presented cards in session order. What the tiles *draw* is these
    /// with any carried card moved to the gap.
    let members: [TabStateModel]
    /// Where a drag in flight would land a card, or `nil` when no drop is
    /// resolved. `BrowserRootPageSurface` owns the decision; the tiles only
    /// draw it.
    let placeholder: BrowserSplitDropLanding?
    /// The card of the split a drag out of the sidebar is, if it is one.
    let placeholderMover: UUID?
    let tabPromotionNamespace: Namespace.ID
    /// The chords the window's commands show in a Start Page card's palette.
    let shortcuts: BrowserShortcutStore?

    /// The core's app preference; an unbound preview store keeps click-to-focus.
    private var appPreferences: BrowserAppPreferenceStore { .shared }
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.browserMacWindows) private var windows
    @State private var cardFrames = BrowserSplitCardFrameRegistry()
    /// Where the card-frame space begins in the window, so a pointer measured in
    /// one can be drawn in the other.
    @State private var surfaceOrigin = CGPoint.zero
    @State private var panelFrame: CGRect?

    private var isSelectedSpace: Bool {
        model.browser.selectedSpaceID == space.id && !model.spaceAccess.isLocked(space)
    }

    private var layoutTransaction: Binding<BrowserSplitLayoutTransaction> {
        guard !isSelectedSpace else { return model.splitWidthTransactionBinding }
        let persisted = model.browser.shownSplitGroupID(in: space)
            .map { model.windowState?.splitColumnFractions(for: $0) ?? [:] }
        return .constant(BrowserSplitLayoutTransaction(persistedFractions: persisted ?? [:]))
    }

    /// The card on the pointer and where the gap it left is standing, while
    /// this Space is the one being carried in.
    private var lift: (tabID: UUID, landing: BrowserSplitDropLanding)? {
        guard isSelectedSpace, let lift = model.splitCardLift.lift, !lift.isSettling else { return nil }
        return (lift.tabID, lift.landing)
    }

    var body: some View {
        BrowserSplitTilesView(
            members: members,
            layout: model.browser.shownSplitLayout(in: space),
            groupID: model.browser.shownSplitGroupID(in: space),
            focusedTabID: isSelectedSpace ? model.pages.activeTabID : model.browser.selectedTabID(in: space.id),
            frameInsets: BrowserChromeAppearance.device(windowCornerRadius: nil).pageInsets(
                docked: model.sidebarPresentation.reservesSidebarWidth, direction: layoutDirection
            ),
            accent: space.settings.shownLook.primaryColor.color,
            placeholder: placeholder,
            placeholderMover: placeholderMover,
            lift: lift,
            layoutTransaction: layoutTransaction,
            onResizeCommit: { branchID, fractions in
                if isSelectedSpace { model.commitSplitColumnFractions(fractions, branchID: branchID) }
            },
            onFocus: { if isSelectedSpace { model.focusSplitCard($0) } },
            usesTransparentInnerSurface: usesTransparentInnerSurface,
            content: { member, _ in
                BrowserSplitCardView(
                    tab: member,
                    space: space,
                    browser: model.browser,
                    pages: model.pages,
                    spaceAccess: model.spaceAccess,
                    tabPromotionNamespace: tabPromotionNamespace,
                    startPageFocusRequest:
                        model.chrome.startPageFocusRequest,
                    isCommandPalettePresented:
                        model.chrome.isCommandPalettePresented,
                    commands: model.paletteRegistry(
                        windows: windows, layoutDirection: layoutDirection, shortcuts: shortcuts),
                    cardFrames: cardFrames,
                    focusesOnHover: { focusesOnHover(member.id) },
                    onFocusRequest: { if isSelectedSpace { model.focusSplitCard(member.id) } }
                )
            },
            panel: isSelectedSpace && model.extensionSidePanel.panel != nil
                ? .init(requestedWidth: model.extensionSidePanel.width) : nil,
            onPanelResizeCommit: { model.extensionSidePanel.commitWidth($0) },
            panelContent: {
                if isSelectedSpace, let panel = model.extensionSidePanel.panel {
                    BrowserExtensionSidePanelCard(host: model.extensionSidePanel, panel: panel)
                        // The carry gesture must be able to tell the panel
                        // divider from a card divider.
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: BrowserSplitCardFrameRegistry.coordinateSpace)
                        } action: {
                            panelFrame = $0
                        }
                        .onDisappear { panelFrame = nil }
                }
            }
        )
        .environment(\.browserSplitUsesBorderlessFrame, BrowserDeviceAppearanceStore.shared.isBorderless)
        .background {
            if isSelectedSpace {
                BrowserSplitCardPointerMonitor(
                    cardFrames: cardFrames,
                    handleMouseDown: handleMouseDown,
                    lift: liftGesture,
                    carryRequest: model.sidebarInteraction.cardCarryRequest,
                    claimCarryRequest: model.sidebarInteraction.claimCardCarry
                )
            }
        }
        // Declared here, on the same view the monitor spans, so a registered card
        // frame and a converted event location share an origin by construction.
        .coordinateSpace(BrowserSplitCardFrameRegistry.coordinateSpace)
        .onGeometryChange(for: CGPoint.self) { proxy in
            proxy.frame(in: .global).origin
        } action: { origin in
            surfaceOrigin = origin
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                model.chrome.handleWebContentInteraction()
            }
        )
        .onChange(of: members.map(\.id), initial: true) { _, identifiers in
            guard isSelectedSpace else { return }
            model.seedSplitColumnFractions()
            // A card that left the row — a sync, another window, a closed tab —
            // is a card with nothing to drop onto and no slot to be put back in.
            if let carried = model.splitCardLift.lift?.tabID,
                !identifiers.contains(carried)
            {
                model.splitCardLift.abandon()
            }
        }
        .onChange(of: isSelectedSpace) { _, selected in
            if selected { model.seedSplitColumnFractions() }
        }
    }

    private var liftGesture: BrowserSplitCardLiftGesture {
        BrowserSplitCardLiftGesture(
            begin: beginLift,
            place: placeLift,
            update: updateLift,
            drop: dropLift,
            cancel: { model.splitCardLift.cancel() },
            isCarrying: { model.splitCardLift.isCarrying },
            isPlaced: { model.splitCardLift.isPlaced }
        )
    }

    /// A menu's "Move Card": the same pickup a ⇧⌘-held press makes, of the
    /// card the menu named, from wherever the pointer is, with nothing held.
    /// The card then rides the pointer until a click puts it down.
    private func placeLift(_ tabID: UUID, at point: CGPoint) -> Bool {
        guard isSelectedSpace, members.count > 1, !model.splitCardLift.isCarrying,
            let index = members.firstIndex(where: { $0.id == tabID }),
            let frame = memberCardFrames[tabID], !frame.isEmpty,
            let origin = model.browser.shownSplitTile(in: space).restoringLanding(for: tabID)
        else { return false }
        let token = model.splitCardLift.reserve()
        loadSnapshot(for: members[index], token: token)
        guard
            model.splitCardLift.begin(
                token: token, tabID: tabID, origin: origin, cardFrame: frame, aimFrames: memberCardFrames,
                pointer: frame.contains(point) ? point : CGPoint(x: frame.midX, y: frame.midY),
                surfaceOrigin: surfaceOrigin, placed: true)
        else {
            model.splitCardLift.discard(token)
            return false
        }
        model.focusSplitCard(tabID)
        updateLift(to: point)
        DiagnosticLog.splits.notice(
            "Menu picks up card \(tabID.uuidString.prefix(8)) at \(Int(point.x)),\(Int(point.y))")
        return true
    }

    /// The frames of the cards actually on show, by tab.
    ///
    /// The registry is keyed by tab and outlives the cards in it — a member the
    /// row is animating out keeps its frame until SwiftUI runs its disappearance
    /// — so every geometric question the carry asks is asked of the members
    /// rather than of the registry alone.
    private var memberCardFrames: [UUID: CGRect] {
        let frames = cardFrames.frames
        return members.reduce(into: [:]) { result, member in
            result[member.id] = frames[member.id]
        }
    }

    /// A ⇧⌘-held press: picks the card up, or declines and lets the press be an
    /// ordinary click.
    ///
    /// The order is the whole of it, and it is deliberate:
    ///
    /// 1. **Resolve the card** against the tiles' membership, so the answer is
    ///    a landing as well as a tab and there is no second way to fail.
    /// 2. **Stage the carry**, which mints its identity and changes nothing.
    /// 3. **Ask WebKit for the picture**, issued here inside the mouse-down —
    ///    before the row has been told anything at all.
    /// 4. **Begin the carry**, which is the first thing that changes on screen.
    /// 5. **Focus the card**, last, because focus is a *consequence* of picking a
    ///    card up and never a condition of it. Moving it ahead of the lift makes
    ///    the pickup depend on a selection change that no-ops on the card that
    ///    already has focus, which is precisely the coupling that made the
    ///    focused card behave differently from its neighbours.
    private func beginLift(
        at point: CGPoint,
        modifiers: BrowserKeyboardModifierFlags
    ) -> Bool {
        guard isSelectedSpace else { return false }
        let frames = memberCardFrames
        let card = BrowserSplitCardLift.card(
            at: point,
            members: members,
            cardFrames: frames
        )
        guard
            BrowserSplitCardLift.picksUp(
                modifiers: modifiers,
                isInsideCard: card != nil,
                isOverDivider: BrowserSplitCardLift.isOverDivider(
                    point, members: members, cardFrames: frames, panelFrame: panelFrame),
                memberCount: members.count,
                isDraggingSidebarItem:
                    model.sidebarInteraction.sidebarReorderState.isDragging,
                isCommandPalettePresented: model.chrome.isCommandPalettePresented
            ),
            let card,
            let origin = model.browser.shownSplitTile(in: space).restoringLanding(for: card.tabID)
        else { return false }

        let token = model.splitCardLift.reserve()
        loadSnapshot(for: members[card.index], token: token)
        guard
            model.splitCardLift.begin(
                token: token,
                tabID: card.tabID,
                origin: origin,
                cardFrame: card.frame,
                aimFrames: frames,
                pointer: point,
                surfaceOrigin: surfaceOrigin
            )
        else {
            model.splitCardLift.discard(token)
            return false
        }
        // Picking a card up is a decision about that card, so it becomes the
        // focused one — the same thing an ordinary click on it would have done,
        // and what makes "you are holding this" true of the chrome as well. It
        // is a consequence of the carry, which is why it happens after it.
        model.focusSplitCard(card.tabID)
        return true
    }

    private func updateLift(to point: CGPoint) {
        guard let carried = model.splitCardLift.carriedTabID, let lift = model.splitCardLift.lift else { return }
        model.splitCardLift.update(
            pointer: point,
            landing: BrowserSplitCardLift.landing(
                at: point, cardFrames: lift.aimFrames, lifted: carried, origin: lift.origin,
                rightToLeft: layoutDirection == .rightToLeft),
            surfaceOrigin: surfaceOrigin
        )
    }

    /// The release. The domain lands the card as the tiles already draw it,
    /// or refuses a move that changes nothing.
    private func dropLift() {
        guard let move = model.splitCardLift.drop() else { return }
        DiagnosticLog.splits.notice("Carry of \(move.tabID.uuidString.prefix(8)) drops at \(move.landing)")
        model.browser.tileSplitMember(
            move.tabID,
            at: move.landing,
            matching: BrowserSpaceRuntimeAssignment(space: space)
        )
    }

    /// Asks WebKit for the page as it is drawn right now, and hands it to the
    /// carry when it arrives.
    ///
    /// Issued inside the mouse-down and never awaited: the request is in flight
    /// before the row has been told a card is leaving it, and the card is on the
    /// pointer showing its title and favicon by the time WebKit answers. Putting
    /// a `Task` between the press and the request would spend a main-actor hop
    /// first — the same hop SwiftUI redraws the row in — for no gain the carry
    /// can use.
    ///
    /// The answer is matched against the carry's own token, so a picture asked
    /// for by an earlier pickup of the same card cannot arrive on this one.
    ///
    /// Asked only of a card that is *showing* a live page, which is not the same
    /// question as whether a page exists for it. Selecting a split builds a
    /// `BrowserPage` — and therefore a `WKWebView` — for every member, start
    /// pages included, and a start-page card never loads or even mounts the one
    /// it was given: it draws `BrowserStartPageContent` instead. Snapshotting a
    /// card by page alone therefore pictures a web view that has never rendered
    /// anything, and an empty picture is worse than none — a snapshot that
    /// arrives stands the placeholder down, so the carry shows neither the page
    /// nor the tab it belongs to. The card's own presentation is the authority
    /// on what it is drawing, and it is resolved here by the same policy the card
    /// resolves it with, so the picture and the card cannot disagree.
    private func loadSnapshot(for member: TabStateModel, token: BrowserSplitCardLiftToken) {
        let page = model.pages.presentedPage(
            matching: BrowserTabRuntimeAssignment(tabID: member.id, spaceID: space.id, profileID: space.profileID))
        guard PagePresentation.of(member.surface, page: page).picturesLivePage, let page else { return }
        let lift = model.splitCardLift
        BrowserSplitCardSnapshotLoader.snapshot(of: page) { snapshot in
            guard let snapshot else { return }
            lift.attach(snapshot: snapshot, token: token)
        }
    }

    private func focusesOnHover(_ tabID: UUID) -> Bool {
        isSelectedSpace
            && Self.focusesOnHover(
                followsMouse: appPreferences.splitFocusFollowsMouse,
                isCardFocused: model.pages.activeTabID == tabID,
                isAddressEditing: model.isAddressEditing,
                isDraggingSidebarItem: model.sidebarInteraction.sidebarReorderState.isDragging,
                isCarryingCard: model.splitCardLift.isCarrying,
                isCommandPalettePresented: model.chrome.isCommandPalettePresented
            )
    }

    private func handleMouseDown(_ tabID: UUID) {
        guard
            isSelectedSpace,
            Self.focusesOnClick(
                isCardFocused: model.pages.activeTabID == tabID,
                isDraggingSidebarItem:
                    model.sidebarInteraction.sidebarReorderState.isDragging,
                isCarryingCard: model.splitCardLift.isCarrying,
                isCommandPalettePresented: model.chrome.isCommandPalettePresented
            )
        else { return }
        model.focusSplitCard(tabID)
    }

    /// The transparent-interior decision, made per card rather than once for
    /// the window: a start-page or not-yet-committed card shows the Space's
    /// atmosphere through it while loaded neighbours keep their page background.
    private func usesTransparentInnerSurface(_ member: TabStateModel) -> Bool {
        let page = model.pages.surfacePage(for: member.id, in: space, accessController: model.spaceAccess)
        return BrowserPageSurfacePresentation.usesTransparentInnerSurface(
            isStartPage: member.surface == .startPage,
            hasActivePage: page != nil,
            completedNavigationCount: page?.completedNavigationCount ?? 0
        )
    }
}
