import AppKit

/// `arma tab`, run in the app through the same browser store calls the
/// sidebar and menus make.
extension TerminalTabCommand {
    // MARK: - Types

    private struct TabRow: Encodable {
        let id: UUID
        let space: String
        let title: String
        let url: String?
        let placement: String
        let folder: String?
        let loaded: Bool
        let engine: String?
        let shown: Bool
    }

    private typealias Refusal = BrowserMacTerminal.Refusal

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) async throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        let browser = terminal.browser
        switch self {
        case .list(let space, let folder, let loadedOnly):
            return try list(space: space, folder: folder, loadedOnly: loadedOnly, in: terminal)
        case .open(let url, let space, let engine, let background):
            return try open(Self.address(url), space: space, engine: engine, background: background, in: terminal)
        case .close(let reference):
            return try await close(try terminal.tab(reference), in: terminal)
        case .show(let reference):
            let found = try terminal.tab(reference)
            guard let window = terminal.frontWindow(over: found.space) else {
                throw Refusal("No Arma window is open. Run arma window open.")
            }
            window.browser.selectSpace(found.space.id)
            guard window.browser.activateSessionTab(found.tab.id, in: found.space.id) else {
                throw Refusal("Arma could not show that tab.")
            }
            terminal.bringForward(window)
            return TerminalOutput(text: "Showing \(found.tab.displayTitle).")
        case .reload(let reference, let hard):
            let found = try terminal.tab(reference)
            try terminal.page(of: found).enginePage.reload(bypassingCache: hard)
            return TerminalOutput(text: "Reloaded \(found.tab.displayTitle).")
        case .go(let reference, let text):
            let found = try terminal.tab(reference)
            let url = try Self.address(text)
            guard try terminal.page(of: found).corePage.load(url) else {
                throw Refusal("Arma did not load \(url.absoluteString) there.")
            }
            return TerminalOutput(text: "Loading \(url.absoluteString).")
        case .engine(let reference, let engine):
            let found = try terminal.tab(reference)
            let page = try terminal.page(of: found)
            let kind = Self.kind(of: engine)
            guard page.corePage.state?.engine != kind else {
                return TerminalOutput(text: "\(found.tab.displayTitle) already runs on \(engine.rawValue).")
            }
            guard page.corePage.otherEngines.contains(kind) else {
                let others = page.corePage.otherEngines.map(\.name)
                throw Refusal(
                    "This Arma has no \(engine.rawValue) engine to move to"
                        + (others.isEmpty ? "." : "; it has \(others.joined(separator: ", "))."))
            }
            guard page.corePage.move(to: kind) else {
                throw Refusal("Arma could not move that page to \(engine.rawValue).")
            }
            return TerminalOutput(text: "Moved \(found.tab.displayTitle) to \(engine.rawValue).")
        case .move(let reference, let spaceName, let folderPath):
            return try move(try terminal.tab(reference), to: spaceName, folder: folderPath, in: terminal)
        case .pin(let reference):
            return try place(try terminal.tab(reference), .pinned, "Pinned", in: terminal)
        case .save(let reference):
            return try place(try terminal.tab(reference), .saved, "Saved", in: terminal)
        case .unpin(let reference):
            return try place(try terminal.tab(reference), .current, "Made an open tab of", in: terminal)
        case .duplicate(let reference):
            let found = try terminal.tab(reference)
            guard let copy = browser.duplicateTab(found.tab.id, in: found.space.id) else {
                throw Refusal("Arma could not duplicate that tab.")
            }
            return TerminalOutput(text: "Duplicated as \(BrowserMacTerminal.short(copy)).", value: ["tab": copy])
        case .rename(let reference, let title):
            let found = try terminal.tab(reference)
            guard browser.renameSessionTab(title, tabID: found.tab.id, in: found.space.id) else {
                throw Refusal("Arma could not rename that tab.")
            }
            return TerminalOutput(text: title.map { "Renamed to \($0)." } ?? "Showing the page's own title.")
        case .reopen:
            guard browser.reopenClosedTab() else { throw Refusal("There is no closed tab to reopen.") }
            return TerminalOutput(text: "Reopened the tab closed last.")
        }
    }

    // MARK: - Actions - Listing

    @MainActor
    private func list(
        space name: String?, folder path: String?, loadedOnly: Bool, in terminal: BrowserMacTerminal
    ) throws(Refusal) -> TerminalOutput {
        var spaces = terminal.spaces.filter { !terminal.application.spaceAccess.isLocked($0) }
        if let name { spaces = [try terminal.unlocked(try terminal.space(name))] }
        var folder: FolderStateModel?
        if let path {
            guard spaces.count == 1 else { throw Refusal("Name the folder's Space with --space.") }
            folder = try terminal.folder(path, in: spaces[0])
        }
        let windows = terminal.application.stackedWindowIDs.compactMap { terminal.browser.core.state.windows[$0] }
        var rows: [TabRow] = []
        for space in spaces {
            for tab in space.tabs.models {
                if let folder, !Self.tab(tab, isIn: folder, of: space) { continue }
                let page = terminal.residentPage(of: tab.id)
                if loadedOnly, page == nil { continue }
                let folderPath = terminal.folderPath(of: tab, in: space)
                let shown = windows.contains { $0.shownTabIDs.contains(tab.id) }
                rows.append(
                    TabRow(
                        id: tab.id, space: space.settings.name, title: tab.displayTitle, url: tab.url ?? tab.savedURL,
                        placement: tab.placement == .current ? "open" : tab.placement.name,
                        folder: folderPath.isEmpty ? nil : folderPath.joined(separator: "/"),
                        loaded: page != nil, engine: page?.corePage.state?.engine.name, shown: shown))
            }
        }
        let text =
            rows.isEmpty
            ? "No tabs."
            : BrowserMacTerminal.table(
                ["ID", "SPACE", "WHERE", "FOLDER", "ENGINE", "TITLE"],
                rows.map { row in
                    [
                        BrowserMacTerminal.short(row.id), row.space, row.placement + (row.shown ? " *" : ""),
                        row.folder ?? "-", row.engine ?? (row.loaded ? "?" : "-"), String(row.title.prefix(60)),
                    ]
                })
        return TerminalOutput(text: text, value: ["tabs": rows])
    }

    /// Whether `tab` is in `folder` or a folder inside it.
    @MainActor
    private static func tab(_ tab: TabStateModel, isIn folder: FolderStateModel, of space: SpaceModel) -> Bool {
        var current = tab.folderID
        var visited = Set<UUID>()
        while let id = current, visited.insert(id).inserted {
            if id == folder.id { return true }
            current = space.folders.model(id)?.parentID
        }
        return false
    }

    // MARK: - Actions - Opening and closing

    @MainActor
    private func open(
        _ url: URL, space name: String?, engine: TerminalEngine?, background: Bool, in terminal: BrowserMacTerminal
    ) throws(Refusal) -> TerminalOutput {
        guard let name else {
            guard engine == nil else {
                throw Refusal("--engine needs --space; a Quick Window opens in its Space's engine.")
            }
            let space = try terminal.space(nil)
            let request = BrowserQuickWindowRequest(
                url: url, spaceAssignment: BrowserSpaceRuntimeAssignment(spaceID: space.id, profileID: space.profileID))
            guard terminal.windows.openQuickWindow(request) != nil else {
                throw Refusal("Arma could not open a Quick Window.")
            }
            return TerminalOutput(
                text: "Opened \(url.absoluteString) in a Quick Window; its Space menu picks the Space.")
        }
        let space = try terminal.unlocked(try terminal.space(name))
        let window = terminal.frontWindow(over: space)
        let shows = !background && window != nil
        let browser = window?.browser ?? terminal.browser
        guard let tabID = browser.openNewTab(url: url, in: space.id, selecting: shows),
            let tab = space.tabs.model(tabID)
        else { throw Refusal("Arma could not open a tab in \(space.settings.name).") }
        var notes: [String] = []
        if let engine {
            let page = try terminal.page(of: BrowserMacTerminal.FoundTab(space: space, tab: tab))
            let kind = Self.kind(of: engine)
            if page.corePage.state?.engine != kind, !page.corePage.move(to: kind) {
                notes.append("It stayed on its first engine; Arma could not move it to \(engine.rawValue).")
            }
        }
        if shows, let window {
            window.browser.selectSpace(space.id)
            terminal.bringForward(window)
        } else if window == nil {
            notes.append("No Arma window is open, so it opened behind.")
        }
        let opened = "Opened \(BrowserMacTerminal.short(tabID)) in \(space.settings.name)."
        return TerminalOutput(text: ([opened] + notes).joined(separator: " "), value: ["tab": tabID])
    }

    @MainActor
    private func close(_ found: BrowserMacTerminal.FoundTab, in terminal: BrowserMacTerminal) async throws(Refusal)
        -> TerminalOutput
    {
        let title = found.tab.displayTitle
        if found.tab.placement.isDurable {
            let assignment = BrowserTabRuntimeAssignment(
                tabID: found.tab.id, spaceID: found.space.id, profileID: found.space.profileID)
            let browser = terminal.frontWindow(over: found.space)?.browser ?? terminal.browser
            guard browser.closeDurableTab(assignment) else { throw Refusal("Arma could not close that tab.") }
            return TerminalOutput(text: "Put away \(title)'s page; the tab stays \(found.tab.placement.name).")
        }
        let browser = terminal.frontWindow(over: found.space)?.browser ?? terminal.browser
        if browser.closeTab(found.tab.id, in: found.space.id) { return TerminalOutput(text: "Closed \(title).") }
        // A page asked whether it may go answers after this returns.
        let deadline = ContinuousClock.now + .seconds(2)
        while found.space.tabs.contains(found.tab.id), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard !found.space.tabs.contains(found.tab.id) else {
            throw Refusal("The page asked whether to leave; answer it in Arma. The tab is still open.")
        }
        return TerminalOutput(text: "Closed \(title).")
    }

    // MARK: - Actions - Organizing

    @MainActor
    private func move(
        _ found: BrowserMacTerminal.FoundTab, to spaceName: String?, folder path: String?,
        in terminal: BrowserMacTerminal
    ) throws(Refusal) -> TerminalOutput {
        var destination = found.space
        if let spaceName { destination = try terminal.unlocked(try terminal.space(spaceName)) }
        if destination.id != found.space.id {
            guard terminal.browser.moveTab(found.tab.id, from: found.space.id, into: destination.id) else {
                throw Refusal("Arma could not move that tab to \(destination.settings.name).")
            }
        }
        guard let path else {
            return TerminalOutput(text: "Moved \(found.tab.displayTitle) to \(destination.settings.name).")
        }
        let folder = try terminal.folder(path, in: destination)
        let assignment = BrowserSpaceRuntimeAssignment(spaceID: destination.id, profileID: destination.profileID)
        guard
            terminal.browser.fileTabs(
                [found.tab.id], matching: assignment, into: folder.id,
                location: folder.location == .saved ? .saved : .current)
        else { throw Refusal("Arma could not put that tab in \(path).") }
        let shown = terminal.folderPath(folder, in: destination).joined(separator: "/")
        return TerminalOutput(text: "Moved \(found.tab.displayTitle) into \(shown).")
    }

    @MainActor
    private func place(
        _ found: BrowserMacTerminal.FoundTab, _ placement: TabPlacement, _ verb: String,
        in terminal: BrowserMacTerminal
    ) throws(Refusal) -> TerminalOutput {
        guard found.tab.placement != placement || found.tab.folderID != nil else {
            return TerminalOutput(text: "\(found.tab.displayTitle) is already \(placement.name).")
        }
        guard terminal.browser.moveSessionTab(found.tab.id, in: found.space.id, to: placement) else {
            throw Refusal("Arma could not move that tab.")
        }
        return TerminalOutput(text: "\(verb) \(found.tab.displayTitle).")
    }

    // MARK: - Actions - Values

    /// `text` as a web address, with https assumed when it names none.
    static func address(_ text: String) throws(BrowserMacTerminal.Refusal) -> URL {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let spelled = trimmed.contains("://") || trimmed.hasPrefix("about:") ? trimmed : "https://" + trimmed
        guard let url = URL(string: spelled), url.scheme != nil else {
            throw BrowserMacTerminal.Refusal("'\(text)' is not an address.")
        }
        return url
    }

    /// The engine `engine` names.
    static func kind(of engine: TerminalEngine) -> EngineKind {
        switch engine {
        case .chromium: .chromium
        case .webkit: .webKit
        case .servo: .servo
        }
    }
}
