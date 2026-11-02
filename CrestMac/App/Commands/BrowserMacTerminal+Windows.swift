import AppKit

/// `arma window`, run in the app on the browser windows' own `NSWindow`s.
/// Points are measured from the top left of a screen, as a person reads one.
extension TerminalWindowCommand {
    // MARK: - Types

    private struct WindowRow: Encodable {
        let number: Int
        let id: UUID
        let space: String?
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let screen: Int?
        let minimized: Bool
        let fullScreen: Bool
        let key: Bool
    }

    private typealias Refusal = BrowserMacTerminal.Refusal

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        switch self {
        case .list:
            return list(in: terminal)
        case .focus(let reference):
            let found = try terminal.window(reference)
            if found.window.isMiniaturized { found.window.deminiaturize(nil) }
            terminal.bringForward(found.model)
            return TerminalOutput(text: "Brought the window forward.")
        case .move(let reference, let x, let y, let number):
            let found = try terminal.window(reference)
            let screen = try Self.screen(number, for: found.window)
            found.window.setFrameTopLeftPoint(NSPoint(x: screen.frame.minX + x, y: screen.frame.maxY - y))
            return Self.placed(found.window)
        case .resize(let reference, let width, let height):
            let found = try terminal.window(reference)
            let minimum = found.window.minSize
            guard width >= minimum.width, height >= minimum.height else {
                throw Refusal("The window is at least \(Int(minimum.width)) by \(Int(minimum.height)) points.")
            }
            let frame = found.window.frame
            found.window.setFrame(
                NSRect(x: frame.minX, y: frame.maxY - height, width: width, height: height), display: true)
            return Self.placed(found.window)
        case .tile(let reference, let region):
            let found = try terminal.window(reference)
            let area = (found.window.screen ?? NSScreen.main)?.visibleFrame ?? found.window.frame
            found.window.setFrame(Self.frame(of: region, in: area), display: true, animate: true)
            return Self.placed(found.window)
        case .center(let reference):
            let found = try terminal.window(reference)
            found.window.center()
            return Self.placed(found.window)
        case .minimize(let reference):
            try terminal.window(reference).window.miniaturize(nil)
            return TerminalOutput(text: "Minimized the window.")
        case .restore(let reference):
            let found = try terminal.window(reference)
            if found.window.isMiniaturized { found.window.deminiaturize(nil) }
            if found.window.styleMask.contains(.fullScreen) { found.window.toggleFullScreen(nil) }
            if found.window.isZoomed { found.window.zoom(nil) }
            return Self.placed(found.window)
        case .zoom(let reference):
            let found = try terminal.window(reference)
            found.window.zoom(nil)
            return Self.placed(found.window)
        case .fullScreen(let reference):
            let found = try terminal.window(reference)
            let entering = !found.window.styleMask.contains(.fullScreen)
            found.window.toggleFullScreen(nil)
            return TerminalOutput(text: entering ? "Entering full screen." : "Leaving full screen.")
        case .open(let spaceName):
            var space: SpaceModel?
            if let spaceName { space = try terminal.unlocked(try terminal.space(spaceName)) }
            let request = BrowserMacWindowRequest.normal(sourceWindowID: nil)
            terminal.windows.open(request, activation: .key)
            guard let model = terminal.application.windowCoordinator.existingModel(for: request.id) else {
                throw Refusal("Arma could not open a window.")
            }
            if let space { model.browser.selectSpace(space.id) }
            NSApp.activate(ignoringOtherApps: true)
            return TerminalOutput(text: "Opened a window\(space.map { " over \($0.settings.name)" } ?? "").")
        case .close(let reference):
            try terminal.window(reference).window.performClose(nil)
            return TerminalOutput(text: "Asked the window to close.")
        }
    }

    // MARK: - Actions - Listing

    @MainActor
    private func list(in terminal: BrowserMacTerminal) -> TerminalOutput {
        var rows: [WindowRow] = []
        for (index, model) in terminal.browserWindows.enumerated() {
            guard let window = terminal.windows.window(for: model.id) else { continue }
            let place = Self.place(of: window)
            rows.append(
                WindowRow(
                    number: index + 1, id: model.id, space: model.browser.shownSpace?.settings.name, x: place.x,
                    y: place.y, width: window.frame.width, height: window.frame.height, screen: place.screen,
                    minimized: window.isMiniaturized, fullScreen: window.styleMask.contains(.fullScreen),
                    key: window.isKeyWindow))
        }
        let text =
            rows.isEmpty
            ? "No Arma window is open."
            : BrowserMacTerminal.table(
                ["#", "SPACE", "POSITION", "SIZE", "SCREEN", "STATE"],
                rows.map { row in
                    let state = [
                        row.key ? "key" : nil, row.minimized ? "minimized" : nil, row.fullScreen ? "full screen" : nil,
                    ].compactMap { $0 }.joined(separator: ", ")
                    return [
                        "\(row.number)", row.space ?? "-", "\(Int(row.x)),\(Int(row.y))",
                        "\(Int(row.width))x\(Int(row.height))", row.screen.map(String.init) ?? "-", state,
                    ]
                })
        return TerminalOutput(text: text, value: ["windows": rows])
    }

    // MARK: - Actions - Geometry

    /// Screen `number`, counting the main screen as 1, or `window`'s own.
    @MainActor
    private static func screen(_ number: Int?, for window: NSWindow) throws(Refusal) -> NSScreen {
        guard let number else {
            guard let screen = window.screen ?? NSScreen.main else { throw Refusal("Arma can't find a screen.") }
            return screen
        }
        let screens = NSScreen.screens
        guard screens.indices.contains(number - 1) else {
            throw Refusal("There are \(screens.count) screens; give --screen 1 to \(screens.count).")
        }
        return screens[number - 1]
    }

    /// `window`'s top-left corner from the top left of its screen, and that
    /// screen's number.
    @MainActor
    private static func place(of window: NSWindow) -> (x: Double, y: Double, screen: Int?) {
        let screen = window.screen ?? NSScreen.main
        let number = screen.flatMap { NSScreen.screens.firstIndex(of: $0) }.map { $0 + 1 }
        guard let frame = screen?.frame else { return (window.frame.minX, window.frame.maxY, number) }
        return (window.frame.minX - frame.minX, frame.maxY - window.frame.maxY, number)
    }

    @MainActor
    private static func placed(_ window: NSWindow) -> TerminalOutput {
        let place = place(of: window)
        return TerminalOutput(
            text: "At \(Int(place.x)),\(Int(place.y)), \(Int(window.frame.width))x\(Int(window.frame.height)).")
    }

    /// The part of `area` that `region` names.
    private static func frame(of region: TerminalWindowRegion, in area: NSRect) -> NSRect {
        let halfWidth = area.width / 2
        let halfHeight = area.height / 2
        switch region {
        case .full: return area
        case .left: return NSRect(x: area.minX, y: area.minY, width: halfWidth, height: area.height)
        case .right: return NSRect(x: area.midX, y: area.minY, width: halfWidth, height: area.height)
        case .top: return NSRect(x: area.minX, y: area.midY, width: area.width, height: halfHeight)
        case .bottom: return NSRect(x: area.minX, y: area.minY, width: area.width, height: halfHeight)
        case .topLeft: return NSRect(x: area.minX, y: area.midY, width: halfWidth, height: halfHeight)
        case .topRight: return NSRect(x: area.midX, y: area.midY, width: halfWidth, height: halfHeight)
        case .bottomLeft: return NSRect(x: area.minX, y: area.minY, width: halfWidth, height: halfHeight)
        case .bottomRight: return NSRect(x: area.midX, y: area.minY, width: halfWidth, height: halfHeight)
        }
    }
}
