import AppKit

/// What can be done inside one live page, the same for an agent the person
/// allowed and for the person at their own terminal: read it as an outline or
/// as text, find the element a uid names, ready a field, deliver input, run
/// a script, capture what it shows, and wait for it to settle. Who may act,
/// and on which tab, is decided before a page reaches it.
@MainActor
struct BrowserPageControl {
    // MARK: - Types

    /// Where the element a uid names is in the viewport, in CSS pixels.
    struct Located: Decodable {
        let x: Double
        let y: Double
        let left: Double
        let top: Double
        let width: Double
        let height: Double
        let tag: String

        /// The element's centre, where input aimed at it lands.
        var center: PagePoint { PagePoint(x: x, y: y) }
        /// The element's box, as a capture of it takes.
        var area: CGRect { CGRect(x: left, y: top, width: width, height: height) }
    }

    /// The page as an accessibility outline, each element with its uid.
    struct Outline: Codable {
        let url: String
        let title: String
        let outline: String
        let truncated: Bool
    }

    /// The page's readable text as Markdown.
    struct Text: Codable {
        let url: String
        let title: String
        let text: String
        let truncated: Bool
    }

    /// Why the page did not do what was asked.
    enum Failure: Error {
        /// The page answered nothing in time.
        case timedOut
        /// The page shows a dialog, which holds up its scripts and input.
        case dialog(ScriptDialogAsked)
        /// The script threw `message`.
        case script(String)
        /// The page has no element by that uid now.
        case unknownElement(String)
        /// The page answered something that isn't what was asked for.
        case unreadable
        /// The page's engine did not take the input.
        case inputRefused
        /// The page would not do it, for the reason `message` gives.
        case refused(String)

        /// The failure as an agent hears it.
        var agentFailure: BrowserAgentFailure {
            switch self {
            case .timedOut: .timedOut
            case .dialog(let asked): .dialog(asked)
            case .script(let message): .script(message)
            case .unknownElement(let uid): .unknownElement(uid)
            case .unreadable: .refused("The page answered something Arma can’t read.")
            case .inputRefused: .refused("The page did not take the input.")
            case .refused(let message): .refused(message)
            }
        }

        /// The failure as the terminal prints it for the tab `tab` names.
        func terminalMessage(tab: String) -> String {
            switch self {
            case .timedOut: "The page took too long to answer."
            case .dialog(let asked):
                asked.question.kind == .beforeUnload
                    ? "The page is asking whether to leave it. Answer it with arma page \(tab) dialog."
                    : "The page is showing a dialog: “\(asked.question.message.prefix(500))”. Answer it with arma page \(tab) dialog."
            case .script(let message): "The script threw: \(message)"
            case .unknownElement(let uid):
                "The page has no element \(uid) now. Run arma page \(tab) snapshot for its uids."
            case .unreadable: "The page answered something Arma can’t read."
            case .inputRefused: "The page did not take the input."
            case .refused(let message): message
            }
        }
    }

    // MARK: - Static Variables

    static let scriptTimeout = Duration.seconds(15)
    static let settleTimeout = Duration.seconds(15)
    static let inputTimeout = Duration.seconds(10)
    /// How long after input a page is given for a load the input started to
    /// begin, as a click on a link or a submit button does.
    static let loadGrace = Duration.seconds(1)

    // MARK: - Variables

    let page: BrowserPage

    // MARK: - Actions - Settling

    /// Waits, for up to `settleTimeout`, until the page shows a document
    /// rather than one still on its way. Input given at `input` may start a
    /// load a moment later, which is waited for too.
    func settle(after input: ContinuousClock.Instant? = nil) async {
        if let input {
            while !page.live.isLoading, page.live.pendingURL == nil, ContinuousClock.now < input + Self.loadGrace {
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        let deadline = ContinuousClock.now + Self.settleTimeout
        while page.committedNavigationCount == 0 || page.live.isLoading || page.live.pendingURL != nil,
            ContinuousClock.now < deadline
        {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Whether the page shows a web page, or a blank one or none yet, rather
    /// than one of the browser's own, an extension's or a file.
    var showsWebPage: Bool {
        guard let address = page.live.url else { return true }
        guard address != "about:blank" else { return true }
        let scheme = URL(string: address)?.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }

    // MARK: - Actions - Reading

    /// What `script` answered in Arma's own world of the page.
    func run(_ script: BrowserAgentPageScript) async throws(Failure) -> AgentJSON {
        guard let evaluated = await page.enginePage.evaluate(script.source, in: .agent, timeout: Self.scriptTimeout)
        else { throw page.scriptDialog.map(Failure.dialog) ?? .timedOut }
        if let error = evaluated.error { throw .script(error) }
        guard let json = evaluated.json, let value = try? JSONDecoder().decode(AgentJSON.self, from: Data(json.utf8))
        else { return .null }
        return value
    }

    /// What `script` answered, read as `Value`.
    func read<Value: Decodable>(_ script: BrowserAgentPageScript, as _: Value.Type) async throws(Failure) -> Value {
        guard let value = try? await run(script).decoded(as: Value.self) else { throw .unreadable }
        return value
    }

    /// The page as an outline whose elements carry uids that `locate(_:)`
    /// and input find again.
    func outline() async throws(Failure) -> Outline {
        try await read(BrowserAgentPageScript.snapshot, as: Outline.self)
    }

    /// The page's readable text, within `limit` characters.
    func text(limit: Int) async throws(Failure) -> Text {
        try await read(BrowserAgentPageScript.readText(limit: limit), as: Text.self)
    }

    /// Scrolls the element `uid` names into view and answers where it is.
    func locate(_ uid: String) async throws(Failure) -> Located {
        let answer = try await run(BrowserAgentPageScript.locate(uid))
        guard answer["error"] == nil, let located = try? answer.decoded(as: Located.self) else {
            throw .unknownElement(uid)
        }
        return located
    }

    /// Whether the page shows `text` now, or, without text, whether it has
    /// finished loading.
    func shows(_ text: String?) async -> Bool {
        (try? await run(BrowserAgentPageScript.shows(text))) == .bool(true)
    }

    // MARK: - Actions - Scripts

    /// Runs `source`, the body of an async function, in the page's own world,
    /// and answers its result as JSON.
    func evaluate(_ source: String) async throws(Failure) -> String {
        guard let evaluated = await page.enginePage.evaluate(source, in: .page, timeout: Self.scriptTimeout) else {
            throw page.scriptDialog.map(Failure.dialog) ?? .timedOut
        }
        if let error = evaluated.error { throw .script(error) }
        return evaluated.json ?? "null"
    }

    // MARK: - Actions - Input

    /// Delivers `input` to the page and answers how it went.
    func deliver(_ input: EnginePageInput) async throws(Failure) -> PageInputDelivered {
        guard let delivered = await page.enginePage.deliver(input, timeout: Self.inputTimeout), delivered.delivered
        else {
            // Input that opens a dialog waits on its answer.
            throw page.scriptDialog.map(Failure.dialog) ?? .inputRefused
        }
        return delivered
    }

    // MARK: - Actions - Capture

    /// What the page's view shows now, all of it or `area`, as a PNG.
    func capture(area: CGRect? = nil) async -> Data? {
        await withCheckedContinuation { continuation in
            page.enginePage.capture(area: area) { continuation.resume(returning: $0) }
        }
    }

    /// The whole page, beyond what its view shows, as a PNG.
    func captureFullPage() async -> Data? {
        try? await page.enginePage.export(.png)
    }

    // MARK: - Mutators

    /// Keeps the page rendering at the size of `window`'s content, or a
    /// laptop's, while no window shows it; answers whether it took a size,
    /// after which it lays out again before it is read.
    @discardableResult
    func holdRendering(over window: BrowserMacWindowModel?) async -> Bool {
        let size = window?.pages.presentationWindow?.contentLayoutRect.size ?? CGSize(width: 1280, height: 800)
        guard page.enginePage.holdRendering(true, size: size) else { return false }
        try? await Task.sleep(for: .milliseconds(150))
        return true
    }
}
