import Foundation

/// `arma extension` over Chromium's per-Space profiles: the same engine
/// requests and install review the Extensions settings pane uses.
extension ChromiumExtensionStore: BrowserMacExtensionManaging {
    // MARK: - Actions - Terminal

    func installedExtensions(in space: BrowserSpaceIdentity) async -> [InstalledExtension]? {
        guard authorized(space) else { return nil }
        await load(space)
        guard authorized(space), ChromiumComposition.engineHost != nil,
            let pages = ChromiumComposition.chromiumEngine?.pages
        else { return nil }
        return pages.request(InstalledExtensions(profileID: space.profileID)).extensions
    }

    func change(_ change: ExtensionChange, extensionID: String, in space: BrowserSpaceIdentity) -> Bool {
        guard authorized(space), let pages = ChromiumComposition.chromiumEngine?.pages else { return false }
        let accepted = pages.request(
            ChangeExtension(profileID: space.profileID, extensionID: extensionID, change: change))
        refresh()
        return accepted
    }

    func reviewInstall(of webStoreID: String, in space: BrowserSpaceIdentity) -> Bool {
        guard installation == nil, authorized(space), ChromiumComposition.activeNativeWindow != nil else {
            return false
        }
        install(webStoreID, in: space, anchor: nil)
        return installation != nil
    }
}
