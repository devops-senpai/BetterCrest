import Foundation

/// Whether `arma page` may read and act inside pages from the person's
/// terminal on this Mac. It starts off, since any program the person runs
/// can run the helper. It is this Mac's own choice and never syncs, so it
/// stays in this launch's defaults, an isolated launch's apart.
@MainActor
enum BrowserTerminalPagePreference {
    // MARK: - Static Variables

    static let key = "crest.terminal.pageControl"

    static let defaults: UserDefaults = {
        let environment = BrowserLaunchEnvironment.current
        guard environment.requiresIsolation else { return .standard }
        let id = environment.persistentIsolationID ?? "ephemeral-\(UUID().uuidString)"
        return UserDefaults(suiteName: BrowserLaunchEnvironment.isolatedDefaultsSuiteName(isolationID: id))!
    }()

    /// Whether the person turned page control on.
    static var isOn: Bool { defaults.bool(forKey: key) }
}
