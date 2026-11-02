import AppKit

/// `arma folder`, run in the app through the same browser store calls the
/// sidebar's folder rows and menus make.
extension TerminalFolderCommand {
    // MARK: - Types

    private struct FolderRow: Encodable {
        let id: UUID
        let space: String
        let section: String
        let path: String
        let depth: Int
        let tabs: Int
        let expanded: Bool
        let color: String?
    }

    private typealias Refusal = BrowserMacTerminal.Refusal

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        let browser = terminal.browser
        switch self {
        case .list(let name):
            return try list(space: name, in: terminal)
        case .create(let name, let spaceName, let parentPath, let open):
            return try create(name, space: spaceName, inside: parentPath, open: open, in: terminal)
        case .rename(let path, let name, let spaceName):
            let space = try terminal.unlocked(try terminal.space(spaceName))
            let folder = try terminal.folder(path, in: space)
            let title = name.trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty, !title.contains("/") else {
                throw Refusal("A folder's name has no / and is not empty.")
            }
            guard browser.renameFolder(folder.id, matching: Self.assignment(of: space), title: title) else {
                throw Refusal("Arma could not rename that folder.")
            }
            return TerminalOutput(text: "Renamed \(path) to \(title).")
        case .delete(let path, let spaceName):
            let space = try terminal.unlocked(try terminal.space(spaceName))
            let folder = try terminal.folder(path, in: space)
            let shown = terminal.folderPath(folder, in: space).joined(separator: "/")
            let tabs = space.tabs.models.filter { $0.folderID == folder.id }.count
            let section = Self.section(of: folder)
            guard browser.deleteFolder(folder.id, matching: Self.assignment(of: space)) else {
                throw Refusal("Arma could not delete that folder.")
            }
            let kept =
                switch tabs {
                case 0: ""
                case 1: " Its tab stays in the \(section) tabs."
                default: " Its \(tabs) tabs stay in the \(section) tabs."
                }
            return TerminalOutput(text: "Deleted \(shown).\(kept) Any folders inside it move up one level.")
        case .add(let references, let path, let spaceName):
            return try add(references, to: path, space: spaceName, in: terminal)
        case .expand(let path, let spaceName, let expanded):
            let space = try terminal.unlocked(try terminal.space(spaceName))
            let folder = try terminal.folder(path, in: space)
            guard folder.isCollapsed == expanded else {
                return TerminalOutput(text: "\(path) is already \(expanded ? "open" : "closed").")
            }
            guard browser.setFolderCollapsed(folder.id, matching: Self.assignment(of: space), isCollapsed: !expanded)
            else { throw Refusal("Arma could not \(expanded ? "open" : "close") that folder.") }
            return TerminalOutput(text: "\(expanded ? "Opened" : "Closed") \(path).")
        case .color(let path, let hex, let spaceName):
            let space = try terminal.unlocked(try terminal.space(spaceName))
            let folder = try terminal.folder(path, in: space)
            let assignment = Self.assignment(of: space)
            guard let hex else {
                guard browser.clearFolderColor(folder.id, matching: assignment) else {
                    throw Refusal("Arma could not change that folder's color.")
                }
                return TerminalOutput(text: "\(path) wears its Space's folder colors again.")
            }
            guard let color = BrandColor(hex: hex) else { throw Refusal("'\(hex)' is not a color like #4A90E2.") }
            guard browser.setFolderColor(folder.id, matching: assignment, color: color) else {
                throw Refusal("Arma could not change that folder's color.")
            }
            return TerminalOutput(text: "Colored \(path) \(color.hexText).")
        }
    }

    // MARK: - Actions - Listing

    @MainActor
    private func list(space name: String?, in terminal: BrowserMacTerminal) throws(Refusal) -> TerminalOutput {
        var spaces = terminal.spaces.filter { !terminal.application.spaceAccess.isLocked($0) }
        if let name { spaces = [try terminal.unlocked(try terminal.space(name))] }
        var rows: [FolderRow] = []
        for space in spaces {
            for section in [TabPlacement.saved, .current] {
                for choice in space.folderChoices(in: [section]) {
                    let folder = choice.folder
                    let path = terminal.folderPath(folder, in: space)
                    rows.append(
                        FolderRow(
                            id: folder.id, space: space.settings.name, section: Self.section(of: folder),
                            path: path.joined(separator: "/"), depth: path.count - 1,
                            tabs: space.tabIDs(inFolder: folder.id).count, expanded: !folder.isCollapsed,
                            color: folder.color?.hexText))
                }
            }
        }
        guard !rows.isEmpty else { return TerminalOutput(text: "No folders.", value: ["folders": rows]) }
        let text = BrowserMacTerminal.table(
            ["SPACE", "SECTION", "TABS", "COLOR", "FOLDER"],
            rows.map { row in
                let name = row.path.split(separator: "/").last.map(String.init) ?? row.path
                let mark = row.expanded ? "v " : "> "
                return [
                    row.space, row.section, String(row.tabs), row.color ?? "-",
                    String(repeating: "  ", count: row.depth) + mark + name,
                ]
            })
        return TerminalOutput(text: text, value: ["folders": rows])
    }

    // MARK: - Actions - Organizing

    @MainActor
    private func create(
        _ name: String, space spaceName: String?, inside parentPath: String?, open: Bool,
        in terminal: BrowserMacTerminal
    ) throws(Refusal) -> TerminalOutput {
        let browser = terminal.browser
        let space = try terminal.unlocked(try terminal.space(spaceName))
        let title = name.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, !title.contains("/") else { throw Refusal("A folder's name has no / and is not empty.") }
        var parent: FolderStateModel?
        if let parentPath { parent = try terminal.folder(parentPath, in: space) }
        let location: BrowserFolderLocation
        if let parent {
            location = parent.location == .saved ? .saved : .current
            if open, location == .saved {
                throw Refusal("\(parentPath ?? "That folder") is a saved folder; leave out --open to make one in it.")
            }
        } else {
            location = open ? .current : .saved
        }
        let assignment = Self.assignment(of: space)
        let made: UUID?
        if location == .saved {
            made = browser.addFolder(title: title, parentID: parent?.id, matching: assignment)
        } else {
            // A new folder starts saved; the open-tabs section takes it next.
            made = browser.addFolder(title: title, matching: assignment)
            if let made, !browser.moveFolder(made, matching: assignment, to: .current, into: parent?.id) {
                browser.deleteFolder(made, matching: assignment)
                throw Refusal("Arma could not make a folder there in the open tabs.")
            }
        }
        guard let made, let folder = space.folders.model(made) else {
            throw Refusal("Arma could not make that folder; the Space may hold as many, or as deep, as it can.")
        }
        let path = terminal.folderPath(folder, in: space).joined(separator: "/")
        return TerminalOutput(
            text: "Made \(path) in \(space.settings.name)'s \(Self.section(of: folder)) tabs.", value: ["folder": made])
    }

    @MainActor
    private func add(
        _ references: [String], to path: String, space spaceName: String?, in terminal: BrowserMacTerminal
    ) throws(Refusal) -> TerminalOutput {
        var found: [BrowserMacTerminal.FoundTab] = []
        for reference in references { found.append(try terminal.tab(reference)) }
        let space = try terminal.unlocked(try terminal.space(spaceName ?? found[0].space.id.uuidString))
        if let other = found.first(where: { $0.space.id != space.id }) {
            throw Refusal(
                "\(other.tab.displayTitle) is in \(other.space.settings.name). Move it with arma tab move first.")
        }
        let folder = try terminal.folder(path, in: space)
        guard
            terminal.browser.fileTabs(
                found.map(\.tab.id), matching: Self.assignment(of: space), into: folder.id,
                location: folder.location == .saved ? .saved : .current)
        else { throw Refusal("Arma could not put those tabs in \(path).") }
        let shown = terminal.folderPath(folder, in: space).joined(separator: "/")
        let what = found.count == 1 ? found[0].tab.displayTitle : "\(found.count) tabs"
        return TerminalOutput(text: "Filed \(what) into \(shown).")
    }

    // MARK: - Actions - Values

    /// The sidebar section `folder` is in, as the terminal names it.
    @MainActor
    private static func section(of folder: FolderStateModel) -> String {
        folder.location == .saved ? "saved" : "open"
    }

    @MainActor
    private static func assignment(of space: SpaceModel) -> BrowserSpaceRuntimeAssignment {
        BrowserSpaceRuntimeAssignment(spaceID: space.id, profileID: space.profileID)
    }
}
