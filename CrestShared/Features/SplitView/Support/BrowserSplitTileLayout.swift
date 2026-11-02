import CoreGraphics
import Foundation

/// The geometry of a tiled split: tile and container in, a frame per card and
/// per divider out.
///
/// Pure, so the row, the carry and the tests measure the same thing. Each
/// branch spreads its extent along its axis among its children with
/// `BrowserSplitColumnLayout`, the same arithmetic one row of columns always
/// used, so the shares a window kept for a row still describe the outer branch
/// of a tiled split.
enum BrowserSplitTileLayout {
    // MARK: - Types

    /// One divider: the gap after child `index` of `branchID`, as the handle
    /// is placed and as its drag is measured.
    struct Divider: Identifiable, Equatable {
        let branchID: UUID
        let index: Int
        let axis: SplitAxis
        /// The handle's frame: the gap plus its overhang, across the branch.
        let frame: CGRect
        /// The branch's extent along its axis, which a drag's travel is a
        /// share of.
        let extent: CGFloat
        /// The least the children on each side of the gap can shrink to along
        /// the axis: a card's minimum, or what a nested branch needs for
        /// every card inside it.
        let leadingMinimum: CGFloat
        let trailingMinimum: CGFloat
        /// The sizes of the children on each side of the gap along the axis,
        /// which is what the divider reads out to assistive technologies.
        let leadingSize: CGFloat
        let trailingSize: CGFloat

        var id: String { "\(branchID.uuidString)/\(index)" }
    }

    /// Every frame the tile lays out.
    struct Frames: Equatable {
        var cards: [UUID: CGRect] = [:]
        var placeholder: CGRect?
        var dividers: [Divider] = []
    }

    // MARK: - Actions - Layout

    /// The frames `tile` lays out in `container`, with each branch's children
    /// at `fractions` of it, or equal when the branch has none that fit.
    static func frames(
        of tile: BrowserSplitTile,
        in container: CGRect,
        fractions: (UUID) -> [Double]?,
        gap: CGFloat = BrowserSplitLayoutMetrics.interCardGap,
        minimumWidth: CGFloat = BrowserSplitLayoutMetrics.minimumCardWidth,
        minimumHeight: CGFloat = BrowserSplitLayoutMetrics.minimumCardHeight,
        handleWidth: CGFloat = BrowserSplitLayoutMetrics.resizeHandleHitWidth
    ) -> Frames {
        var frames = Frames()
        place(
            tile, in: container, fractions: fractions, gap: gap, minimumWidth: minimumWidth,
            minimumHeight: minimumHeight, handleWidth: handleWidth, into: &frames)
        return frames
    }

    private static func place(
        _ tile: BrowserSplitTile, in container: CGRect, fractions: (UUID) -> [Double]?, gap: CGFloat,
        minimumWidth: CGFloat, minimumHeight: CGFloat, handleWidth: CGFloat, into frames: inout Frames
    ) {
        switch tile {
        case .card(let id):
            frames.cards[id] = container
        case .placeholder:
            frames.placeholder = container
        case .branch(let id, let axis, let children):
            let extent = axis.isHorizontal ? container.width : container.height
            let minimums = children.map {
                minimumExtent(
                    of: $0, along: axis, gap: gap, minimumWidth: minimumWidth, minimumHeight: minimumHeight)
            }
            let sizes = BrowserSplitColumnLayout.widths(
                containerWidth: extent, fractions: branchFractions(fractions(id), children: children), gap: gap,
                minimums: minimums)
            var offset: CGFloat = 0
            for (index, child) in children.enumerated() {
                let size = index < sizes.count ? sizes[index] : 0
                let frame =
                    axis.isHorizontal
                    ? CGRect(x: container.minX + offset, y: container.minY, width: size, height: container.height)
                    : CGRect(x: container.minX, y: container.minY + offset, width: container.width, height: size)
                place(
                    child, in: frame, fractions: fractions, gap: gap, minimumWidth: minimumWidth,
                    minimumHeight: minimumHeight, handleWidth: handleWidth, into: &frames)
                offset += size
                if index + 1 < children.count {
                    let center = offset + gap / 2
                    let handle =
                        axis.isHorizontal
                        ? CGRect(
                            x: container.minX + center - handleWidth / 2, y: container.minY, width: handleWidth,
                            height: container.height)
                        : CGRect(
                            x: container.minX, y: container.minY + center - handleWidth / 2, width: container.width,
                            height: handleWidth)
                    frames.dividers.append(
                        Divider(
                            branchID: id, index: index, axis: axis, frame: handle, extent: extent,
                            leadingMinimum: minimums[index], trailingMinimum: minimums[index + 1],
                            leadingSize: size, trailingSize: index + 1 < sizes.count ? sizes[index + 1] : 0))
                    offset += gap
                }
            }
        }
    }

    /// The shares a branch spreads its extent by: the ones it kept, when they
    /// still count its children; those with the placeholder's own share
    /// taken out of them when a placeholder has joined; else equal shares.
    static func branchFractions(_ persisted: [Double]?, children: [BrowserSplitTile]) -> [Double] {
        if let index = children.firstIndex(of: .placeholder), let persisted, persisted.count == children.count - 1 {
            return BrowserSplitColumnLayout.fractionsInserting(at: index, into: persisted)
        }
        return BrowserSplitColumnLayout.seedFractions(persisted: persisted, memberCount: children.count)
    }

    /// The least `tile` can shrink to along `axis`: a card's minimum, the
    /// sum of its children's along a branch that runs that way, with the
    /// gaps between them, or the largest of them across one that does not.
    static func minimumExtent(
        of tile: BrowserSplitTile,
        along axis: SplitAxis,
        gap: CGFloat = BrowserSplitLayoutMetrics.interCardGap,
        minimumWidth: CGFloat = BrowserSplitLayoutMetrics.minimumCardWidth,
        minimumHeight: CGFloat = BrowserSplitLayoutMetrics.minimumCardHeight
    ) -> CGFloat {
        switch tile {
        case .card, .placeholder:
            return axis.isHorizontal ? minimumWidth : minimumHeight
        case .branch(_, let branchAxis, let children):
            let extents = children.map {
                minimumExtent(of: $0, along: axis, gap: gap, minimumWidth: minimumWidth, minimumHeight: minimumHeight)
            }
            guard branchAxis == axis else { return extents.max() ?? 0 }
            return extents.reduce(0, +) + max(0, gap) * CGFloat(max(children.count - 1, 0))
        }
    }

    /// Whether `point` is over one of the dividers between `cardFrames`: in
    /// the gap between two cards that face each other across it, with no card
    /// between them, within reach of its middle.
    static func isOverDivider(
        _ point: CGPoint,
        cardFrames: [CGRect],
        hitWidth: CGFloat = BrowserSplitLayoutMetrics.resizeHandleHitWidth
    ) -> Bool {
        let reach = max(0, hitWidth) / 2
        for leading in cardFrames {
            for trailing in cardFrames where leading != trailing {
                guard let (gap, isColumn) = gap(between: leading, and: trailing) else { continue }
                let isHit =
                    isColumn
                    ? abs(point.x - gap.midX) <= reach && (gap.minY...gap.maxY).contains(point.y)
                    : abs(point.y - gap.midY) <= reach && (gap.minX...gap.maxX).contains(point.x)
                // A gap with another card standing in it lies between two
                // cards that are not neighbours.
                let isBlocked = cardFrames.contains { other in
                    other != leading && other != trailing && !other.intersection(gap).isEmpty
                }
                if isHit && !isBlocked { return true }
            }
        }
        return false
    }

    /// The gap from `leading` to `trailing` when the second sits after the
    /// first across a shared span: beside it as a column, or below it as a
    /// row.
    private static func gap(between leading: CGRect, and trailing: CGRect) -> (CGRect, isColumn: Bool)? {
        let rows = (min: max(leading.minY, trailing.minY), max: min(leading.maxY, trailing.maxY))
        if leading.maxX <= trailing.minX, rows.max > rows.min {
            return (
                CGRect(x: leading.maxX, y: rows.min, width: trailing.minX - leading.maxX, height: rows.max - rows.min),
                true
            )
        }
        let columns = (min: max(leading.minX, trailing.minX), max: min(leading.maxX, trailing.maxX))
        if leading.maxY <= trailing.minY, columns.max > columns.min {
            return (
                CGRect(
                    x: columns.min, y: leading.maxY, width: columns.max - columns.min,
                    height: trailing.minY - leading.maxY),
                false
            )
        }
        return nil
    }
}
