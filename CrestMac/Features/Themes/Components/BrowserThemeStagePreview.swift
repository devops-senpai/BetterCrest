import SwiftUI

/// The Themes page's stage: a small Arma window in the theme being edited,
/// its picture, sidebar colors, folders and text included, with the command
/// palette open over its page in the theme's palette tint and text, drawn by
/// the same preview onboarding shows and scaled down, so every color picked
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
            BrowserThemePalettePreview(branding: branding)
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .scaleEffect(Self.scale)
        .frame(width: Self.windowSize.width * Self.scale, height: Self.windowSize.height * Self.scale)
        .allowsHitTesting(false)
    }
}

/// The command palette as a theme dresses it, open with a few results: the
/// palette's own material under the theme's tint, in its text color.
private struct BrowserThemePalettePreview: View {
    // MARK: - Variables

    let branding: SpaceBranding

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var surface: SpacePaletteSurface? {
        branding.commandPalette?.surface(dark: colorScheme == .dark)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }

    // MARK: - Actions - Presentation

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Search or Enter URL…", systemImage: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .frame(height: 48)
            Divider()
            VStack(spacing: 2) {
                row("Mail", symbol: "envelope.fill", selected: true)
                row("Docs", symbol: "doc.text.fill", selected: false)
                row("Music", symbol: "music.note", selected: false)
            }
            .padding(6)
        }
        .frame(width: 300)
        .modifier(SpaceTextColor(color: surface?.textColor))
        .environment(\.colorScheme, surface?.foregroundTone?.colorScheme ?? colorScheme)
        .modifier(
            BrowserCommandPaletteShellMaterial(shape: shape, reduceTransparency: reduceTransparency, surface: surface)
        )
        .clipShape(shape)
        .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
    }

    private func row(_ title: LocalizedStringKey, symbol: String, selected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).frame(width: 18)
            Text(title)
            Spacer(minLength: 0)
            if selected {
                Text("Switch to Tab").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(CrestColor.selection)
            }
        }
    }
}
