import SwiftUI

/// What a shell offers for a Space's look as a shareable file: writing it out
/// and loading one in, each answering what went wrong or nil. A shell with
/// no file panels, such as a phone, offers none and the Forge shows nothing.
struct BrowserSpaceThemeFileActions {
    // MARK: - Variables

    let export: @MainActor () async -> String?
    let load: @MainActor () async -> String?
}

extension EnvironmentValues {
    @Entry var browserSpaceThemeFiles: BrowserSpaceThemeFileActions? = nil
}
