import Foundation

/// The extensions an engine runs in each Space's profile, as `arma extension`
/// manages them from the terminal. Only an engine that runs extensions per
/// Space supplies one; its store answers for the Spaces this Arma may change
/// and refuses the rest, as its own settings pane does.
@MainActor
protocol BrowserMacExtensionManaging: AnyObject {
    /// What `space`'s profile has installed, once the engine has prepared it,
    /// or nil when the Space is not one this Arma may read.
    func installedExtensions(in space: BrowserSpaceIdentity) async -> [InstalledExtension]?

    /// Makes `change` to `extensionID` in `space`'s profile; answers whether
    /// the engine accepted it.
    func change(_ change: ExtensionChange, extensionID: String, in space: BrowserSpaceIdentity) -> Bool

    /// Starts installing Web Store extension `webStoreID` into `space`
    /// through the review Arma shows in its active window, where the person
    /// confirms it. False when no review could start: another is open, the
    /// Space is not one this Arma may change, or no window is open.
    func reviewInstall(of webStoreID: String, in space: BrowserSpaceIdentity) -> Bool
}
