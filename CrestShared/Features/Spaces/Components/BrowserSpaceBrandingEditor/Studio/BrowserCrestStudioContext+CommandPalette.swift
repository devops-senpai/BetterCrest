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
                    editSurface(dark: dark) { $0 = $0.tinted(tint) }
                }), default: nil)
    }

    /// The color the card's text reads in, in the appearance `dark` names, or
    /// nil for the system's.
    func paletteTextColor(dark: Bool) -> CrestSettingValue<BrandColor?> {
        CrestSettingValue(
            Binding(
                get: { value.commandPalette?.surface(dark: dark).textColor },
                set: { color in
                    editSurface(dark: dark) { $0.textColor = color }
                }), default: nil)
    }

    /// How far the tint covers the material in the appearance `dark` names.
    func paletteOpacity(dark: Bool) -> CrestSettingValue<Double> {
        CrestSettingValue(
            Binding(
                get: { value.commandPalette?.surface(dark: dark).opacity ?? 0 },
                set: { opacity in
                    editSurface(dark: dark) { $0.opacity = opacity }
                }), default: 0)
    }

    private func editSurface(dark: Bool, _ edit: @escaping (inout SpacePaletteSurface) -> Void) {
        branding.editorUpdate {
            $0.editPaletteSurface(dark: dark, edit)
            $0.hasCustomAppearance = true
        }
    }
}
