import SwiftUI

/// Draws content's text in `color` when a Space chose one, else as the
/// scheme has it. Secondary and tertiary text follow the color at their usual
/// strengths.
struct SpaceTextColor: ViewModifier {
    let color: BrandColor?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let color {
            content.foregroundStyle(color.color)
        } else {
            content
        }
    }
}
