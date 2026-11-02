import AppKit
import Observation

/// Whether testing frameworks such as Playwright, Puppeteer and Selenium may
/// drive Arma's Chromium engine over its DevTools port, and what they reach:
/// one profile's tabs, or a throwaway profile, and of that profile only the
/// tabs they open or every tab. It starts off, since any program on this Mac
/// that reaches the port controls the browser.
///
/// It is this Mac's own choice and never syncs. The engine reads it once, as
/// it starts, from these defaults, so a change applies after Arma restarts;
/// `launched` is what this run started with.
@MainActor
@Observable
final class BrowserAutomationPreferences {
    // MARK: - Types

    /// The tabs a framework can see in the profile it drives.
    enum TabReach: String, CaseIterable, Identifiable, Sendable {
        /// Only tabs it opened since automation started, and their popups.
        case opened
        /// Every tab of the profile, the person's own included.
        case all

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .opened: "Only tabs it opens"
            case .all: "Existing tabs too"
            }
        }
    }

    /// What a framework drives: one of the person's profiles, by the
    /// identifier its Spaces carry, or a throwaway one.
    enum Profile: Hashable, Sendable {
        case profile(UUID)
        case ephemeral

        static let ephemeralName = "ephemeral"

        init?(stored: String?) {
            guard let stored else { return nil }
            if stored == Self.ephemeralName {
                self = .ephemeral
            } else if let id = UUID(uuidString: stored) {
                self = .profile(id)
            } else {
                return nil
            }
        }

        var stored: String {
            switch self {
            case .profile(let id): id.uuidString.lowercased()
            case .ephemeral: Self.ephemeralName
            }
        }
    }

    /// The settings the engine starts with.
    struct Values: Equatable, Sendable {
        var isOn: Bool
        var port: Int
        var profile: Profile
        var tabs: TabReach
    }

    private enum Key {
        static let enabled = "arma.automation.enabled"
        static let port = "arma.automation.port"
        static let profile = "arma.automation.profile"
        static let tabs = "arma.automation.tabs"
        /// The profile whose Space shows the tabs of an Ephemeral profile or
        /// a context a framework made, since tabs belong to a Space.
        static let hostProfile = "arma.automation.hostProfile"
    }

    // MARK: - Static Variables

    static let shared = BrowserAutomationPreferences()

    /// The port a framework connects to unless the person picks another.
    static let defaultPort = 9222
    /// The ports a person may pick: unprivileged ones.
    static let ports = 1024...65535

    // MARK: - Variables

    private let defaults: UserDefaults
    /// The isolated launch's defaults suite, which the engine is told to read.
    private let suiteName: String?
    /// What this run of Arma started with.
    let launched: Values
    private(set) var values: Values

    /// Whether a change waits for Arma to restart.
    var needsRestart: Bool { values != launched }

    // MARK: - Initializers

    private init() {
        let environment = BrowserLaunchEnvironment.current
        if environment.requiresIsolation {
            let id = environment.persistentIsolationID ?? "ephemeral-\(UUID().uuidString)"
            let suite = BrowserLaunchEnvironment.isolatedDefaultsSuiteName(isolationID: id)
            suiteName = suite
            defaults = UserDefaults(suiteName: suite)!
        } else {
            suiteName = nil
            defaults = .standard
        }
        let stored = Self.read(from: defaults)
        launched = stored
        values = stored
    }

    // MARK: - Actions - Changing

    func setOn(_ isOn: Bool) { change { $0.isOn = isOn } }

    func setPort(_ port: Int) {
        guard Self.ports.contains(port) else { return }
        change { $0.port = port }
    }

    func setProfile(_ profile: Profile) { change { $0.profile = profile } }

    func setTabs(_ tabs: TabReach) { change { $0.tabs = tabs } }

    /// Records the profile whose Space shows tabs that belong to no Space's
    /// profile: the chosen profile's own, or for Ephemeral, `fallback`, the
    /// profile of the Space the person is using.
    func recordHost(fallback: UUID?) {
        let host: UUID? =
            switch values.profile {
            case .profile(let id): id
            case .ephemeral: fallback
            }
        defaults.set(host?.uuidString.lowercased(), forKey: Key.hostProfile)
    }

    // MARK: - Actions - Engine

    /// Tells the engine where these settings live and whether it must start
    /// with the app, before it starts: it reads them once, at startup, and
    /// only a running engine listens on the port.
    func prepareEngine() -> Bool {
        if let suiteName { setenv("ARMA_AUTOMATION_DEFAULTS_SUITE", suiteName, 1) }
        return launched.isOn
    }

    private func change(_ edit: (inout Values) -> Void) {
        var next = values
        edit(&next)
        guard next != values else { return }
        values = next
        defaults.set(next.isOn, forKey: Key.enabled)
        defaults.set(next.port, forKey: Key.port)
        defaults.set(next.profile.stored, forKey: Key.profile)
        defaults.set(next.tabs.rawValue, forKey: Key.tabs)
    }

    // MARK: - Actions - Restarting

    /// Quits Arma and opens it again once it has gone, so the engine starts
    /// with the settings as they are now.
    func restart() {
        let bundle = Bundle.main.bundleURL.path
        let pid = ProcessInfo.processInfo.processIdentifier
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = [
            "-c", "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\"", bundle,
        ]
        relaunch.environment = ProcessInfo.processInfo.environment
        do {
            try relaunch.run()
        } catch {
            return
        }
        NSApp.terminate(nil)
    }

    // MARK: - Actions - Reading

    private static func read(from defaults: UserDefaults) -> Values {
        let port = defaults.integer(forKey: Key.port)
        return Values(
            isOn: defaults.bool(forKey: Key.enabled),
            port: ports.contains(port) ? port : defaultPort,
            profile: Profile(stored: defaults.string(forKey: Key.profile)) ?? .ephemeral,
            tabs: defaults.string(forKey: Key.tabs).flatMap(TabReach.init(rawValue:)) ?? .opened)
    }
}
