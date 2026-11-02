import SwiftUI

/// The look the Spaces setup makes wear: Crest's own banners and crests, a
/// modern gradient and icon, or one of the themes Arma ships with, each shown
/// as a small window. Choosing one restyles the stage and every preview from
/// here on.
struct BrowserOnboardingLookPage: View {
    let look: SetupLook
    let theme: BrowserBundledTheme?
    let choose: (SetupLook) -> Void
    let chooseTheme: (BrowserBundledTheme) -> Void
    let back: BrowserOnboardingBackAction
    let continueSetup: () -> Void

    @State private var library = BrowserThemeLibrary.shared

    /// The size each window takes in a grid of three across and two down,
    /// with room under each for its name and a line on who it suits.
    private func cardSize(in stage: CGSize) -> CGSize {
        let spacing = BrowserOnboardingLookMetrics.spacing
        let width = min((stage.width - spacing * 2) / 3, BrowserOnboardingLookMetrics.maximumWidth)
        let ratio = BrowserOnboardingLookMetrics.windowSize.height / BrowserOnboardingLookMetrics.windowSize.width
        let height = min(
            width * ratio,
            (stage.height - BrowserOnboardingLookMetrics.rowSpacing) / 2 - BrowserOnboardingLookMetrics.captionHeight)
        return CGSize(width: min(width, height / ratio), height: height)
    }

    var body: some View {
        VStack(spacing: 0) {
            BrowserOnboardingHeadline("Pick your look")
                .padding(.top, 22)
            GeometryReader { geometry in
                let size = cardSize(in: geometry.size)
                let columns = Array(
                    repeating: GridItem(.fixed(size.width), spacing: BrowserOnboardingLookMetrics.spacing), count: 3)
                LazyVGrid(columns: columns, spacing: BrowserOnboardingLookMetrics.rowSpacing) {
                    ForEach(SetupLook.all, id: \.self) { offered in
                        BrowserOnboardingLookCard(
                            title: Text(offered.title), caption: Text(offered.caption),
                            branding: offered.previewBranding, symbol: offered.previewSymbol, backdrop: nil,
                            isSelected: theme == nil && offered == look, size: size,
                            identifier: "onboarding-look-\(offered.name)"
                        ) {
                            choose(offered)
                        }
                    }
                    ForEach(BrowserBundledTheme.all) { bundled in
                        BrowserOnboardingLookCard(
                            title: Text(verbatim: bundled.name), caption: Text(bundled.pitch),
                            branding: branding(of: bundled), symbol: SetupLook.heraldic.previewSymbol,
                            backdrop: bundled.theme?.backgroundImage == nil
                                ? nil : (bundled.id, library.previewBackdrops),
                            isSelected: theme?.id == bundled.id, size: size,
                            identifier: "onboarding-theme-\(bundled.resource)"
                        ) {
                            chooseTheme(bundled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, BrowserOnboardingStageMetrics.pageInset)
            .padding(.vertical, 16)
            BrowserOnboardingFooter(back: back) {
                BrowserOnboardingContinueButton(action: continueSetup)
                    .accessibilityIdentifier("onboarding-look-continue")
            }
        }
        .onAppear {
            for bundled in BrowserBundledTheme.all { library.preparePreview(bundled.id) }
        }
    }

    /// The heraldic look dressed in `bundled`'s light look.
    private func branding(of bundled: BrowserBundledTheme) -> SpaceBranding {
        let base = SetupLook.heraldic.previewBranding
        guard let theme = bundled.theme else { return base }
        return (try? base.dressed(in: theme)) ?? base
    }
}

/// One choice as a small window, named underneath with a line on who it suits.
private struct BrowserOnboardingLookCard: View {
    let title: Text
    let caption: Text
    let branding: SpaceBranding
    let symbol: String
    let backdrop: (ownerID: UUID, store: BrowserSpaceBackdropStore)?
    let isSelected: Bool
    let size: CGSize
    let identifier: String
    let select: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: select) {
                BrowserOnboardingWindowPreview(
                    branding: branding, symbol: symbol, name: String(localized: "Personal"), backdrop: backdrop
                ) {
                    EmptyView()
                }
                // Laid out as a real window, then scaled to the card, so the
                // sidebar keeps its own measures at every card size.
                .frame(
                    width: BrowserOnboardingLookMetrics.windowSize.width,
                    height: BrowserOnboardingLookMetrics.windowSize.height
                )
                .scaleEffect(size.width / BrowserOnboardingLookMetrics.windowSize.width)
                .frame(width: size.width, height: size.height)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: BrowserOnboardingWindowPreviewMetrics.cornerRadius, style: .continuous
                    )
                    .strokeBorder(isSelected ? CrestBrandPalette.butter : .clear, lineWidth: 4)
                }
                .contentShape(
                    .rect(cornerRadius: BrowserOnboardingWindowPreviewMetrics.cornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier(identifier)
            title
                .font(CrestTypography.display(20))
                .foregroundStyle(CrestBrandTheme.textDisplay)
            caption
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

extension SetupLook {
    /// One line on who the look suits, under it in setup.
    fileprivate var caption: LocalizedStringResource {
        self == .modern ? "A gradient and a simple icon, quiet and clean" : "Banners and a crest of your own"
    }
}

#if DEBUG
    #Preview("Look") {
        BrowserOnboardingStage(step: .look, branding: SetupLook.heraldic.previewBranding) {
            BrowserOnboardingLookPage(
                look: .heraldic, theme: nil, choose: { _ in }, chooseTheme: { _ in },
                back: BrowserOnboardingBackAction(closes: false, action: {}), continueSetup: {})
        }
        .frame(width: 1440, height: 900)
    }
#endif

enum BrowserOnboardingLookMetrics {
    static let spacing: CGFloat = 36
    static let rowSpacing: CGFloat = 20
    static let maximumWidth: CGFloat = 420
    /// The name and line under each window.
    static let captionHeight: CGFloat = 64
    /// The window each card lays out before scaling it down.
    static let windowSize = CGSize(width: 760, height: 470)
}
