import SwiftUI

/// macOS owns real resize pointers, so the divider can say what it does
/// before anyone grabs it: a column resize across a row, a row resize down a
/// stack.
///
/// `pointerStyle(_:)` and `PointerStyle.columnResize` are macOS 15 and later,
/// well under Crest's macOS 26.1 deployment target, so the affordance needs no
/// availability fork of its own — only the platform fork this file is.
struct BrowserPlatformColumnResizePointerModifier: ViewModifier {
    let axis: SplitAxis

    func body(content: Content) -> some View {
        content.pointerStyle(axis.isHorizontal ? .columnResize : .rowResize)
    }
}
