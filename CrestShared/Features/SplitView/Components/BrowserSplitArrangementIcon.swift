import SwiftUI

#if canImport(AppKit)
    import AppKit
#else
    import UIKit
#endif

/// The picture of one split arrangement, drawn from its runs: a card for each
/// tab, laid out the way the arrangement lays them. Drawn as a template image,
/// so a menu tints it like the symbols beside it, and drawn once per
/// arrangement and kept.
@MainActor
enum BrowserSplitArrangementIcon {
    // MARK: - Static Variables

    private static let size = CGSize(width: 18, height: 13)
    private static let gap: CGFloat = 1.5
    private static let cornerRadius: CGFloat = 1.5
    private static var cache: [String: Image] = [:]

    // MARK: - Actions - Drawing

    /// The arrangement's picture, as a template image that takes the menu's
    /// text color.
    static func image(for arrangement: SplitArrangement) -> Image {
        if let cached = cache[arrangement.name] { return cached }
        let frames = cardFrames(for: arrangement)
        #if canImport(AppKit)
            let picture = NSImage(size: size, flipped: true) { _ in
                NSColor.black.setFill()
                for frame in frames {
                    NSBezierPath(roundedRect: frame, xRadius: cornerRadius, yRadius: cornerRadius).fill()
                }
                return true
            }
            picture.isTemplate = true
            let image = Image(nsImage: picture)
        #else
            let picture = UIGraphicsImageRenderer(size: size).image { _ in
                UIColor.black.setFill()
                for frame in frames {
                    UIBezierPath(roundedRect: frame, cornerRadius: cornerRadius).fill()
                }
            }
            let image = Image(uiImage: picture.withRenderingMode(.alwaysTemplate))
        #endif
        cache[arrangement.name] = image
        return image
    }

    /// Where each card sits in the picture, from the arrangement's own layout
    /// over as many stand-in cards as it holds.
    private static func cardFrames(for arrangement: SplitArrangement) -> [CGRect] {
        let tile = BrowserSplitTile.arranged(
            arrangement, members: (0..<arrangement.memberCount).map { _ in UUID() })
        return Array(
            BrowserSplitTileLayout.frames(
                of: tile, in: CGRect(origin: .zero, size: size), fractions: { _ in nil }, gap: gap, minimumWidth: 0,
                minimumHeight: 0, handleWidth: 0
            ).cards.values)
    }
}
