import SwiftUI

/// Draws content's text in `color` when a Space chose one, else as the
/// scheme has it. Secondary text, such as New Tab, draws in `secondary` when
/// the Space chose that, else it and tertiary text follow the color at their
/// usual strengths.
struct SpaceTextColor: ViewModifier {
    let color: BrandColor?
    var secondary: BrandColor? = nil

    @ViewBuilder
    func body(content: Content) -> some View {
        if let secondary {
            content.foregroundStyle(color?.color ?? Color.primary, secondary.color)
        } else if let color {
            content.foregroundStyle(color.color)
        } else {
            content
        }
    }
}
