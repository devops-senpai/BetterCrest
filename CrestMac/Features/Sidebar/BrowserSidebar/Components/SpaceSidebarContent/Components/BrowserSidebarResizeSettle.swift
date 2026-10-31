import AppKit
import SwiftUI

/// Settles the tab list's scroll view after its window changes size.
///
/// The list is laid out lazily and re-measures its rows only when its scroll
/// view scrolls. A window that grows, as when it enters full screen, resizes
/// the clip view without a scroll: the list's height estimate collapses, the
/// rows outside the old range stay unlaid and the newly exposed part is empty
/// until the next wheel event. This view lives inside the scrolling document
/// and, once the window has finished resizing, sends the scroll view a wheel
/// scroll of a few points and back, the same path a trackpad takes, so the list
/// measures again. A list that was at its end before the resize is scrolled
/// back to its end afterwards, in steps, as each step lets more rows measure.
struct BrowserSidebarResizeSettle: NSViewRepresentable {
    // MARK: - Actions - Representable

    func makeNSView(context: Context) -> BrowserSidebarResizeSettleView {
        BrowserSidebarResizeSettleView()
    }

    func updateNSView(_ nsView: BrowserSidebarResizeSettleView, context: Context) {}

    static func dismantleNSView(_ view: BrowserSidebarResizeSettleView, coordinator: ()) {
        view.stopObserving()
    }
}

@MainActor
final class BrowserSidebarResizeSettleView: NSView {
    // MARK: - Static Variables

    /// How far the settle scrolls, in points, before scrolling back.
    private static let nudge: CGFloat = 4

    /// How many steps the return to the end may take while rows measure.
    private static let maximumEndSteps = 40

    /// The time between steps: one frame, so each step sees the rows the last
    /// one let the list measure.
    private static let stepInterval: TimeInterval = 1.0 / 60

    // MARK: - Variables

    private weak var observedWindow: NSWindow?
    private weak var observedClipView: NSClipView?
    private var observers: [NSObjectProtocol] = []
    private var settleIsScheduled = false
    private var isSettling = false
    /// Whether the list showed its end the last time it scrolled on its own.
    private var wasAtEnd = false
    private var lastClipHeight: CGFloat = 0

    // MARK: - Actions - Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window !== observedWindow else { return }
        stopObserving()
        guard let window else { return }
        observedWindow = window
        let center = NotificationCenter.default
        for name in [
            NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification,
            NSWindow.didEndLiveResizeNotification, NSWindow.didResizeNotification,
        ] {
            observers.append(
                center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.scheduleSettle() }
                })
        }
        DispatchQueue.main.async { [weak self] in self?.observeScrolling() }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func stopObserving() {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        observedWindow = nil
        observedClipView = nil
    }

    /// Follows the clip view so a scroll the person makes records whether the
    /// list shows its end. A bounds change that also changes the clip's
    /// height is the resize itself and records nothing.
    private func observeScrolling() {
        guard observedClipView == nil, let scrollView = enclosingScrollView else { return }
        let clipView = scrollView.contentView
        observedClipView = clipView
        lastClipHeight = clipView.bounds.height
        wasAtEnd = Self.showsEnd(scrollView)
        clipView.postsBoundsChangedNotifications = true
        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification, object: clipView, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.clipBoundsDidChange() }
            })
    }

    private func clipBoundsDidChange() {
        guard let scrollView = enclosingScrollView, !isSettling else { return }
        let height = scrollView.contentView.bounds.height
        defer { lastClipHeight = height }
        guard height == lastClipHeight else { return }
        wasAtEnd = Self.showsEnd(scrollView)
    }

    // MARK: - Actions - Settling

    /// Waits for the layout pass the resize starts, and for a live resize to
    /// end, before touching the scroll view.
    private func scheduleSettle() {
        guard !settleIsScheduled else { return }
        settleIsScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            settleIsScheduled = false
            guard let window, !window.inLiveResize else { return }
            settle()
        }
    }

    private func settle() {
        guard let scrollView = enclosingScrollView else { return }
        let returnToEnd = wasAtEnd
        guard let up = Self.wheelEvent(deltaY: Self.nudge, in: scrollView),
            let down = Self.wheelEvent(deltaY: -Self.nudge, in: scrollView)
        else { return }
        isSettling = true
        scrollView.scrollWheel(with: up)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.stepInterval) { [weak self] in
            guard let self, window != nil else { return }
            scrollView.scrollWheel(with: down)
            if returnToEnd {
                stepToEnd(scrollView, remaining: Self.maximumEndSteps)
            } else {
                finishSettling()
            }
        }
    }

    /// Scrolls past the end the list knows now, then again once the rows that
    /// appeared have measured, until neither the end nor the document moves.
    /// The end the list reports right after a resize is the end of its
    /// collapsed estimate, so reaching it proves nothing.
    private func stepToEnd(
        _ scrollView: NSScrollView, remaining: Int, previous: (origin: CGFloat, height: CGFloat)? = nil
    ) {
        guard window != nil, let documentView = scrollView.documentView else { return finishSettling() }
        let current = (origin: scrollView.contentView.bounds.origin.y, height: documentView.bounds.height)
        let settled = previous.map { $0.origin == current.origin && $0.height == current.height } ?? false
        let pastEnd = current.height + scrollView.contentView.bounds.height
        guard remaining > 0, !settled, let event = Self.wheelEvent(deltaY: -pastEnd, in: scrollView) else {
            return finishSettling()
        }
        scrollView.scrollWheel(with: event)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.stepInterval) { [weak self] in
            self?.stepToEnd(scrollView, remaining: remaining - 1, previous: current)
        }
    }

    private func finishSettling() {
        isSettling = false
        if let scrollView = enclosingScrollView {
            wasAtEnd = Self.showsEnd(scrollView)
            lastClipHeight = scrollView.contentView.bounds.height
        }
    }

    /// Whether the clip view shows the document's last point.
    private static func showsEnd(_ scrollView: NSScrollView) -> Bool {
        guard let documentView = scrollView.documentView else { return false }
        return scrollView.contentView.bounds.maxY >= documentView.bounds.maxY - 1
    }

    /// A scroll-wheel event over the scroll view's center, as a trackpad would
    /// send it. Only the list's own scroll view receives it.
    private static func wheelEvent(deltaY: CGFloat, in scrollView: NSScrollView) -> NSEvent? {
        guard let window = scrollView.window,
            let event = CGEvent(
                scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                wheel1: Int32(deltaY), wheel2: 0, wheel3: 0)
        else { return nil }
        let center = scrollView.convert(CGPoint(x: scrollView.bounds.midX, y: scrollView.bounds.midY), to: nil)
        let screenPoint = window.convertPoint(toScreen: center)
        // CGEvent locations have their origin at the top left of the main display.
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        event.location = CGPoint(x: screenPoint.x, y: mainHeight - screenPoint.y)
        return NSEvent(cgEvent: event)
    }
}
