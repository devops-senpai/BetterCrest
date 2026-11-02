/// Settings destinations whose implementations are available in the mobile shell.
enum BrowserPlatformSettingsDestinationCatalog {
    /// The destinations whose subject exists only on the Mac: the engine
    /// choice, rebindable keyboard commands, WebKit's private feature registry,
    /// the agents server, testing frameworks and the saved themes.
    static let macOnly: Set<BrowserSettingsDestination> = [
        .engines, .shortcuts, .featureFlags, .agents, .automation, .themes,
    ]

    static let cases = BrowserSettingsDestination.all.filter { !macOnly.contains($0) }
}
