import SwiftUI

/// The command palette's surfaces as settings: one tint and one opacity for
/// each appearance. The default is the system material alone, whatever look
/// the Space opened with, so a tint is always something to reset.
extension BrowserCrestStudioContext {
    // MARK: - Actions - Command Palette

    /// The tint the palette card wears in the appearance `dark` names, or nil
    /// for the system material alone. Picking a tint over a surface that
    /// covered nothing covers the material the default way.
    func paletteTint(dark: Bool) -> CrestSettingValue<BrandColor?> {
        CrestSettingValue(
            Binding(
                get: { value.commandPalette?.surface(dark: dark).tint },
                set: { tint in
                    branding.editorUpdate {
                        let surface = ($0.commandPalette ?? .neutral).surface(dark: dark)
                        $0.setPaletteSurface(surface.tinted(tint), dark: dark)
                        $0.hasCustomAppearance = true
                    }
                }), default: nil)
    }

    /// The color the card's text reads in, in the appearance `dark` names, or
    /// nil for the system's.
    func paletteTextColor(dark: Bool) -> CrestSettingValue<BrandColor?> {
        CrestSettingValue(
            Binding(
                get: { value.commandPalette?.surface(dark: dark).textColor },
                set: { color in
                    branding.editorUpdate {
                        var surface = ($0.commandPalette ?? .neutral).surface(dark: dark)
                        surface.textColor = color
                        $0.setPaletteSurface(surface, dark: dark)
                        $0.hasCustomAppearance = true
                    }
                }), default: nil)
    }

    /// How far the tint covers the material in the appearance `dark` names.
    func paletteOpacity(dark: Bool) -> CrestSettingValue<Double> {
        CrestSettingValue(
            Binding(
                get: { value.commandPalette?.surface(dark: dark).opacity ?? 0 },
                set: { opacity in
                    branding.editorUpdate {
                        var surface = ($0.commandPalette ?? .neutral).surface(dark: dark)
                        surface.opacity = opacity
                        $0.setPaletteSurface(surface, dark: dark)
                        $0.hasCustomAppearance = true
                    }
                }), default: 0)
    }
}
