import AppKit

/// `arma space`, run in the app.
extension TerminalSpaceCommand {
    // MARK: - Types

    private struct SpaceRow: Encodable {
        let id: UUID
        let name: String
        let shown: Bool
        let locked: Bool
        let pinned: Int?
        let saved: Int?
        let open: Int?
        let folders: Int?
    }

    private struct SpaceDetail: Encodable {
        let id: UUID
        let name: String
        let pinned: [TabEntry]
        let saved: [TabEntry]
        let open: [TabEntry]
        let folders: [String]
    }

    private struct TabEntry: Encodable {
        let id: UUID
        let title: String
        let url: String?
        let folder: String?
    }

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        switch self {
        case .list:
            return list(in: terminal)
        case .show(let name):
            return show(try terminal.unlocked(try terminal.space(name)), in: terminal)
        case .switchTo(let name):
            let space = try terminal.unlocked(try terminal.space(name))
            guard let window = terminal.frontWindow(over: space) else {
                throw BrowserMacTerminal.Refusal("No Arma window is open. Run arma window open.")
            }
            window.browser.selectSpace(space.id)
            terminal.bringForward(window)
            return TerminalOutput(text: "Showing \(space.settings.name).")
        }
    }

    @MainActor
    private func list(in terminal: BrowserMacTerminal) -> TerminalOutput {
        let shownID = terminal.frontWindow?.browser.shownSpace?.id
        let rows = terminal.spaces.map { space in
            let locked = terminal.application.spaceAccess.isLocked(space)
            let tabs = locked ? [] : space.tabs.models
            return SpaceRow(
                id: space.id, name: space.settings.name, shown: space.id == shownID, locked: locked,
                pinned: locked ? nil : tabs.filter { $0.placement == .pinned }.count,
                saved: locked ? nil : tabs.filter { $0.placement == .saved }.count,
                open: locked ? nil : tabs.filter { $0.placement == .current }.count,
                folders: locked ? nil : space.folders.models.count)
        }
        let text = BrowserMacTerminal.table(
            ["", "SPACE", "PINNED", "SAVED", "OPEN", "FOLDERS", "ID"],
            rows.map { row in
                [
                    row.shown ? "*" : "", row.name + (row.locked ? " (locked)" : ""),
                    row.pinned.map(String.init) ?? "-", row.saved.map(String.init) ?? "-",
                    row.open.map(String.init) ?? "-", row.folders.map(String.init) ?? "-",
                    BrowserMacTerminal.short(row.id),
                ]
            })
        return TerminalOutput(text: text, value: ["spaces": rows])
    }

    @MainActor
    private func show(_ space: SpaceModel, in terminal: BrowserMacTerminal) -> TerminalOutput {
        func entries(_ placement: TabPlacement) -> [TabEntry] {
            space.tabs.models.filter { $0.placement == placement }.map { tab in
                let folder = terminal.folderPath(of: tab, in: space)
                return TabEntry(
                    id: tab.id, title: tab.displayTitle, url: tab.url ?? tab.savedURL,
                    folder: folder.isEmpty ? nil : folder.joined(separator: "/"))
            }
        }
        let detail = SpaceDetail(
            id: space.id, name: space.settings.name, pinned: entries(.pinned), saved: entries(.saved),
            open: entries(.current),
            folders: space.folders.models.map { terminal.folderPath($0, in: space).joined(separator: "/") }.sorted())
        func section(_ title: String, _ tabs: [TabEntry]) -> String {
            guard !tabs.isEmpty else { return "\(title): none" }
            let lines = tabs.map { tab in
                "  \(BrowserMacTerminal.short(tab.id))  \(tab.folder.map { "[\($0)] " } ?? "")\(tab.title)"
            }
            return "\(title) (\(tabs.count)):\n" + lines.joined(separator: "\n")
        }
        let folders =
            detail.folders.isEmpty
            ? "Folders: none"
            : "Folders (\(detail.folders.count)):\n" + detail.folders.map { "  \($0)" }.joined(separator: "\n")
        let text = [
            "\(space.settings.name)  \(space.id.uuidString.lowercased())",
            section("Pinned", detail.pinned), section("Saved", detail.saved), section("Open", detail.open), folders,
        ].joined(separator: "\n\n")
        return TerminalOutput(text: text, value: detail)
    }
}
