import AppKit
import os

/// Runs the commands a person gives Crest from their own terminal through the
/// `bettercrest` helper, such as `bettercrest theme`. They reach Crest
/// over a Unix domain socket of their own that exists while Crest runs and
/// admits only this Crest's helper running as this user, so a person's own
/// command never needs agents turned on or an agent's approval. Each
/// connection carries one request and gets one answer.
@MainActor
final class BrowserMacCommands {
    // MARK: - Static Variables

    static let maximumConnections = 8

    private static let logger = Logger(subsystem: "com.senpaimedia.bettercrest", category: "Commands")

    // MARK: - Variables

    unowned let application: BrowserMacApplication
    /// Where the helper connects, or nil when this launch offers no socket.
    let path: String?
    /// What a helper must be to be heard: this Crest's own.
    private let helper: BrowserAgentHelperRequirement?
    private var listener: BrowserAgentListener?
    private var connections: [ObjectIdentifier: BrowserAgentConnection] = [:]

    private var browser: BrowserStore { application.browser }

    // MARK: - Initializers

    init(application: BrowserMacApplication) {
        self.application = application
        helper = BrowserAgentHelperRequirement(bundle: .main)
        path =
            helper == nil
            ? nil : Bundle.main.bundleIdentifier.flatMap { AgentSocketLocation.path(forApp: $0, lane: .commands) }
    }

    // MARK: - Actions - Lifecycle

    /// Opens the socket for as long as Crest runs.
    func start() {
        guard listener == nil, let path, let helper else { return }
        let listener = BrowserAgentListener(path: path, helper: helper) { [weak self] connection in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.admit(connection) } }
        }
        do {
            try listener.start()
            self.listener = listener
        } catch {
            Self.logger.error("The commands socket could not open: \(String(describing: error), privacy: .public)")
        }
    }

    /// Removes the socket and ends every connection, as the app quits.
    func stop() {
        if let listener, !listener.stop() {
            Self.logger.error("The commands socket did not close in time.")
        }
        listener = nil
        for connection in connections.values { connection.close() }
        connections = [:]
    }

    // MARK: - Actions - Connections

    private func admit(_ connection: BrowserAgentConnection) {
        guard listener != nil, connections.count < Self.maximumConnections else {
            connection.close()
            return
        }
        let key = ObjectIdentifier(connection)
        connections[key] = connection
        connection.open { [weak self] line in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.receive(line, on: key) } }
        } ended: { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.connections[key] = nil } }
        }
    }

    private func receive(_ line: Data, on key: ObjectIdentifier) {
        guard let connection = connections[key] else { return }
        guard let request = try? JSONDecoder().decode(CommandLinkRequest.self, from: line) else {
            connection.close()
            return
        }
        let response: CommandLinkResponse
        switch request {
        case .theme(let version, let space, let changes, let resets, let removeDark, let export):
            response =
                version == CommandLinkRequest.version
                ? theme(space, changes: changes, resets: resets, removeDark: removeDark, export: export)
                : .refused(
                    message:
                        "This helper is from another build. Run the one inside the BetterCrest that is open.")
        }
        if let answer = try? JSONEncoder().encode(response) { connection.send(answer) }
        connection.close()
    }

    // MARK: - Actions - Themes

    /// Dresses the Space `name` names, by name or identifier: the `resets`
    /// sections go back to the Space's starting look, then `changes` is laid
    /// on. Answers the Space's theme when `export`, else what changed.
    private func theme(
        _ name: String, changes: CrestTheme?, resets: [CrestThemeSection], removeDark: Bool, export: Bool
    ) -> CommandLinkResponse {
        let spaces = browser.spaceModels
        guard let space = Self.space(named: name, in: spaces) else {
            let names = spaces.map { "'\($0.settings.name)'" }.joined(separator: ", ")
            return .refused(message: "There is no Space named '\(name)'. The Spaces are \(names).")
        }
        guard !application.spaceAccess.isLocked(space) else {
            return .refused(message: "Unlock the '\(space.settings.name)' Space in BetterCrest first.")
        }
        let current = space.settings.look
        let currentDark = space.settings.darkBranding
        var look = current
        var dark = currentDark
        let starting = current.startingLook ?? .neutral
        for section in resets {
            look = look.resetting(section, to: starting)
            dark = dark?.resetting(section, to: starting)
        }
        if removeDark { dark = nil }
        if let changes {
            do {
                look = try look.dressed(in: changes)
                if let darkSections = changes.dark { dark = try (dark ?? look).dressed(in: darkSections) }
            } catch {
                return .refused(message: error.message)
            }
        }
        if look != current {
            browser.updateSpaceBranding(look.normalized(), in: space.id)
        }
        if dark != currentDark {
            browser.updateSpaceDarkBranding(dark?.normalized(), in: space.id)
        }
        if export {
            let settings = browser.spaceModel(space.id)?.settings
            return .theme(CrestTheme(look: settings?.look ?? look, dark: settings?.darkBranding ?? dark))
        }
        var did: [String] = []
        if !resets.isEmpty { did.append("reset \(resets.map(\.rawValue).joined(separator: ", "))") }
        if removeDark { did.append("unpaired the dark look") }
        if let changes {
            var sections: [String] = []
            if changes.background != nil { sections.append("background") }
            if changes.icon != nil { sections.append("icon") }
            if changes.folders != nil { sections.append("folders") }
            if changes.commandPalette != nil { sections.append("command palette") }
            if changes.dark != nil { sections.append("dark look") }
            did.append("applied \(sections.joined(separator: ", "))")
        }
        return .applied(summary: "\(space.settings.name): \(did.joined(separator: "; ")).")
    }

    /// The Space `name` names: the one whose name matches, ignoring case,
    /// else the one whose identifier it is.
    private static func space(named name: String, in spaces: [SpaceModel]) -> SpaceModel? {
        let wanted = name.trimmingCharacters(in: .whitespaces)
        if let match = spaces.first(where: {
            $0.settings.name.compare(wanted, options: .caseInsensitive) == .orderedSame
        }) {
            return match
        }
        guard let id = UUID(uuidString: wanted) else { return nil }
        return spaces.first { $0.id == id }
    }
}
