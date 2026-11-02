import Foundation

/// One tile of the split view.
///
/// A drag in flight adds a tile rather than decorating the view with one. The
/// slot the dragged tab would land in is laid out, wrapped, and measured exactly
/// as a member's card is: same surface, same gap, same share of its branch.
/// Only its interior differs, and only until the drop replaces it with the card
/// it was standing in for.
///
/// Identity is what makes that replacement read as a replacement. A member keeps
/// its `UUID` for the life of the row, so the cards a drag never touched are
/// never remounted — which matters more here than in an ordinary list, because a
/// remounted card would hand a live `WKWebView` to a second superview. The
/// placeholder and extension panel have distinct identities without tabs:
/// on release the placeholder leaves and the joining member arrives in the same
/// position at the same width, and every other column holds still.
enum BrowserSplitColumnSlot<Member: Identifiable>: Identifiable where Member.ID == UUID {
    case member(Member)
    /// The column a drag in flight would drop into.
    case placeholder
    case panel

    var id: BrowserSplitColumnSlotID {
        switch self {
        case .member(let tab): .member(tab.id)
        case .placeholder: .placeholder
        case .panel: .panel
        }
    }

    var member: Member? {
        switch self {
        case .member(let tab): tab
        case .placeholder, .panel: nil
        }
    }

    /// The slots the tiles of `members` lay out, with the drop tile when a
    /// drag has resolved a landing. Where each one sits is the tile's answer.
    static func slots(
        members: [Member],
        includesPlaceholder: Bool,
        includesPanel: Bool = false
    ) -> [BrowserSplitColumnSlot] {
        var slots = members.map(BrowserSplitColumnSlot.member)
        if includesPlaceholder { slots.append(.placeholder) }
        if includesPanel { slots.append(.panel) }
        return slots
    }
}

enum BrowserSplitColumnSlotID: Hashable {
    case member(UUID)
    case placeholder
    case panel
}
