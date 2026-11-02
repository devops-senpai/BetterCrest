import CoreGraphics
import Foundation

/// Where a dragged tab, or a carried card, lands among the cards on show: on
/// one side of a card, outside the whole split on one of its sides, where it
/// takes the full height or width of the content area, or, for a card of the
/// split dropped on the middle of another, in that card's place.
///
/// Resolved from the pointer and the cards' frames alone, so a drop can be
/// exercised without a live drag. The core's `SplitLanding` names the node a
/// landing is beside; `outside` is spelled with the split's outer node only
/// when the drop is sent, since the row that resolves the landing need not know
/// which branch is the outer one.
enum BrowserSplitDropLanding: Equatable, Sendable {
    case beside(UUID, SplitSide)
    case outside(SplitSide)
    /// The card `lifted`, a member of the split, changes places with `with`.
    case swapping(lifted: UUID, with: UUID)

    // MARK: - Static Variables

    /// How far inside the cards' outer edge a pointer still lands outside the
    /// whole split rather than beside the card under it.
    static let outerBand: CGFloat = 36

    /// The share of a card, from each edge, that still lands beside it; the
    /// middle that is left changes places with it when the lift is a member.
    static let swapInset: CGFloat = 0.3

    // MARK: - Actions - Aiming

    /// The landing the pointer aims at among `cardFrames`, the cards on show
    /// in the space the pointer is measured in: outside the split within
    /// `outerBand` of its edge; in the place of the card the pointer is in
    /// the middle of, when `member` names a card of the split that is being
    /// carried; else on the nearest side of the card under the pointer, or of
    /// the nearest card. Nil with no cards to measure.
    ///
    /// The frames are where the cards are on screen, and sides are in reading
    /// order, so `rightToLeft` reads a card's screen-left edge as its trailing
    /// side.
    static func aimed(
        at point: CGPoint,
        cardFrames: [UUID: CGRect],
        member: UUID? = nil,
        outerBand: CGFloat = outerBand,
        rightToLeft: Bool = false
    ) -> BrowserSplitDropLanding? {
        let cards = cardFrames.filter { (id: UUID, frame: CGRect) in !frame.isEmpty && id != member }
        guard !cards.isEmpty else { return nil }
        let bounds = cards.values.reduce(CGRect.null) { $0.union($1) }
        if cards.count > 1 || member != nil, let outside = outerSide(of: point, in: bounds, band: outerBand) {
            return .outside(outside.reading(rightToLeft: rightToLeft))
        }
        let nearest = cards.min { distance(from: point, to: $0.value) < distance(from: point, to: $1.value) }!
        if let member,
            nearest.value.insetBy(dx: nearest.value.width * swapInset, dy: nearest.value.height * swapInset)
                .contains(point)
        {
            return .swapping(lifted: member, with: nearest.key)
        }
        return .beside(nearest.key, nearestSide(of: point, in: nearest.value).reading(rightToLeft: rightToLeft))
    }

    /// The side of `bounds` the point is within `band` of, nearest first, or
    /// nil for a point well inside or well outside them.
    private static func outerSide(of point: CGPoint, in bounds: CGRect, band: CGFloat) -> SplitSide? {
        let reach = bounds.insetBy(dx: -band, dy: -band)
        guard reach.contains(point) else { return nil }
        let distances: [(SplitSide, CGFloat)] = [
            (.leading, point.x - bounds.minX), (.trailing, bounds.maxX - point.x),
            (.above, point.y - bounds.minY), (.below, bounds.maxY - point.y),
        ]
        guard let nearest = distances.min(by: { $0.1 < $1.1 }), nearest.1 <= band else { return nil }
        return nearest.0
    }

    /// The side of `frame` the point is nearest, measured as a share of the
    /// frame on each axis so a wide card is not all left and right.
    static func nearestSide(of point: CGPoint, in frame: CGRect) -> SplitSide {
        let width = max(frame.width, 1)
        let height = max(frame.height, 1)
        let distances: [(SplitSide, CGFloat)] = [
            (.leading, (point.x - frame.minX) / width), (.trailing, (frame.maxX - point.x) / width),
            (.above, (point.y - frame.minY) / height), (.below, (frame.maxY - point.y) / height),
        ]
        return distances.min { $0.1 < $1.1 }!.0
    }

    private static func distance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
        let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
        return dx * dx + dy * dy
    }
}

extension SplitSide {
    /// The side in reading order for a side measured on screen: leading and
    /// trailing trade places right to left.
    fileprivate func reading(rightToLeft: Bool) -> SplitSide {
        guard rightToLeft, axis.isHorizontal else { return self }
        return isAfter ? .leading : .trailing
    }
}
