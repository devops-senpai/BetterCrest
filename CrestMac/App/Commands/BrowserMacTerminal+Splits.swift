import AppKit

/// `arma split`, run in the app through the same core intents the sidebar's
/// Split View menus and drags send, from the front window that shows the
/// split's Space.
extension TerminalSplitCommand {
    // MARK: - Types

    private struct SplitRow: Encodable {
        let id: UUID
        let space: String
        let title: String
        let layout: String
        let tabs: [SplitMember]
    }

    private struct SplitMember: Encodable {
        let id: UUID
        let title: String
    }

    private typealias Refusal = BrowserMacTerminal.Refusal
    private typealias FoundTab = BrowserMacTerminal.FoundTab

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        switch self {
        case .list(let name):
            return try list(space: name, in: terminal)
        case .create(let references, let rows):
            return try create(references, rows: rows, in: terminal)
        case .add(let reference, let targetReference):
            let found = try terminal.tab(reference)
            let target = try terminal.tab(targetReference)
            guard found.space.id == target.space.id else {
                throw Refusal(
                    "A split's tabs share one Space. Move \(found.tab.displayTitle) with arma tab move first.")
            }
            let browser = try Self.browser(showing: found.space, in: terminal)
            let join = JoinSplit(
                workspaceID: browser.family.workspaceID, windowID: browser.windowID, spaceID: found.space.id,
                tabID: found.tab.id, targetTabID: target.tab.id, index: nil, landing: nil)
            if let refusal = browser.family.refusal(of: join, from: browser) {
                throw Refusal(refusal.placementExplanation)
            }
            let item = BrowserTabDragItem(
                tabID: found.tab.id, spaceID: found.space.id, profileID: found.space.profileID)
            guard browser.addTabToSplit(item, joining: target.tab.id, at: nil) else {
                throw Refusal("Arma could not add that tab to the split.")
            }
            return TerminalOutput(text: "Added \(found.tab.displayTitle) to \(target.tab.displayTitle)'s split.")
        case .remove(let reference):
            let found = try Self.member(reference, in: terminal)
            let browser = try Self.browser(showing: found.space, in: terminal)
            guard browser.removeTabFromSplit(found.tab.id, matching: Self.assignment(of: found.space)) else {
                throw Refusal("Arma could not take that tab out of its split.")
            }
            return TerminalOutput(text: "Took \(found.tab.displayTitle) out of its split.")
        case .dissolve(let reference):
            let found = try Self.member(reference, in: terminal)
            let browser = try Self.browser(showing: found.space, in: terminal)
            guard browser.dissolveSplit(containing: found.tab.id, matching: Self.assignment(of: found.space)) else {
                throw Refusal("Arma could not end that split.")
            }
            return TerminalOutput(text: "Ended the split; its tabs stay, each on its own.")
        case .arrange(let reference, let name):
            let found = try Self.member(reference, in: terminal)
            guard let arrangement = SplitArrangement.named(name.lowercased()) else {
                let names = SplitArrangement.all.map(\.name).joined(separator: ", ")
                throw Refusal("There is no layout '\(name)'. The layouts are \(names).")
            }
            return try arrange(found, as: arrangement, in: terminal)
        }
    }

    // MARK: - Actions - Listing

    @MainActor
    private func list(space name: String?, in terminal: BrowserMacTerminal) throws(Refusal) -> TerminalOutput {
        var spaces = terminal.spaces.filter { !terminal.application.spaceAccess.isLocked($0) }
        if let name { spaces = [try terminal.unlocked(try terminal.space(name))] }
        var rows: [SplitRow] = []
        for space in spaces {
            // A split keeps a record only once it is named, tinted or tiled;
            // its tabs always name it.
            var groupIDs: [UUID] = []
            for tab in space.tabs.models {
                if let id = tab.splitGroupID, !groupIDs.contains(id) { groupIDs.append(id) }
            }
            for groupID in groupIDs {
                let group = space.splitGroups.first { $0.id == groupID }
                var members = space.splitMembers(of: groupID)
                if members.isEmpty { members = space.tabs.models.filter { $0.splitGroupID == groupID } }
                rows.append(
                    SplitRow(
                        id: groupID, space: space.settings.name,
                        title: group?.displayTitle ?? String(localized: "Split View"),
                        layout: Self.layoutName(of: group?.layout),
                        tabs: members.map { SplitMember(id: $0.id, title: $0.displayTitle) }))
            }
        }
        guard !rows.isEmpty else { return TerminalOutput(text: "No splits.", value: ["splits": rows]) }
        var lines: [String] = []
        for row in rows {
            lines.append("\(row.space): \(row.title) (\(row.layout))")
            for member in row.tabs {
                lines.append("  " + BrowserMacTerminal.short(member.id) + "  " + String(member.title.prefix(60)))
            }
        }
        return TerminalOutput(text: lines.joined(separator: "\n"), value: ["splits": rows])
    }

    /// How a split lays its tabs out, in the words `arrange` takes where one
    /// fits.
    private static func layoutName(of layout: SplitLayoutNode?) -> String {
        guard let layout, let axis = layout.axis else { return "columns" }
        guard layout.children.allSatisfy({ $0.children.isEmpty }) else { return "tiled" }
        return axis.isHorizontal ? "columns" : "rows"
    }

    // MARK: - Actions - Creating

    @MainActor
    private func create(_ references: [String], rows: Bool, in terminal: BrowserMacTerminal) throws(Refusal)
        -> TerminalOutput
    {
        var found: [FoundTab] = []
        for reference in references {
            let tab = try terminal.tab(reference)
            guard !found.contains(where: { $0.tab.id == tab.tab.id }) else { throw Refusal("Name each tab once.") }
            found.append(tab)
        }
        let space = found[0].space
        if let other = found.first(where: { $0.space.id != space.id }) {
            throw Refusal(
                "A split's tabs share one Space, and \(other.tab.displayTitle) is in \(other.space.settings.name).")
        }
        let browser = try Self.browser(showing: space, in: terminal)
        let ids = found.map(\.tab.id)
        let split = SplitTabs(
            workspaceID: browser.family.workspaceID, windowID: browser.windowID, spaceID: space.id,
            selection: TabSelection(tabIDs: ids, folderIDs: [], memberTabIDs: ids), targetTabID: nil, index: nil,
            landing: nil)
        if let refusal = browser.family.refusal(of: split, from: browser) {
            throw Refusal(refusal.placementExplanation)
        }
        guard browser.sendCopying(split, in: space.id) != nil else {
            throw Refusal("Arma could not make that split.")
        }
        let made = "Showing \(found.count) tabs in Split View."
        guard rows else { return TerminalOutput(text: made) }
        guard let member = space.tabs.model(ids[0]), member.splitGroupID != nil else {
            return TerminalOutput(text: made + " Arma could not stack them in rows.")
        }
        let stacked = SplitArrangement.all.first { arrangement in
            arrangement.memberCount == ids.count && !arrangement.axis.isHorizontal
                && arrangement.groups.allSatisfy { $0 == 1 }
        }
        guard let stacked else {
            return TerminalOutput(text: made + " Rows hold up to 4 tabs, so they stay in columns.")
        }
        _ = try arrange(FoundTab(space: space, tab: member), as: stacked, in: terminal)
        return TerminalOutput(text: "Showing \(found.count) tabs in Split View, in stacked rows.")
    }

    @MainActor
    private func arrange(_ found: FoundTab, as arrangement: SplitArrangement, in terminal: BrowserMacTerminal)
        throws(Refusal) -> TerminalOutput
    {
        guard let groupID = found.tab.splitGroupID else { throw Refusal("\(found.tab.displayTitle) is in no split.") }
        let members = found.space.tabs.models.filter { $0.splitGroupID == groupID }.count
        guard arrangement.memberCount == members else {
            let fits = SplitArrangement.all.filter { $0.memberCount == members }.map(\.name)
            throw Refusal(
                "\(arrangement.name) lays out \(arrangement.memberCount) tabs and this split has \(members). "
                    + "Its layouts are \(fits.joined(separator: ", ")).")
        }
        let browser = try Self.browser(showing: found.space, in: terminal)
        guard browser.arrangeSplit(groupID, as: arrangement, matching: Self.assignment(of: found.space)) else {
            throw Refusal("Arma could not lay out that split as \(arrangement.name).")
        }
        return TerminalOutput(text: "Laid out the split as \(String(localized: arrangement.title)).")
    }

    // MARK: - Actions - Values

    /// The tab `reference` names, when it is in a split.
    @MainActor
    private static func member(_ reference: String, in terminal: BrowserMacTerminal) throws(Refusal) -> FoundTab {
        let found = try terminal.tab(reference)
        guard found.tab.splitGroupID != nil else { throw Refusal("\(found.tab.displayTitle) is in no split.") }
        return found
    }

    /// The store of the front window over `space`, showing it: the split
    /// intents act in the Space a window shows, as they do from its sidebar.
    @MainActor
    private static func browser(showing space: SpaceModel, in terminal: BrowserMacTerminal) throws(Refusal)
        -> BrowserStore
    {
        let space = try terminal.unlocked(space)
        guard let window = terminal.frontWindow(over: space) else {
            throw Refusal("No Arma window is open. Run arma window open.")
        }
        window.browser.selectSpace(space.id)
        return window.browser
    }

    @MainActor
    private static func assignment(of space: SpaceModel) -> BrowserSpaceRuntimeAssignment {
        BrowserSpaceRuntimeAssignment(spaceID: space.id, profileID: space.profileID)
    }
}
