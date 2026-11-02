import SwiftUI

/// The translucent layer a Space's sidebar lays under its rows so they read
/// over the Space's picture: its reach, the color it wears in the window's
/// appearance, how strongly it shows, and how frosted the picture is behind it.
struct BrowserSidebarTabBacking: Equatable {
    // MARK: - Variables

    let reach: BrowserSpaceBackdropStore.TabBackingReach
    let color: Color
    let opacity: Double
    let blur: Double

    // MARK: - Initializers

    /// The backing the Space `spaceID` wears, or nil while it has no picture
    /// or keeps its backing off.
    @MainActor
    init?(spaceID: UUID, branding: SpaceBranding, scheme: ColorScheme, store: BrowserSpaceBackdropStore) {
        guard let backdrop = store.backdrop(for: spaceID), backdrop.tabBacking.reach != .off else { return nil }
        let backing = backdrop.tabBacking
        reach = backing.reach
        color = backing.shownColor(over: branding, in: scheme).color
        opacity = backing.opacity
        blur = backing.blur
    }

    // MARK: - Actions - Drawing

    /// The layer in `shape`: the picture frosted behind it as far as its blur
    /// says, then its color.
    func layer(in shape: some Shape) -> some View {
        ZStack {
            if blur > 0 {
                shape.fill(blur > 0.5 ? Material.regular : Material.ultraThin)
                    .opacity(min(1, blur * 2))
            }
            shape.fill(color.opacity(opacity))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension EnvironmentValues {
    /// The backing the sidebar's rows lie on, nil for none.
    @Entry var browserSidebarTabBacking: BrowserSidebarTabBacking? = nil
}

/// The plate under one sidebar row, in the row's own rounded shape, while
/// the Space's backing lies behind each row.
struct BrowserSidebarTabBackingPlate: View {
    let cornerRadius: CGFloat

    @Environment(\.browserSidebarTabBacking) private var backing

    var body: some View {
        if let backing, backing.reach.platesRows {
            backing.layer(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

/// Gives a Space's sidebar page its tab backing: the panel over the whole
/// column, or the plates its rows draw.
struct BrowserSidebarTabBackingModifier: ViewModifier {
    let space: SpaceModel

    @State private var store = BrowserSpaceBackdropStore.shared
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let backing = BrowserSidebarTabBacking(
            spaceID: space.id, branding: space.settings.shownLook, scheme: colorScheme, store: store)
        content
            .background {
                if let backing, backing.reach.coversSidebar {
                    backing.layer(in: Rectangle())
                }
            }
            .environment(\.browserSidebarTabBacking, backing)
    }
}
