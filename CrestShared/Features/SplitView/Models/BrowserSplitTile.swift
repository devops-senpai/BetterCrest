import Foundation

/// How a split's cards tile the content area, as the row draws it: the core's
/// `SplitLayoutNode` resolved over the cards on show, with the slot a drag or a
/// carry opens in it.
///
/// The core owns the layout and repairs it against the split's members; this
/// only reads it, and keeps the same reading the core keeps when the two are a
/// frame apart: a card the layout names but the window does not show leaves,
/// a card the window shows but the layout does not place joins the outer row,
/// and a branch left with one child gives way to it. A window presenting one
/// tab is a lone card, and a split without a layout is one row of columns.
indirect enum BrowserSplitTile: Equatable {
    /// One member tab.
    case card(UUID)
    /// The slot a drag in flight would drop a card into.
    case placeholder
    /// Cards or branches laid along one axis: columns across, or rows down.
    case branch(id: UUID, axis: SplitAxis, children: [BrowserSplitTile])

    // MARK: - Static Variables

    /// The branch a preview opens around a card, which exists only until the
    /// drop names it.
    static let previewBranchID = UUID(uuidString: "C0DEC0DE-5711-4000-8000-000000000001")!

    /// A preview branch's name, distinct for each node it opens around and
    /// each run an arrangement draws, so two preview branches in one tile
    /// never share the shares or the dividers keyed by a branch.
    static func previewBranchID(_ seed: UUID?, index: Int = 0) -> UUID {
        guard let seed else {
            var bytes = previewBranchID.uuid
            bytes.15 = UInt8(truncatingIfNeeded: index)
            return UUID(uuid: bytes)
        }
        var bytes = seed.uuid
        bytes.0 ^= 0xC0
        bytes.1 ^= 0xDE
        bytes.15 ^= UInt8(truncatingIfNeeded: index &+ 1)
        return UUID(uuid: bytes)
    }

    // MARK: - Variables

    /// The node's own identity: the card's tab, or the branch's name. A
    /// placeholder has none.
    var nodeID: UUID? {
        switch self {
        case .card(let id): id
        case .branch(let id, _, _): id
        case .placeholder: nil
        }
    }

    /// The cards the tile places, in reading order.
    var cards: [UUID] {
        switch self {
        case .card(let id): [id]
        case .placeholder: []
        case .branch(_, _, let children): children.flatMap(\.cards)
        }
    }

    /// Every branch, the outer one first.
    var branches: [(id: UUID, axis: SplitAxis, count: Int)] {
        guard case .branch(let id, let axis, let children) = self else { return [] }
        return [(id, axis, children.count)] + children.flatMap(\.branches)
    }

    /// The tile as a log names it: `[a | b / c]`, cards by the first eight
    /// characters of their tab identities, `|` between columns and `/`
    /// between rows.
    var summary: String {
        switch self {
        case .card(let id): String(id.uuidString.prefix(8))
        case .placeholder: "_"
        case .branch(_, let axis, let children):
            "[" + children.map(\.summary).joined(separator: axis.isHorizontal ? " | " : " / ") + "]"
        }
    }

    /// Whether the placeholder is somewhere in the tile.
    var holdsPlaceholder: Bool {
        switch self {
        case .placeholder: true
        case .card: false
        case .branch(_, _, let children): children.contains(where: \.holdsPlaceholder)
        }
    }

    // MARK: - Initializers

    /// The tile a split with `layout` draws for `members`, the cards the
    /// window shows in order, named by `groupID`; a lone member is a lone
    /// card.
    static func resolved(layout: SplitLayoutNode?, groupID: UUID?, members: [UUID]) -> BrowserSplitTile {
        let kept = Set(members)
        var seen: Set<UUID> = []
        let pruned = layout.flatMap { Self(node: $0).pruned { kept.contains($0) && seen.insert($0).inserted } }
        let placed = Set(pruned?.cards ?? [])
        var tile = pruned
        for member in members where !placed.contains(member) {
            tile = tile.map { $0.insertingColumn(.card(member), groupID: groupID) } ?? .card(member)
        }
        return tile ?? .card(members.first ?? UUID())
    }

    private init(node: SplitLayoutNode) {
        if let axis = node.axis {
            self = .branch(id: node.id, axis: axis, children: node.children.map(Self.init(node:)))
        } else {
            self = .card(node.id)
        }
    }

    // MARK: - Actions - Reading

    /// Whether the tile has a node with the id, card or branch.
    func holds(_ id: UUID) -> Bool {
        switch self {
        case .card(let own): own == id
        case .placeholder: false
        case .branch(let own, _, let children): own == id || children.contains { $0.holds(id) }
        }
    }

    /// The landing that puts `cardID` back where the tile has it, for a carry
    /// to start from: beside the sibling before it, or beside the one after it
    /// at the head of its branch. Nil for a card the tile does not place
    /// beside anything.
    func restoringLanding(for cardID: UUID) -> BrowserSplitDropLanding? {
        guard case .branch(_, let axis, let children) = self else { return nil }
        if let index = children.firstIndex(of: .card(cardID)) {
            if index > 0, let sibling = children[index - 1].nodeID {
                return .beside(sibling, axis.isHorizontal ? .trailing : .below)
            }
            if index + 1 < children.count, let sibling = children[index + 1].nodeID {
                return .beside(sibling, axis.isHorizontal ? .leading : .above)
            }
            return nil
        }
        return children.lazy.compactMap { $0.restoringLanding(for: cardID) }.first
    }

    // MARK: - Actions - Editing

    /// The tile with `slot` landed as `landing` says, the way the core lands
    /// a card: beside the node in a branch that already runs that way, or in
    /// a preview branch that takes the node's place, normalized as the core
    /// normalizes the layout the drop makes.
    func inserting(_ slot: BrowserSplitTile, at landing: BrowserSplitDropLanding) -> BrowserSplitTile {
        switch landing {
        case .outside(let side):
            return wrapped(with: slot, side: side).normalized
        case .beside(let nodeID, let side):
            let tile = holds(nodeID) ? inserting(slot, beside: nodeID, side: side) : wrapped(with: slot, side: side)
            return tile.normalized
        case .swapping:
            return self
        }
    }

    /// The tile without the card, every branch it empties closed; nil for a
    /// tile that held nothing else.
    func removing(_ cardID: UUID) -> BrowserSplitTile? {
        pruned { $0 != cardID }
    }

    /// The tile with the two cards' places exchanged.
    func swapping(_ first: UUID, _ second: UUID) -> BrowserSplitTile {
        switch self {
        case .card(first): .card(second)
        case .card(second): .card(first)
        case .card, .placeholder: self
        case .branch(let id, let axis, let children):
            .branch(id: id, axis: axis, children: children.map { $0.swapping(first, second) })
        }
    }

    /// Whether the tile places the same cards the same way as `other`,
    /// whatever its branches are named.
    func hasShape(of other: BrowserSplitTile) -> Bool {
        switch (self, other) {
        case (.card(let own), .card(let theirs)): own == theirs
        case (.placeholder, .placeholder): true
        case (.branch(_, let axis, let children), .branch(_, let otherAxis, let otherChildren)):
            axis == otherAxis && children.count == otherChildren.count
                && zip(children, otherChildren).allSatisfy { $0.hasShape(of: $1) }
        default: false
        }
    }

    /// The tile `arrangement` gives `members`, the cards in order, the way the
    /// core lays it out: runs along its axis, each run of more than one card
    /// stacked the other way.
    static func arranged(_ arrangement: SplitArrangement, members: [UUID]) -> BrowserSplitTile {
        let inner: SplitAxis = arrangement.axis == .horizontal ? .vertical : .horizontal
        var next = 0
        var children: [BrowserSplitTile] = []
        for size in arrangement.groups {
            let run = members.dropFirst(next).prefix(size).map(BrowserSplitTile.card)
            next += size
            children.append(
                run.count == 1
                    ? run[0]
                    : .branch(id: previewBranchID(nil, index: children.count + 1), axis: inner, children: Array(run)))
        }
        return .branch(id: previewBranchID, axis: arrangement.axis, children: children)
    }

    private func wrapped(with slot: BrowserSplitTile, side: SplitSide) -> BrowserSplitTile {
        .branch(
            id: Self.previewBranchID(nodeID), axis: side.axis, children: side.isAfter ? [self, slot] : [slot, self])
    }

    private func inserting(_ slot: BrowserSplitTile, beside nodeID: UUID, side: SplitSide) -> BrowserSplitTile {
        if self.nodeID == nodeID { return wrapped(with: slot, side: side) }
        guard case .branch(let id, let axis, var children) = self else { return self }
        if let index = children.firstIndex(where: { $0.nodeID == nodeID }) {
            if axis == side.axis {
                children.insert(slot, at: side.isAfter ? index + 1 : index)
            } else {
                children[index] = children[index].wrapped(with: slot, side: side)
            }
        } else {
            children = children.map { $0.inserting(slot, beside: nodeID, side: side) }
        }
        return .branch(id: id, axis: axis, children: children)
    }

    private func insertingColumn(_ slot: BrowserSplitTile, groupID: UUID?) -> BrowserSplitTile {
        if case .branch(let id, let axis, let children) = self, axis == .horizontal {
            return .branch(id: id, axis: axis, children: children + [slot])
        }
        return .branch(id: groupID ?? Self.previewBranchID, axis: .horizontal, children: [self, slot])
    }

    /// The tile the way the core keeps a layout: a branch inside one that runs
    /// the same way gives its children to it, and a branch of one child gives
    /// way to that child. A preview opened outside a row is a column of that
    /// row, as the drop will make it.
    var normalized: BrowserSplitTile {
        pruned { _ in true } ?? self
    }

    /// The tile with only the cards `keeps` answers for, normalized the way
    /// the core normalizes a layout; nil when none remain.
    private func pruned(_ keeps: (UUID) -> Bool) -> BrowserSplitTile? {
        switch self {
        case .card(let id):
            return keeps(id) ? self : nil
        case .placeholder:
            return self
        case .branch(let id, let axis, let children):
            var kept: [BrowserSplitTile] = []
            for child in children {
                guard let pruned = child.pruned(keeps) else { continue }
                if case .branch(_, let childAxis, let grandchildren) = pruned, childAxis == axis {
                    kept.append(contentsOf: grandchildren)
                } else {
                    kept.append(pruned)
                }
            }
            switch kept.count {
            case 0: return nil
            case 1: return kept[0]
            default: return .branch(id: id, axis: axis, children: kept)
            }
        }
    }
}
