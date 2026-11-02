import SwiftUI

/// A Space's Appearance page: the theme it wears, which Settings › Themes
/// edits, then the Crest Studio's Forge for the Space's own crest, which no
/// theme carries.
struct BrowserSpaceEditorView: View {
    // MARK: - Static Variables

    /// The steps that shape the Space's own crest and icon; colors, the
    /// sidebar and the background picture belong to its theme.
    private static let crestSteps: [BrowserCrestStudioStep] = [.shape, .field, .band, .emblem, .border, .finish]

    // MARK: - Variables

    @Environment(\.browserSettingsUsesLiveSidebar) private var usesLiveSidebar
    @Environment(\.browserSettingsTabState) private var tabState
    @State private var standaloneStep = BrowserCrestStudioStep.shape

    let browser: BrowserStore
    let space: SpaceModel

    // MARK: - Actions - Presentation

    var body: some View {
        VStack(spacing: 0) {
            BrowserSpaceThemePicker(browser: browser, space: space)
                // Lines up with the leading edge of the Forge's column below it.
                .padding(.horizontal, usesLiveSidebar ? 30 : 20)
                .frame(maxWidth: usesLiveSidebar ? BrowserCrestForgeMetrics.columnWidth : 680)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, usesLiveSidebar ? BrowserSettingsLayout.formMinimumInset : 0)
                .padding(.vertical, 8)
            BrowserCrestForge(branding: branding, symbol: symbol, step: forgeStep, offeredSteps: Self.crestSteps)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("space-customization-controls")
    }

    private var forgeStep: Binding<BrowserCrestStudioStep> {
        Binding(
            get: { tabState?.forgeStep ?? standaloneStep },
            set: { if let tabState { tabState.forgeStep = $0 } else { standaloneStep = $0 } })
    }

    private var symbol: Binding<String> {
        browser.spaceSymbolBinding(in: space)
    }

    /// The Space's look, whose crest the Forge edits. A Space with a dark look
    /// wears the same crest in it.
    private var branding: Binding<SpaceBranding> {
        let light = browser.spaceBrandingBinding(in: space)
        return Binding(
            get: { light.wrappedValue },
            set: { edited in
                light.wrappedValue = edited
                guard var dark = space.settings.darkBranding,
                    dark.crest != edited.crest || dark.iconStyle != edited.iconStyle
                else { return }
                dark.crest = edited.crest
                dark.iconStyle = edited.iconStyle
                browser.updateSpaceDarkBranding(dark.normalized(), in: space.id)
            })
    }
}
