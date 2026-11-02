import CoreGraphics

/// The whole of Crest's column arithmetic: fractions in, widths out.
///
/// Every function here is pure and deterministic, which is what lets one set of
/// numbers serve every branch of `BrowserSplitTileLayout`, across or down, and
/// the unit tests without a view in the loop. Two invariants hold across all of them:
///
/// - Widths are never negative.
/// - Widths sum to the container's available width — the container minus the
///   gaps between columns. When the container cannot hold the columns'
///   minimums, they share it in proportion to those minimums, so no card
///   spills over its neighbour. Layout never dissolves a split to make it fit.
///
/// Fractions are shares of that available width and always sum to one.
enum BrowserSplitColumnLayout {
    /// The fractions of a split nobody has resized yet: equal columns.
    static func equalFractions(count: Int) -> [Double] {
        guard count > 0 else { return [] }
        return Array(repeating: 1 / Double(count), count: count)
    }

    /// Which fractions a split starts a layout pass with.
    ///
    /// Two callers need the same answer and must not disagree: the window
    /// model, seeding its width transaction when the presented group changes,
    /// and the columns view, which lays out every frame and cannot index a
    /// fraction list that is one member behind the group it is drawing. A
    /// stored list whose length no longer matches the group is not repaired
    /// here — a split of three has no honest reading of two fractions — so it
    /// is discarded for equal columns, the same starting point a brand-new
    /// group gets.
    static func seedFractions(persisted: [Double]?, memberCount: Int) -> [Double] {
        guard memberCount > 0 else { return [] }
        guard let persisted, persisted.count == memberCount else {
            return equalFractions(count: memberCount)
        }
        return normalizedFractions(persisted)
    }

    /// The caller's fractions as shares summing to one.
    ///
    /// A list containing anything that cannot be a share — a non-finite value,
    /// zero, a negative — falls back to equal columns in full rather than
    /// salvaging the readable entries. Partially trusting a malformed list
    /// produces layouts nobody asked for; equal columns are at least the
    /// documented starting point.
    static func normalizedFractions(_ fractions: [Double]) -> [Double] {
        guard !fractions.isEmpty else { return [] }
        guard fractions.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            return equalFractions(count: fractions.count)
        }
        let total = fractions.reduce(0, +)
        guard total.isFinite, total > 0 else {
            return equalFractions(count: fractions.count)
        }
        return fractions.map { $0 / total }
    }

    /// The width of each card in a container of this width.
    ///
    /// Fractions are normalized, distributed across the width left after the
    /// gaps, floored at `minimum`, and the overflow that flooring creates is
    /// taken back from the cards still above the floor in proportion to their
    /// shares. A container that cannot seat every card at `minimum` gives
    /// each card an equal share of what it has.
    static func widths(
        containerWidth: CGFloat,
        fractions: [Double],
        gap: CGFloat = BrowserSplitLayoutMetrics.interCardGap,
        minimum: CGFloat = BrowserSplitLayoutMetrics.minimumCardWidth
    ) -> [CGFloat] {
        widths(
            containerWidth: containerWidth, fractions: fractions, gap: gap,
            minimums: Array(repeating: minimum, count: fractions.count))
    }

    /// The width of each child of a branch, each floored at its own minimum:
    /// a child that is itself a branch needs room for every card inside it.
    ///
    /// A container too small for the minimums shares what it has in
    /// proportion to them, so a child never spills over its neighbour.
    static func widths(
        containerWidth: CGFloat,
        fractions: [Double],
        gap: CGFloat,
        minimums: [CGFloat]
    ) -> [CGFloat] {
        guard !fractions.isEmpty else { return [] }
        let floors = fractions.indices.map { max(0, $0 < minimums.count ? minimums[$0] : 0) }
        let available = availableWidth(
            containerWidth: containerWidth,
            columnCount: fractions.count,
            gap: gap
        )
        let floorTotal = floors.reduce(0, +)
        guard available > floorTotal else {
            guard available > 0, floorTotal > 0 else {
                return Array(repeating: max(available, 0) / CGFloat(fractions.count), count: fractions.count)
            }
            return floors.map { $0 * available / floorTotal }
        }

        let shares = normalizedFractions(fractions)
        var widths = [CGFloat](repeating: 0, count: fractions.count)
        var flexible = Array(widths.indices)
        var remaining = available

        // `available` exceeds every card's floor combined, so each pass leaves
        // at least one card above the floor and the loop always terminates.
        while !flexible.isEmpty {
            let shareTotal = flexible.reduce(0.0) { $0 + shares[$1] }
            guard shareTotal > 0 else {
                let equalWidth = remaining / CGFloat(flexible.count)
                for index in flexible {
                    widths[index] = equalWidth
                }
                break
            }
            for index in flexible {
                widths[index] = remaining * CGFloat(shares[index] / shareTotal)
            }
            let flooring = flexible.filter { widths[$0] < floors[$0] }
            guard !flooring.isEmpty else { break }
            for index in flooring {
                widths[index] = floors[index]
                remaining -= floors[index]
            }
            flexible.removeAll(where: flooring.contains)
        }

        return distributingResidual(widths, across: available)
    }

    /// The fractions a divider drag lands on.
    ///
    /// `dividerIndex` names the gap after that card, `delta` is the pointer's
    /// travel from where the drag began, and only the pair around the divider
    /// moves: the cards beyond it keep the widths they had, which is what makes
    /// a drag feel local. The pair's own boundary stops as soon as either side
    /// reaches its minimum — `pairMinimums` when the two are branches of
    /// different sizes, else `minimum` — and a pair with no room to give
    /// returns unchanged fractions.
    static func fractionsAfterResize(
        fractions: [Double],
        dividerIndex: Int,
        delta: CGFloat,
        containerWidth: CGFloat,
        gap: CGFloat = BrowserSplitLayoutMetrics.interCardGap,
        minimum: CGFloat = BrowserSplitLayoutMetrics.minimumCardWidth,
        pairMinimums: (leading: CGFloat, trailing: CGFloat)? = nil
    ) -> [Double] {
        var shares = normalizedFractions(fractions)
        guard shares.count > 1, dividerIndex >= 0, dividerIndex < shares.count - 1 else {
            return shares
        }
        let available = availableWidth(
            containerWidth: containerWidth,
            columnCount: shares.count,
            gap: gap
        )
        guard available > 0 else { return shares }

        let leadingFloor = max(0, pairMinimums?.leading ?? minimum)
        let trailingFloor = max(0, pairMinimums?.trailing ?? minimum)
        let pairWidth = available * CGFloat(shares[dividerIndex] + shares[dividerIndex + 1])
        guard pairWidth >= leadingFloor + trailingFloor else { return shares }

        let leadingWidth = available * CGFloat(shares[dividerIndex])
        let resolvedWidth = min(max(leadingWidth + delta, leadingFloor), pairWidth - trailingFloor)
        shares[dividerIndex] = Double(resolvedWidth / available)
        shares[dividerIndex + 1] = Double((pairWidth - resolvedWidth) / available)
        return shares
    }

    /// The fractions after a card joins at `index`.
    ///
    /// The newcomer takes an equal share of the wider split it creates and the
    /// existing cards give it up in proportion, so a resized pair stays as
    /// lopsided as its owner left it.
    ///
    /// A drag in flight lays its drop placeholder out with these same fractions.
    /// The placeholder is not a hint about where a card would go, it is that
    /// card's own column drawn a moment early — half the row beside a lone card,
    /// a third among two, a quarter among three — so the slot under the pointer
    /// is already the width the card that lands in it will have.
    static func fractionsInserting(at index: Int, into fractions: [Double]) -> [Double] {
        guard !fractions.isEmpty else { return [1] }
        let shares = normalizedFractions(fractions)
        let newcomerShare = 1 / Double(shares.count + 1)
        var result = shares.map { $0 * (1 - newcomerShare) }
        result.insert(newcomerShare, at: min(max(index, 0), result.count))
        return result
    }

    /// The width columns share once the gaps between them are paid for.
    private static func availableWidth(
        containerWidth: CGFloat,
        columnCount: Int,
        gap: CGFloat
    ) -> CGFloat {
        guard columnCount > 1 else { return containerWidth }
        return containerWidth - max(0, gap) * CGFloat(columnCount - 1)
    }

    /// Absorbs division noise into the widest card so the widths sum to the
    /// available width exactly. The widest card is by definition further above
    /// the floor than the correction, so flooring survives.
    private static func distributingResidual(
        _ widths: [CGFloat],
        across total: CGFloat
    ) -> [CGFloat] {
        var widths = widths
        let residual = total - widths.reduce(0, +)
        guard residual != 0,
            let widest = widths.indices.max(by: { widths[$0] < widths[$1] })
        else { return widths }
        widths[widest] += residual
        return widths
    }
}
