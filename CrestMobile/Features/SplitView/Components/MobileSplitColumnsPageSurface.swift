import SwiftUI

/// The iPadOS content area when it is laying its pages out as a row of cards.
///
/// Usually that means a group of more than one member. It also means a lone tab
/// with a drag in flight over it: the row is what a drop placeholder can open
/// beside, so `MobileRegularPageSurface` switches to it for the length of the
/// drag and this surface draws a one-card row without treating it as a special
/// case — the same thing `BrowserSplitColumnsView` does for macOS.
///
/// The regular half of `MobileRegularPageSurface`'s branch, and the iPad's use of
/// the very same `BrowserSplitColumnsView` macOS lays out — which is the point of
/// the container being shared. What the platform supplies is the card interior
/// and the two things the single detail surface attaches to its one surface: the
/// utility-fan dismissal on web-content interaction, and the per-card decision
/// about a transparent interior.
///
/// Every column is visible, so every column loads. `prepareSplitCardPages()` runs
/// on the membership change rather than per card, because there is no lazy
/// materialization here to hang it off.
struct MobileSplitColumnsPageSurface: View {
    @Environment(\.browserWindowCornerRadius) private var windowCornerRadius
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.mobileBrowserFold) private var fold
    @Environment(\.mobileBrowserControlPlacement) private var controlPlacement
    /// Where the row sits, for lining its pages up with a fold.
    @State private var globalFrame = CGRect.zero
    let model: MobileBrowserRootModel
    let space: SpaceModel
    let members: [TabStateModel]
    let adjoinsSidebar: Bool
    /// Where a drag out of the sidebar would land a card.
    /// `MobileRegularPageSurface` owns the decision; the tiles only draw it.
    let placeholder: BrowserSplitDropLanding?
    /// The card of the split a drag out of the sidebar is, if it is one.
    let placeholderMover: UUID?

    private var appearance: BrowserChromeAppearance { .device(windowCornerRadius: windowCornerRadius) }

    var body: some View {
        BrowserSplitTilesView(
            members: members,
            layout: model.browser.shownSplitLayout(in: space),
            groupID: model.browser.shownSplitGroupID(in: space),
            focusedTabID: model.browser.shownTab?.id,
            frameInsets: frameInsets,
            accent: space.settings.shownLook.primaryColor.color,
            placeholder: placeholder,
            placeholderMover: placeholderMover,
            // "Fancy Move" is a pointer gesture: ⇧⌘-held mouse-down, and a
            // card that follows a cursor. iPadOS reorders its cards from the
            // member menu instead, so the tiles here are never carrying one.
            lift: nil,
            layoutTransaction: layoutTransaction,
            // The fold's columns are never the person's, so none are kept.
            onResizeCommit: { branchID, fractions in
                if foldFractions == nil { model.commitSplitColumnFractions(fractions, branchID: branchID) }
            },
            onFocus: model.focusSplitCard,
            usesTransparentInnerSurface: usesTransparentInnerSurface,
            content: { member, _ in
                MobileSplitCardContent(
                    member: member,
                    space: space,
                    pages: model.pages,
                    viewport: .inline,
                    failureLayout: .regular,
                    handleInteraction: {
                        model.navigation.utilityPresentation
                            .handleInteraction(.webContent)
                        model.navigation.handleRegularPageInteraction()
                    },
                    requestFocus: { model.focusSplitCard(member.id) }
                )
                // Where this card sits, in the space a drag resolves in, so a
                // tab dropped on the row lands in the slot the finger is
                // actually over. The Space rides along because the registry
                // outlives the presentation that filled it.
                .browserSplitDropCardFrame(
                    tabID: member.id,
                    assignment: BrowserSpaceRuntimeAssignment(space: space),
                    state: model.sidebarInteraction.sidebarReorderState
                )
            }
        )
        .overlay {
            MobileHistorySwipeBorder(
                insets: frameInsets,
                leadingPage: members.first.flatMap(residentPage(of:)),
                trailingPage: members.last.flatMap(residentPage(of:))
            )
        }
        .environment(\.browserSplitUsesBorderlessFrame, appearance.borderless)
        .environment(\.browserSplitInterCardGap, interCardGap)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            globalFrame = frame
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                model.navigation.utilityPresentation.handleInteraction(.webContent)
                model.navigation.handleRegularPageInteraction()
            }
        )
        .onChange(of: members.map(\.id), initial: true) { _, _ in
            model.seedSplitColumnFractions()
            model.prepareSplitCardPages()
        }
    }

    private var layoutTransaction: Binding<BrowserSplitLayoutTransaction> {
        guard let foldFractions else { return model.splitWidthTransactionBinding }
        return .constant(BrowserSplitLayoutTransaction(persistedFractions: foldFractions))
    }

    private var frameInsets: EdgeInsets {
        controlPlacement.pageInsets(
            appearance.pageInsets(docked: adjoinsSidebar, direction: layoutDirection)
        )
    }

    /// Columns that meet in the fold while the display is folded, by the
    /// outer row's branch, or nil to keep the split's own. Only a split whose
    /// outer branch runs across has columns to line up with a fold; a stack
    /// of rows keeps its own shares.
    private var foldFractions: [UUID: [Double]]? {
        guard let fold,
            case .branch(let branchID, let axis, let children) = model.browser.shownSplitTile(in: space),
            axis.isHorizontal
        else { return nil }
        let insets = frameInsets
        let row = CGRect(
            x: globalFrame.minX + (layoutDirection == .rightToLeft ? insets.trailing : insets.leading),
            y: globalFrame.minY,
            width: globalFrame.width - insets.leading - insets.trailing,
            height: globalFrame.height
        )
        return fold.columnFractions(
            memberCount: children.count,
            across: row,
            direction: layoutDirection,
            gap: foldGap(fold)
        ).map { [branchID: $0] }
    }

    /// The space between cards: the whole fold while the pages meet in it,
    /// so neither reaches into the crease.
    private var interCardGap: CGFloat {
        guard let fold, foldFractions != nil else { return BrowserSplitLayoutMetrics.interCardGap }
        return foldGap(fold)
    }

    private func foldGap(_ fold: MobileBrowserFold) -> CGFloat {
        max(BrowserSplitLayoutMetrics.interCardGap, fold.frame.width)
    }

    private func residentPage(of member: TabStateModel) -> MobileBrowserPage? {
        model.pages.residentPage(
            matching: BrowserTabRuntimeAssignment(
                tabID: member.id,
                spaceID: space.id,
                profileID: space.profileID
            )
        )
    }

    /// The transparent-interior decision, made per card rather than once for the
    /// window: a start-page or not-yet-committed card shows the Space's atmosphere
    /// through it while loaded neighbours keep their page background.
    private func usesTransparentInnerSurface(_ member: TabStateModel) -> Bool {
        let page = residentPage(of: member)
        return BrowserPageSurfacePresentation.usesTransparentInnerSurface(
            isStartPage: member.surface == .startPage,
            hasActivePage: page != nil,
            completedNavigationCount: page?.completedNavigationCount ?? 0
        )
    }
}
