import Foundation

/// One request, from a menu, that the content area pick a Split View card up
/// and carry it on the pointer until a click puts it down: the same move a
/// ⇧⌘-held drag makes, for a hand that is not holding keys.
struct BrowserSplitCardCarryRequest: Equatable, Sendable {
    let tabID: UUID
    /// Advances with every request, so the same card asked for again is a new
    /// request.
    let sequence: Int
}
