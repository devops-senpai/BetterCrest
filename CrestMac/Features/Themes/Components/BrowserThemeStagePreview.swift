import SwiftUI

/// The Themes page's stage: a small Arma window in the theme being edited,
/// its picture, sidebar colors, folders and text included, drawn by the
/// same preview onboarding shows and scaled down, so every color picked
/// changes it.
struct BrowserThemeStagePreview: View {
    // MARK: - Static Variables

    /// The window the preview lays out, as a real one is, before scaling.
    private static let windowSize = CGSize(width: 640, height: 400)
    private static let scale: CGFloat = 0.46

    // MARK: - Variables

    let branding: SpaceBranding
    let symbol: String
    /// The theme whose picture `backdrops` keeps.
    let themeID: UUID
    let backdrops: BrowserSpaceBackdropStore

    // MARK: - Actions - Presentation

    var body: some View {
        BrowserOnboardingWindowPreview(
            branding: branding, symbol: symbol, name: String(localized: "Personal"),
            backdrop: (themeID, backdrops)
        ) {
            EmptyView()
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .scaleEffect(Self.scale)
        .frame(width: Self.windowSize.width * Self.scale, height: Self.windowSize.height * Self.scale)
        .allowsHitTesting(false)
    }
}
