import AppKit

/// Runs what a person types as `arma <section> <action>` in their own
/// terminal, against the running Arma. The commands socket admits only this
/// Arma's helper running as this user, so a command acts as the person would
/// from the menus: through the same browser stores, page pools and windows,
/// and the core's rules. It never acts for an agent.
@MainActor
final class BrowserMacTerminal {
    // MARK: - Types

    /// Why a command did not run, as the terminal prints it.
    struct Refusal: Error {
        let message: String

        init(_ message: String) {
            self.message = message
        }
    }

    /// One tab, found by its reference, with its Space.
    struct FoundTab {
        let space: SpaceModel
        let tab: TabStateModel
    }

    // MARK: - Variables

    unowned let application: BrowserMacApplication
    unowned let windows: BrowserMacWindows

    var browser: BrowserStore { application.browser }

    // MARK: - Initializers

    init(application: BrowserMacApplication, windows: BrowserMacWindows) {
        self.application = application
        self.windows = windows
    }

    // MARK: - Actions - Running

    func run(_ command: TerminalCommand) async throws(Refusal) -> TerminalOutput {
        switch command {
        case .space(let space): try space.run(in: self)
        case .tab(let tab): try await tab.run(in: self)
        case .window(let window): try window.run(in: self)
        case .folder(let folder): try folder.run(in: self)
        case .split(let split): try split.run(in: self)
        case .command(let command): try command.run(in: self)
        case .extension(let command): try await command.run(in: self)
        case .history(let history): try history.run(in: self)
        case .download(let download): try download.run(in: self)
        case .page(let page): try await page.run(in: self)
        case .automation(let automation): try automation.run(in: self)
        case .settings(let settings): try await settings.run(in: self)
        case .site(let site): try await site.run(in: self)
        case .theme(let theme): try theme.run(in: self)
        case .crest(let crest): try crest.run(in: self)
        }
    }

    // MARK: - Actions - Spaces

    /// Every Space in the sidebar's order.
    var spaces: [SpaceModel] { browser.spaceModels }

    /// The Space `name` names, by name in any case or identifier; the front
    /// window's when `name` is nil.
    func space(_ name: String?) throws(Refusal) -> SpaceModel {
        guard let name else {
            guard let space = frontWindow?.browser.shownSpace ?? browser.shownSpace else {
                throw Refusal("No Space is shown. Name one with --space.")
            }
            return space
        }
        let wanted = name.trimmingCharacters(in: .whitespaces)
        if let match = spaces.first(where: {
            $0.settings.name.compare(wanted, options: .caseInsensitive) == .orderedSame
        }) {
            return match
        }
        if let id = UUID(uuidString: wanted), let match = spaces.first(where: { $0.id == id }) { return match }
        let names = spaces.map { "'\($0.settings.name)'" }.joined(separator: ", ")
        throw Refusal("There is no Space named '\(name)'. The Spaces are \(names).")
    }

    /// `space`, when it is unlocked.
    func unlocked(_ space: SpaceModel) throws(Refusal) -> SpaceModel {
        guard !application.spaceAccess.isLocked(space) else {
            throw Refusal("Unlock the '\(space.settings.name)' Space in Arma first.")
        }
        return space
    }

    // MARK: - Actions - Tabs

    /// The tab `reference` names: `current`, an identifier, or the start of
    /// one, across every unlocked Space.
    func tab(_ reference: String) throws(Refusal) -> FoundTab {
        let wanted = reference.trimmingCharacters(in: .whitespaces).lowercased()
        if wanted == "current" {
            guard let window = frontWindow, let space = window.browser.shownSpace,
                let tab = window.browser.shownTab
            else { throw Refusal("The front window shows no tab.") }
            return FoundTab(space: space, tab: tab)
        }
        guard wanted.count >= 4 else { throw Refusal("Give at least 4 characters of the tab's id.") }
        var matches: [FoundTab] = []
        for space in spaces where !application.spaceAccess.isLocked(space) {
            for tab in space.tabs.models where tab.id.uuidString.lowercased().hasPrefix(wanted) {
                matches.append(FoundTab(space: space, tab: tab))
            }
        }
        switch matches.count {
        case 1: return matches[0]
        case 0: throw Refusal("No tab's id starts with '\(reference)'. Run arma tab list.")
        default: throw Refusal("\(matches.count) tabs' ids start with '\(reference)'. Give more of it.")
        }
    }

    /// The folder `path` names in `space`: names joined with `/`, or one name
    /// anywhere in the Space when it is unique.
    func folder(_ path: String, in space: SpaceModel) throws(Refusal) -> FolderStateModel {
        let parts = path.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        let matches = space.folders.models.filter { folder in
            folderPath(folder, in: space).suffix(parts.count).elementsEqual(parts) {
                $0.compare($1, options: .caseInsensitive) == .orderedSame
            }
        }
        switch matches.count {
        case 1: return matches[0]
        case 0: throw Refusal("'\(space.settings.name)' has no folder '\(path)'.")
        default:
            throw Refusal(
                "'\(space.settings.name)' has \(matches.count) folders '\(path)'. Give more of its path, such as Parent/\(parts.last ?? "")."
            )
        }
    }

    /// The names of `folder` and the folders above it, outermost first.
    func folderPath(_ folder: FolderStateModel, in space: SpaceModel) -> [String] {
        var path = [folder.title]
        var visited: Set<UUID> = [folder.id]
        var current = folder.parentID
        while let id = current, visited.insert(id).inserted, let parent = space.folders.model(id) {
            path.insert(parent.title, at: 0)
            current = parent.parentID
        }
        return path
    }

    /// The folder path of the folder `tab` is in, or empty.
    func folderPath(of tab: TabStateModel, in space: SpaceModel) -> [String] {
        guard let id = tab.folderID, let folder = space.folders.model(id) else { return [] }
        return folderPath(folder, in: space)
    }

    /// The live page of tab `tabID` in any window, or nil when it has none.
    func residentPage(of tabID: UUID) -> BrowserPage? {
        let pools = [application.pages] + application.windowCoordinator.openWindowPages
        for pool in pools {
            if let page = pool.residentPage(ofTab: tabID) { return page }
        }
        return nil
    }

    /// The live page of `found`, made and loaded at its address when it has
    /// none.
    func page(of found: FoundTab) throws(Refusal) -> BrowserPage {
        if let page = residentPage(of: found.tab.id) { return page }
        guard let page = application.pages.agentPage(for: found.tab, in: found.space) else {
            throw Refusal("Arma could not give that tab a page.")
        }
        return page
    }

    // MARK: - Actions - Windows

    /// The browser windows, front to back, over the person's own Spaces.
    var browserWindows: [BrowserMacWindowModel] {
        application.stackedWindowIDs.compactMap { application.windowCoordinator.existingModel(for: $0) }
            .filter { !$0.isTemporary }
    }

    /// The frontmost browser window, or nil with none open.
    var frontWindow: BrowserMacWindowModel? { browserWindows.first }

    /// The front window that shows `space`'s workspace, or nil.
    func frontWindow(over space: SpaceModel) -> BrowserMacWindowModel? {
        browserWindows.first { $0.browser.spaceModel(space.id) != nil }
    }

    /// The window `reference` names: its number in `arma window list`,
    /// `front`, or its identifier.
    func window(_ reference: String) throws(Refusal) -> (model: BrowserMacWindowModel, window: NSWindow) {
        let models = browserWindows
        let model: BrowserMacWindowModel?
        if reference == "front" {
            model = models.first
        } else if let number = Int(reference) {
            model = models.indices.contains(number - 1) ? models[number - 1] : nil
        } else {
            model = models.first { $0.id.uuidString.lowercased().hasPrefix(reference.lowercased()) }
        }
        guard let model, let window = windows.window(for: model.id) else {
            throw Refusal(
                models.isEmpty ? "No Arma window is open." : "There is no window '\(reference)'. Run arma window list.")
        }
        return (model, window)
    }

    /// Shows what `window` selected and brings it forward, and Arma with it.
    func bringForward(_ window: BrowserMacWindowModel) {
        window.pages.select()
        windows.open(window.request, activation: .key)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Actions - Output

    /// `rows` as aligned columns under `header`.
    static func table(_ header: [String], _ rows: [[String]]) -> String {
        let all = [header] + rows
        let widths = header.indices.map { column in
            all.map { $0.indices.contains(column) ? $0[column].count : 0 }.max() ?? 0
        }
        return all.map { row in
            row.enumerated().map { column, cell in
                column == row.count - 1 ? cell : cell.padding(toLength: widths[column], withPad: " ", startingAt: 0)
            }.joined(separator: "  ")
        }.joined(separator: "\n")
    }

    /// The first eight characters of `id`, which `tab(_:)` accepts back.
    static func short(_ id: UUID) -> String {
        String(id.uuidString.lowercased().prefix(8))
    }
}
