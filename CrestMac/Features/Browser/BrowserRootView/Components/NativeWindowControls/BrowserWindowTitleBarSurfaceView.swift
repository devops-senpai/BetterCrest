import AppKit

/// Empty window chrome that acts as the window's title bar. Like AppKit's own
/// title bar, it answers each mouse-down by its click count: a press drags the
/// window, and the second press of a double-click performs the person's
/// title-bar action instead.
///
/// The surface moves the window from its own drag events. It does not ask the
/// window server to (`NSWindow.performDrag(with:)`), because the window server
/// starts nothing for most trackpad presses and reports nothing about it. This
/// also keeps the surface moving the window where AppKit's title bar does not:
/// below the title bar, and under it while a page holds the window still
/// (`BrowserWindowTitleBarGuard`).
@MainActor
final class BrowserWindowTitleBarSurfaceView: NSView {
    // MARK: - Variables

    /// Where the window stood at the last press on this surface. A second
    /// click is a double-click only while the window has not moved since the
    /// first: releasing a drag and pressing again where it ended also arrives
    /// as click two, and that press is another drag.
    private var frameAtLastPress: NSRect?
    /// Where the window and the pointer were at the press being dragged.
    private var drag: (windowOrigin: NSPoint, pointer: NSPoint)?

    // MARK: - Actions - Mouse

    /// A press on an inactive window moves it at once, as its title bar does.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        // A window in fullscreen has no title bar to stand in for; its own
        // appears in the menu bar's place and moves it.
        guard let window, !window.styleMask.contains(.fullScreen) else { return }
        let frame = window.frame
        defer { frameAtLastPress = frame }
        if event.clickCount == 2, frameAtLastPress == frame {
            BrowserWindowTitleBarAction.current().perform(on: window)
        } else {
            drag = (frame.origin, NSEvent.mouseLocation)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let drag else { return }
        let pointer = NSEvent.mouseLocation
        window.setFrameOrigin(
            NSPoint(
                x: drag.windowOrigin.x + pointer.x - drag.pointer.x,
                y: drag.windowOrigin.y + pointer.y - drag.pointer.y))
    }

    override func mouseUp(with event: NSEvent) {
        drag = nil
    }
}
