import SwiftUI

/// The palette card's surface: the system material, with the Space's tint
/// for this appearance laid over it as far as the Space asks.
struct BrowserCommandPaletteShellMaterial: ViewModifier {
    let shape: RoundedRectangle
    let reduceTransparency: Bool
    /// The Space's surface for the appearance the card shows in, or nil for
    /// the material alone.
    var surface: SpacePaletteSurface? = nil

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background { tint }.background(.background, in: shape)
        } else {
            content.background { tint }.glassEffect(.regular, in: shape)
        }
    }

    /// The tint between the material and the card's contents, so the
    /// material never washes it out. It keeps the card's shape so the glass
    /// keeps its own edge.
    @ViewBuilder
    private var tint: some View {
        if let surface, let color = surface.tint, surface.opacity > 0 {
            shape.fill(color.color.opacity(surface.opacity))
        }
    }
}
