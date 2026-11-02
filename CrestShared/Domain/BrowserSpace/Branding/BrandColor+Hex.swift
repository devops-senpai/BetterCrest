import Foundation

/// A color as people type it: `#RRGGBB`, or `#RGB` shorthand.
extension BrandColor {
    // MARK: - Initializers

    /// The color `text` spells, with or without its `#`, or nil.
    init?(hex text: String) {
        var digits = Substring(text.trimmingCharacters(in: .whitespaces))
        if digits.hasPrefix("#") { digits = digits.dropFirst() }
        if digits.count == 3 { digits = Substring(digits.flatMap { [$0, $0] }) }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255, alpha: 1)
    }

    // MARK: - Variables

    /// The color as `#RRGGBB`.
    var hexText: String {
        func byte(_ value: Double) -> String { String(format: "%02X", Int((min(max(value, 0), 1) * 255).rounded())) }
        return "#" + byte(red) + byte(green) + byte(blue)
    }
}
