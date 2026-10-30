import SwiftUI

/// The look a Space wears in the windows as they are now: its dark look while
/// the windows are dark and it has one, else its light look. Editors and
/// exports read `look` and `darkLook` themselves; everything that draws reads
/// this.
extension SpaceSettings {
    // MARK: - Variables

    @MainActor
    var shownLook: SpaceBranding {
        BrowserDeviceAppearanceStore.shared.shownColorScheme == .dark ? darkLook : look
    }
}

extension SpaceSettingsModel {
    // MARK: - Variables

    /// The look the windows show for this Space now, as `SpaceSettings.shownLook`.
    @MainActor
    var shownLook: SpaceBranding {
        BrowserDeviceAppearanceStore.shared.shownColorScheme == .dark ? darkLook : look
    }
}
