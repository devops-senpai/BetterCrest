import SwiftUI

/// What a shell offers for a Space's look as a shareable file: writing it out
/// and loading one in, each answering what went wrong or nil. A shell with
/// no file panels, such as a phone, offers none and the Forge shows nothing.
struct BrowserSpaceThemeFileActions {
    // MARK: - Variables

    let export: @MainActor () async -> String?
    let load: @MainActor () async -> String?
}

/// What a shell adds to the Forge's Sidebar step, such as the picture behind
/// the sidebar and the backing under its tabs. A shell with nothing to add
/// offers none.
struct BrowserSpaceSidebarSections {
    // MARK: - Variables

    let content: @MainActor () -> AnyView
}

/// What a Forge's stage shows in place of the crest, drawn from the look
/// being edited, as Settings › Themes shows a small browser in its colors.
struct BrowserCrestForgeStageHero {
    // MARK: - Variables

    let content: @MainActor (SpaceBranding) -> AnyView
}

extension EnvironmentValues {
    @Entry var browserCrestForgeStageHero: BrowserCrestForgeStageHero? = nil
    @Entry var browserSpaceThemeFiles: BrowserSpaceThemeFileActions? = nil
    @Entry var browserSpaceSidebarSections: BrowserSpaceSidebarSections? = nil
}
