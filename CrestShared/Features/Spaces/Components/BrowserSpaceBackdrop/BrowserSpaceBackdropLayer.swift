import SwiftUI

/// A Space's colors as the window wears them behind its sidebar, with the
/// Space's picture on them when it has one: the colors fill the window, the
/// picture lies on them at its own opacity, size and corner, and the colors
/// lie over it again as strongly as the Space says. Without a picture this
/// is the banner alone.
struct BrowserSpaceBackdropLayer: View {
    let spaceID: UUID?
    let branding: SpaceBranding
    /// Where the picture is kept: the Spaces' store, or a theme preview's.
    var store: BrowserSpaceBackdropStore = .shared

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        if let spaceID, let backdrop = store.backdrop(for: spaceID), let image = store.image(for: spaceID),
            let pixels = store.pixelSize(for: spaceID)
        {
            let natural = CGSize(width: pixels.width / displayScale, height: pixels.height / displayScale)
            ZStack {
                // The Space's colors fill the window wherever the picture
                // does not reach, as when it keeps its own size.
                BrowserSpaceBannerBackground(branding: branding)
                picture(image, natural: natural, backdrop)
                    .opacity(backdrop.imageOpacity)
                BrowserSpaceBannerBackground(branding: branding)
                    .opacity(backdrop.tintOpacity)
            }
            .accessibilityHidden(true)
        } else {
            BrowserSpaceBannerBackground(branding: branding)
        }
    }

    /// The picture at the size its backdrop says, held to its corner, drawn
    /// once or repeated across the window.
    private func picture(_ image: CGImage, natural: CGSize, _ backdrop: BrowserSpaceBackdropStore.Backdrop)
        -> some View
    {
        Canvas { context, size in
            let drawn = backdrop.drawnSize(of: natural, in: size)
            guard drawn.width >= 1, drawn.height >= 1 else { return }
            let resolved = context.resolve(Image(decorative: image, scale: 1))
            // The corner the picture holds to stays put; a bottom anchor
            // lays it, and its rows, upward from the window's bottom edge.
            let firstY = backdrop.anchor.isTop ? 0 : size.height - drawn.height
            guard backdrop.tiles else {
                context.draw(resolved, in: CGRect(origin: CGPoint(x: 0, y: firstY), size: drawn))
                return
            }
            let rows = Int((size.height / drawn.height).rounded(.up))
            let columns = Int((size.width / drawn.width).rounded(.up))
            for row in 0..<max(rows, 1) {
                let y = backdrop.anchor.isTop ? Double(row) * drawn.height : firstY - Double(row) * drawn.height
                for column in 0..<max(columns, 1) {
                    context.draw(
                        resolved, in: CGRect(origin: CGPoint(x: Double(column) * drawn.width, y: y), size: drawn))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
