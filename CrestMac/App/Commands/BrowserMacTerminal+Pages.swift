import AppKit

/// `arma page`, run in the app through the same page operations agents use,
/// without an agent's session: the person at their own terminal acts as they
/// would in the window. Every action needs Settings › Agents › Command-line
/// page control, and works on web pages only, never Arma's own pages, an
/// extension's or a file.
extension TerminalPageCommand {
    // MARK: - Types

    private typealias Refusal = BrowserMacTerminal.Refusal

    private struct Info: Encodable {
        let tab: UUID
        let space: String
        let url: String?
        let title: String
        let engine: String?
        let loading: Bool
        let zoomPercent: Int
        let dialog: String?
    }

    private struct ConsoleRow: Encodable {
        let sequence: Int64
        let level: String
        let text: String
        let source: String?
        let line: Int
    }

    /// A request as the terminal lists it; what the page's engine doesn't
    /// know, such as the method and status WebKit never reports, is left out.
    private struct RequestRow: Encodable {
        let id: Int64
        let url: String
        let method: String?
        let type: String
        let status: Int?
        let failure: String?
        let durationMilliseconds: Double

        init(_ request: PageNetworkRequest) {
            id = request.sequence
            url = request.url
            method = request.method.isEmpty ? nil : request.method
            type = request.resourceType
            status = request.status == 0 ? nil : request.status
            failure = request.failure
            durationMilliseconds = request.duration
        }
    }

    // MARK: - Static Variables

    static let offMessage = "Turn on Settings › Agents › Command-line page control first."
    private static let untrustedNote =
        "This page’s engine took the input as script events, which some pages ignore."

    /// The engine pages whose console and network Arma keeps for the
    /// terminal, so the first read can say it starts from now.
    @MainActor private static var observedPages: Set<UUID> = []

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) async throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        guard BrowserTerminalPagePreference.isOn else { throw Refusal(Self.offMessage) }
        let found = try terminal.tab(tab)
        let page = try terminal.page(of: found)
        let control = BrowserPageControl(page: page)
        if case .info = action { return info(found, page) }
        guard control.showsWebPage else {
            throw Refusal(
                "That tab shows one of Arma's own pages, an extension's or a file; arma page works on web pages.")
        }
        // A dialog holds up the page's scripts, so it is answered at once.
        if case .dialog(let accept, let text) = action { return try answer(page, accept: accept, text: text) }
        await control.settle()
        if !Self.isShown(found.tab.id, in: terminal) {
            await control.holdRendering(over: terminal.frontWindow(over: found.space))
        }
        do {
            return try await perform(on: control, found)
        } catch {
            throw Refusal(error.terminalMessage(tab: tab))
        }
    }

    @MainActor
    private func perform(on control: BrowserPageControl, _ found: BrowserMacTerminal.FoundTab)
        async throws(BrowserPageControl.Failure) -> TerminalOutput
    {
        switch action {
        case .info, .dialog:
            return TerminalOutput(text: "")
        case .text(let limit):
            let read = try await control.text(limit: limit)
            var text = "\(read.title)\n\(read.url)\n\n\(read.text)"
            if read.truncated { text += "\n\n(Cut short at \(limit) characters; raise --max for more.)" }
            return TerminalOutput(text: text, value: read)
        case .snapshot:
            let outline = try await control.outline()
            var text = "\(outline.title)\n\(outline.url)\n\n\(outline.outline)"
            if outline.truncated { text += "\n\n(The outline was cut short. Scroll and take another.)" }
            return TerminalOutput(text: text, value: outline)
        case .screenshot(let path, let fullPage, let uid):
            return try await screenshot(control, found, path: path, fullPage: fullPage, uid: uid)
        case .eval(let source):
            let json = try await control.evaluate(Self.functionBody(source))
            return TerminalOutput(text: json, json: json)
        case .click(let target, let double):
            let (point, name) = try await aim(at: target, on: control)
            let delivered = try await control.deliver(.click(at: point, button: .primary, count: double ? 2 : 1))
            return Self.done("Clicked \(name).", delivered)
        case .hover(let target):
            let (point, name) = try await aim(at: target, on: control)
            return Self.done("The pointer is over \(name).", try await control.deliver(.hover(at: point)))
        case .type(let text):
            return Self.done("Typed the text.", try await control.deliver(.type(text)))
        case .fill(let uid, let text):
            return try await fill(uid, with: text, on: control)
        case .key(let name, let modifiers):
            guard let key = BrowserAgentKey.named(name) else {
                throw .refused("\(name) is not a key Arma knows; use a KeyboardEvent key such as Enter or a.")
            }
            let held = modifiers.reduce(into: KeyModifiers()) { $0.formUnion($1.keys) }
            return Self.done("Pressed \(name).", try await control.deliver(.press(key.pageKey, modifiers: held)))
        case .scroll(.by(let dx, let dy)):
            guard dx != 0 || dy != 0 else { return TerminalOutput(text: "Nothing to scroll.") }
            let delivered = try await control.deliver(.scroll(at: PagePoint(x: 10, y: 10), deltaX: dx, deltaY: dy))
            return Self.done("Scrolled.", delivered)
        case .scroll(.to(let edge)):
            _ = try await control.run(BrowserAgentPageScript.scrollToEdge(bottom: edge == .bottom))
            return TerminalOutput(text: "Scrolled to the \(edge.rawValue).")
        case .wait(let wait):
            return try await self.wait(for: wait, on: control)
        case .console(let since):
            return console(control.page, since: since)
        case .network(let since):
            return network(control.page, since: since)
        }
    }

    // MARK: - Actions - Reading

    @MainActor
    private func info(_ found: BrowserMacTerminal.FoundTab, _ page: BrowserPage) -> TerminalOutput {
        let info = Info(
            tab: found.tab.id, space: found.space.settings.name, url: page.live.url, title: page.live.title,
            engine: page.corePage.state?.engine.name, loading: page.live.isLoading,
            zoomPercent: Int((page.pageZoom * 100).rounded()), dialog: page.scriptDialog?.question.message)
        var lines = [
            "Tab      \(BrowserMacTerminal.short(info.tab)) in \(info.space)",
            "Title    \(info.title)",
            "Address  \(info.url ?? "-")",
            "Engine   \(info.engine ?? "-")",
            "Loading  \(info.loading ? "yes" : "no")",
            "Zoom     \(info.zoomPercent)%",
        ]
        if let dialog = info.dialog { lines.append("Dialog   \(dialog)") }
        return TerminalOutput(text: lines.joined(separator: "\n"), value: info)
    }

    @MainActor
    private func screenshot(
        _ control: BrowserPageControl, _ found: BrowserMacTerminal.FoundTab, path: String?, fullPage: Bool,
        uid: String?
    ) async throws(BrowserPageControl.Failure) -> TerminalOutput {
        let png: Data?
        if let uid {
            png = await control.capture(area: try await control.locate(uid).area)
        } else if fullPage {
            png = await control.captureFullPage()
        } else {
            png = await control.capture()
        }
        guard let png, !png.isEmpty else { throw .refused("The page showed nothing to capture.") }
        let stamp = Int(Date().timeIntervalSince1970)
        let url =
            path.map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent(
                "arma-\(BrowserMacTerminal.short(found.tab.id))-\(stamp).png")
        do {
            try png.write(to: url, options: .atomic)
        } catch {
            throw .refused("Arma could not write \(url.path): \(error.localizedDescription)")
        }
        return TerminalOutput(text: url.path, value: ["path": url.path])
    }

    @MainActor
    private func console(_ page: BrowserPage, since: Int64) -> TerminalOutput {
        let started = Self.observe(page)
        let log = page.enginePage.console(after: since)
        let rows = log.messages.map {
            ConsoleRow(
                sequence: $0.sequence, level: String(describing: $0.level), text: $0.text, source: $0.source,
                line: $0.line)
        }
        var text =
            rows.isEmpty
            ? "No console messages."
            : BrowserMacTerminal.table(
                ["SEQ", "LEVEL", "SOURCE", "TEXT"],
                rows.map { row in
                    [
                        String(row.sequence), row.level, row.source.map { "\($0):\(row.line)" } ?? "-",
                        String(row.text.prefix(300)),
                    ]
                })
        if started { text += "\nArma keeps this page's console from now on; run it again after the page logs." }
        return TerminalOutput(text: text, value: ["messages": rows])
    }

    @MainActor
    private func network(_ page: BrowserPage, since: Int64) -> TerminalOutput {
        let started = Self.observe(page)
        let rows = page.enginePage.network(after: since).requests.map(RequestRow.init)
        var text =
            rows.isEmpty
            ? "No network requests."
            : BrowserMacTerminal.table(
                ["ID", "METHOD", "STATUS", "TYPE", "URL"],
                rows.map { row in
                    [
                        String(row.id), row.method ?? "-", row.failure ?? row.status.map(String.init) ?? "-",
                        row.type, String(row.url.prefix(200)),
                    ]
                })
        if started { text += "\nArma keeps this page's requests from now on; reload it to see them all." }
        return TerminalOutput(text: text, value: ["requests": rows])
    }

    // MARK: - Actions - Input

    /// The point `target` names, and how the output names it.
    @MainActor
    private func aim(at target: Target, on control: BrowserPageControl) async throws(BrowserPageControl.Failure)
        -> (PagePoint, String)
    {
        switch target {
        case .point(let x, let y):
            return (PagePoint(x: x, y: y), "\(Int(x)),\(Int(y))")
        case .element(let uid):
            let located = try await control.locate(uid)
            return (located.center, "the \(located.tag) \(uid)")
        }
    }

    @MainActor
    private func fill(_ uid: String, with text: String, on control: BrowserPageControl)
        async throws(BrowserPageControl.Failure) -> TerminalOutput
    {
        let prepared = try await control.run(BrowserAgentPageScript.prepareFill(uid, value: text))
        if let refusal = BrowserAgentFillRefusal.named(prepared["error"]?.string) {
            throw .refused(refusal.failure(uid: uid, value: text).message)
        }
        if let chosen = prepared["chosen"]?.string { return TerminalOutput(text: "Chose \(chosen).") }
        guard !text.isEmpty else { return TerminalOutput(text: "Cleared \(uid).") }
        return Self.done("Filled \(uid).", try await control.deliver(.type(text)))
    }

    @MainActor
    private func wait(for wait: Wait, on control: BrowserPageControl) async throws(BrowserPageControl.Failure)
        -> TerminalOutput
    {
        let deadline: ContinuousClock.Instant
        switch wait {
        case .seconds(let seconds):
            try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
            return TerminalOutput(text: "Waited \(seconds.formatted()) seconds.")
        case .text(_, let timeout), .url(_, let timeout):
            deadline = .now + .milliseconds(Int(timeout * 1000))
        }
        repeat {
            switch wait {
            case .text(let text, _):
                if await control.shows(text) { return TerminalOutput(text: "The page shows \(text).") }
            case .url(let part, _):
                if let url = control.page.live.url, url.contains(part) {
                    return TerminalOutput(text: "The tab is at \(url).")
                }
            case .seconds:
                break
            }
            try? await Task.sleep(for: .milliseconds(250))
        } while ContinuousClock.now < deadline
        if case .url(let part, _) = wait { throw .refused("The tab's address didn't come to contain \(part) in time.") }
        throw .refused("The page didn't show that text in time.")
    }

    // MARK: - Actions - Dialogs

    @MainActor
    private func answer(_ page: BrowserPage, accept: Bool, text: String?) throws(Refusal) -> TerminalOutput {
        guard let asked = page.scriptDialog else { throw Refusal("The page shows no dialog.") }
        page.corePage.answer(AnswerScriptDialog(promptID: asked.promptID, accepted: accept, text: text))
        return TerminalOutput(text: accept ? "Accepted the page's dialog." : "Dismissed the page's dialog.")
    }

    // MARK: - Actions - Values

    /// `source` as the body of an async function: one expression, such as
    /// `document.title`, returns its value; statements run as written, and
    /// answer what they return.
    static func functionBody(_ source: String) -> String {
        var expression = source.trimmingCharacters(in: .whitespacesAndNewlines)
        while expression.hasSuffix(";") { expression.removeLast() }
        let statements =
            #"^(const|let|var|if|for|while|do|switch|try|throw|function|class|return)\b|;|\breturn\b"#
        guard expression.range(of: statements, options: .regularExpression) == nil else { return source }
        return "return (\n\(expression)\n);"
    }

    /// Whether a window shows tab `tabID`, which then renders on its own.
    @MainActor
    private static func isShown(_ tabID: UUID, in terminal: BrowserMacTerminal) -> Bool {
        terminal.application.stackedWindowIDs.compactMap { terminal.browser.core.state.windows[$0] }
            .contains { $0.shownTabIDs.contains(tabID) }
    }

    /// Keeps `page`'s console and network from now on; answers whether this
    /// call started it.
    @MainActor
    private static func observe(_ page: BrowserPage) -> Bool {
        page.enginePage.observeActivity(true)
        return observedPages.insert(page.enginePage.id).inserted
    }

    private static func done(_ message: String, _ delivered: PageInputDelivered) -> TerminalOutput {
        TerminalOutput(text: delivered.trusted ? message : "\(message) \(untrustedNote)")
    }
}

extension TerminalPageCommand.Modifier {
    /// The modifier as the engine contract carries it.
    fileprivate var keys: KeyModifiers {
        switch self {
        case .command: .command
        case .shift: .shift
        case .option: .option
        case .control: .control
        }
    }
}
