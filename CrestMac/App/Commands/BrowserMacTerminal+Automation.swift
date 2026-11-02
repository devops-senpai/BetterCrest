import AppKit

/// `arma automation`, run in the app on the same preferences Settings ›
/// Automation shows.
extension TerminalAutomationCommand {
    // MARK: - Types

    private struct Status: Encodable {
        let on: Bool
        let profile: String
        let tabs: String
        let port: Int
        let listening: String?
        let restartNeeded: Bool
    }

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        let preferences = BrowserAutomationPreferences.shared
        switch self {
        case .status:
            return status(preferences, in: terminal)
        case .set(let isOn, let profileName, let tabs, let port):
            if let profileName {
                if profileName.lowercased() == BrowserAutomationPreferences.Profile.ephemeralName {
                    preferences.setProfile(.ephemeral)
                } else {
                    preferences.setProfile(.profile(try terminal.space(profileName).profileID))
                }
            }
            if let tabs, let reach = BrowserAutomationPreferences.TabReach(rawValue: tabs) {
                preferences.setTabs(reach)
            }
            if let port {
                guard BrowserAutomationPreferences.ports.contains(port) else {
                    throw BrowserMacTerminal.Refusal("The port is a number from 1024 to 65535.")
                }
                preferences.setPort(port)
            }
            if let isOn { preferences.setOn(isOn) }
            let shown = terminal.frontWindow?.browser.shownSpace ?? terminal.spaces.first
            preferences.recordHost(fallback: shown?.profileID)
            return status(preferences, in: terminal)
        case .restart:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { preferences.restart() }
            return TerminalOutput(text: "Restarting Arma.")
        }
    }

    @MainActor
    private func status(_ preferences: BrowserAutomationPreferences, in terminal: BrowserMacTerminal)
        -> TerminalOutput
    {
        let values = preferences.values
        let profile: String =
            switch values.profile {
            case .ephemeral: "Ephemeral"
            case .profile(let id):
                terminal.spaces.filter { $0.profileID == id }.map(\.settings.name).joined(separator: ", ")
            }
        let listening = preferences.launched.isOn ? "127.0.0.1:\(preferences.launched.port)" : nil
        let state = Status(
            on: values.isOn, profile: profile, tabs: values.tabs.rawValue, port: values.port, listening: listening,
            restartNeeded: preferences.needsRestart)
        let tabs =
            values.profile == .ephemeral
            ? "all (ephemeral)" : values.tabs == .opened ? "only tabs it opens" : "existing tabs too"
        var lines = [
            "Automation  \(values.isOn ? "on" : "off")",
            "Profile     \(profile.isEmpty ? "a profile no Space uses" : profile)",
            "Tabs        \(tabs)",
            "Port        \(values.port)",
            "Listening   \(listening ?? "no")",
        ]
        if preferences.needsRestart { lines.append("\nRestart Arma to apply: arma automation restart") }
        if let listening {
            lines.append("\nConnect: puppeteer.connect({ browserURL: \"http://\(listening)\" })")
            lines.append("         chromium.connectOverCDP(\"http://\(listening)\")")
        }
        return TerminalOutput(text: lines.joined(separator: "\n"), value: state)
    }
}
