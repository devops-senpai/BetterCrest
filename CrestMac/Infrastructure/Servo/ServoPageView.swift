import AppKit

/// The view one Servo page draws into, which forwards the pointer, wheel and
/// keys it receives to the page. Servo needs the view in a window to draw, so
/// the page starts the first time the view reaches one, at the address it was
/// last asked to load. Command chords stay with the app's menus.
@MainActor
final class ServoPageView: NSView {
    // MARK: - Types

    /// What Servo reports about the page, as its event kinds name it.
    enum Event {
        case title(String)
        case url(String)
        case loadStarted
        case headParsed
        case loadComplete
        /// The page's history, oldest first, and the entry it shows.
        case history(urls: [String], current: Int)
    }

    // MARK: - Variables

    private let library: ServoLibrary
    private let engine: ServoEngine
    private(set) var page: OpaquePointer?
    /// The address the page loads once it starts.
    private var pendingURL: String?
    private var paintScheduled = false
    /// Hears what Servo reports about the page.
    var onEvent: ((Event) -> Void)?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    private var scale: CGFloat { window?.backingScaleFactor ?? 2 }
    private var pixelSize: (width: UInt32, height: UInt32) {
        (UInt32(max(bounds.width * scale, 1)), UInt32(max(bounds.height * scale, 1)))
    }

    // MARK: - Initializers

    init(library: ServoLibrary, engine: ServoEngine) {
        self.library = library
        self.engine = engine
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("ServoPageView is built in code.") }

    isolated deinit {
        close()
    }

    // MARK: - Actions - Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return followVisibility() }
        guard page == nil else {
            library.pageResize(page, pixelSize.width, pixelSize.height)
            followVisibility()
            return
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        let size = pixelSize
        page = library.pageNew(
            engine.handle, context, size.width, size.height, Float(scale), pendingURL ?? "about:blank", context,
            { context in
                guard let context else { return }
                let view = Unmanaged<ServoPageView>.fromOpaque(context).takeUnretainedValue()
                MainActor.assumeIsolated { view.schedulePaint() }
            },
            { context, kind, text in
                guard let context else { return }
                let view = Unmanaged<ServoPageView>.fromOpaque(context).takeUnretainedValue()
                let string = text.map { String(cString: $0) } ?? ""
                MainActor.assumeIsolated { view.receive(kind, string) }
            })
        pendingURL = nil
        if page == nil { DiagnosticLog.servo.error("Servo could not start a page in its view") }
        followVisibility()
    }

    override func viewDidHide() {
        super.viewDidHide()
        followVisibility()
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        followVisibility()
    }

    /// Servo draws the page only while its view shows in a window.
    private func followVisibility() {
        guard let page else { return }
        let shown = window != nil && !isHiddenOrHasHiddenAncestor
        library.pageSetVisible(page, shown ? 1 : 0)
        if shown { schedulePaint() }
    }

    /// Frees the page. Nothing it reports reaches this view afterwards.
    func close() {
        guard let page else { return }
        self.page = nil
        library.pageFree(page)
    }

    // MARK: - Actions - Navigation

    func load(_ url: String) {
        guard let page else {
            pendingURL = url
            return
        }
        library.pageLoad(page, url)
    }

    func traverse(_ steps: Int) {
        guard let page, steps != 0 else { return }
        library.pageTraverse(page, Int32(steps))
    }

    func reload() {
        guard let page else { return }
        library.pageReload(page)
    }

    // MARK: - Actions - Drawing

    private func schedulePaint() {
        guard !paintScheduled else { return }
        paintScheduled = true
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.paintScheduled = false
                guard let page = self.page else { return }
                self.library.pagePaint(page)
            }
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard let page else { return }
        library.pageResize(page, pixelSize.width, pixelSize.height)
        schedulePaint()
    }

    // MARK: - Actions - Events

    private func receive(_ kind: Int32, _ text: String) {
        let event: Event
        switch kind {
        case 0: event = .title(text)
        case 1: event = .url(text)
        case 2: event = .loadStarted
        case 3: event = .loadComplete
        case 4:
            var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            guard !lines.isEmpty, let current = Int(lines.removeFirst()) else { return }
            event = .history(urls: lines, current: current)
        case 5: event = .headParsed
        default: return
        }
        onEvent?(event)
    }

    // MARK: - Actions - Input

    private func point(_ event: NSEvent) -> (x: Float, y: Float) {
        let location = convert(event.locationInWindow, from: nil)
        return (Float(location.x * scale), Float(location.y * scale))
    }

    override func scrollWheel(with event: NSEvent) {
        guard let page else { return }
        let location = point(event)
        let factor: CGFloat = event.hasPreciseScrollingDeltas ? scale : 40 * scale
        library.pageScroll(
            page, Double(event.scrollingDeltaX * factor), Double(event.scrollingDeltaY * factor), location.x,
            location.y)
    }

    private func button(_ event: NSEvent, _ which: Int32, down: Bool) {
        if down { window?.makeFirstResponder(self) }
        guard let page else { return }
        let location = point(event)
        library.pageMouseButton(page, which, down ? 1 : 0, location.x, location.y)
    }

    override func mouseDown(with event: NSEvent) { button(event, 0, down: true) }
    override func mouseUp(with event: NSEvent) { button(event, 0, down: false) }
    override func rightMouseDown(with event: NSEvent) { button(event, 2, down: true) }
    override func rightMouseUp(with event: NSEvent) { button(event, 2, down: false) }
    override func otherMouseDown(with event: NSEvent) { button(event, 1, down: true) }
    override func otherMouseUp(with event: NSEvent) { button(event, 1, down: false) }

    override func mouseMoved(with event: NSEvent) {
        guard let page else { return }
        let location = point(event)
        library.pageMouseMove(page, location.x, location.y)
    }

    override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    override func becomeFirstResponder() -> Bool {
        if let page { library.pageSetFocused(page, 1) }
        return true
    }

    override func resignFirstResponder() -> Bool {
        if let page { library.pageSetFocused(page, 0) }
        return true
    }

    override func keyDown(with event: NSEvent) { key(event, down: true) }
    override func keyUp(with event: NSEvent) { key(event, down: false) }

    /// Command chords belong to the app's menus.
    override func performKeyEquivalent(with event: NSEvent) -> Bool { false }

    private func key(_ event: NSEvent, down: Bool) {
        guard let page, !event.modifierFlags.contains(.command) else {
            if down { super.keyDown(with: event) }
            return
        }
        var modifiers: UInt32 = 0
        if event.modifierFlags.contains(.shift) { modifiers |= 1 }
        if event.modifierFlags.contains(.control) { modifiers |= 2 }
        if event.modifierFlags.contains(.option) { modifiers |= 4 }
        library.pageKey(page, down ? 1 : 0, Self.domKey(event), modifiers)
    }

    /// The DOM `key` value for a macOS key event.
    private static func domKey(_ event: NSEvent) -> String {
        switch event.keyCode {
        case 36, 76: "Enter"
        case 48: "Tab"
        case 51: "Backspace"
        case 117: "Delete"
        case 53: "Escape"
        case 123: "ArrowLeft"
        case 124: "ArrowRight"
        case 125: "ArrowDown"
        case 126: "ArrowUp"
        case 115: "Home"
        case 119: "End"
        case 116: "PageUp"
        case 121: "PageDown"
        default: event.characters ?? ""
        }
    }
}
