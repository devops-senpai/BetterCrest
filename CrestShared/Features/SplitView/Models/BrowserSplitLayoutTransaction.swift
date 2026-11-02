import CoreGraphics
import Foundation

/// Keeps divider updates local until the interaction commits: the shares of
/// every branch of the split on show, by branch, with one drag in flight.
struct BrowserSplitLayoutTransaction: Equatable {
    private(set) var fractions: [UUID: [Double]]
    private(set) var persistedFractions: [UUID: [Double]]

    /// Total drag translation is measured from these fractions, never the previous frame.
    private var dragBaseline: [Double]?
    private var dragBranchID: UUID?

    /// Ignores subpixel fraction changes when deciding whether to persist.
    private static let minimumMeaningfulChange = 0.0005

    init(persistedFractions: [UUID: [Double]] = [:]) {
        let normalized = persistedFractions.mapValues(BrowserSplitColumnLayout.normalizedFractions)
        fractions = normalized
        self.persistedFractions = normalized
    }

    /// The shares one branch spreads its extent by, or nil for a branch nobody
    /// resized, which the layout spreads equally.
    func fractions(for branchID: UUID) -> [Double]? {
        fractions[branchID]
    }

    /// Replacing the split on show cancels the drag and adopts its saved layout.
    mutating func begin(fractions: [UUID: [Double]]) {
        let normalized = fractions.mapValues(BrowserSplitColumnLayout.normalizedFractions)
        self.fractions = normalized
        persistedFractions = normalized
        dragBaseline = nil
        dragBranchID = nil
    }

    /// Applies total drag travel to the baseline captured on the first update:
    /// the gap after `dividerIndex` of `branchID`, whose children spread its
    /// `extent` along `axis`, `gap` apart. `pairMinimums` are the least the
    /// two children around the gap can shrink to, which for a nested branch
    /// is more than one card's minimum.
    mutating func resize(
        branchID: UUID, childCount: Int, axis: SplitAxis, dividerIndex: Int, delta: CGFloat, extent: CGFloat,
        gap: CGFloat = BrowserSplitLayoutMetrics.interCardGap,
        pairMinimums: (leading: CGFloat, trailing: CGFloat)? = nil
    ) {
        if dragBranchID != branchID { dragBaseline = nil }
        let baseline =
            dragBaseline
            ?? BrowserSplitColumnLayout.seedFractions(persisted: fractions[branchID], memberCount: childCount)
        dragBaseline = baseline
        dragBranchID = branchID
        fractions[branchID] = BrowserSplitColumnLayout.fractionsAfterResize(
            fractions: baseline,
            dividerIndex: dividerIndex,
            delta: delta,
            containerWidth: extent,
            gap: gap,
            minimum: axis.isHorizontal
                ? BrowserSplitLayoutMetrics.minimumCardWidth : BrowserSplitLayoutMetrics.minimumCardHeight,
            pairMinimums: pairMinimums
        )
    }

    /// Returns the branch whose shares changed, once per completed interaction.
    mutating func commit() -> (branchID: UUID, fractions: [Double])? {
        defer {
            dragBaseline = nil
            dragBranchID = nil
        }
        guard let branchID = dragBranchID, let changed = fractions[branchID],
            !Self.matches(changed, persistedFractions[branchID])
        else { return nil }
        persistedFractions[branchID] = changed
        return (branchID, changed)
    }

    private static func matches(_ fractions: [Double], _ other: [Double]?) -> Bool {
        guard let other, fractions.count == other.count else { return false }
        return zip(fractions, other).allSatisfy { pair in
            abs(pair.0 - pair.1) < minimumMeaningfulChange
        }
    }
}
