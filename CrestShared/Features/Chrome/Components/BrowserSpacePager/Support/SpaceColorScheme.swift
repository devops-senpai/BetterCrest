import SwiftUI

/// Draws content in the scheme a Space's sidebar reads in over the window,
/// and in the one text color the Space chose, when it chose one.
///
/// The scheme follows the device's dark dimming, which a person drags. Working
/// it out here, rather than in the view that wraps the sidebar, keeps a drag to
/// this modifier: the sidebar under it re-renders only when the scheme itself
/// changes.
struct SpaceColorScheme: ViewModifier {
    /// The look of the Space the content belongs to, or nil for none, which
    /// draws dark.
    let branding: SpaceBranding?

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .modifier(SpaceTextColor(color: branding?.sidebarTextColor))
            .environment(\.colorScheme, branding?.shown.colorScheme(over: colorScheme) ?? .dark)
    }
}
