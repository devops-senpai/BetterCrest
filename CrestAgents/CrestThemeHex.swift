import Foundation

/// How a theme spells a color: `#RRGGBB`, or `#RRGGBBAA` when it is not
/// opaque, each component a byte.
enum CrestThemeHex {
    // MARK: - Types

    /// A color's components, each 0 through 1.
    struct Components: Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }

    // MARK: - Actions - Reading

    /// The components `text` spells, or nil when it is not a hex color. A
    /// leading `#` is optional, and three-digit shorthand doubles each digit.
    static func components(_ text: String) -> Components? {
        var digits = Substring(text.trimmingCharacters(in: .whitespaces))
        if digits.hasPrefix("#") { digits = digits.dropFirst() }
        if digits.count == 3 || digits.count == 4 {
            digits = Substring(digits.flatMap { [$0, $0] })
        }
        guard digits.count == 6 || digits.count == 8, let value = UInt64(digits, radix: 16) else { return nil }
        let hasAlpha = digits.count == 8
        let shift: UInt64 = hasAlpha ? 8 : 0
        func channel(_ offset: UInt64) -> Double { Double((value >> (offset + shift)) & 0xFF) / 255 }
        return Components(
            red: channel(16), green: channel(8), blue: channel(0),
            alpha: hasAlpha ? Double(value & 0xFF) / 255 : 1)
    }

    // MARK: - Actions - Writing

    /// `components` as a theme spells them.
    static func text(_ components: Components) -> String {
        func byte(_ value: Double) -> String {
            String(format: "%02x", Int((min(max(value, 0), 1) * 255).rounded()))
        }
        let opaque = "#" + byte(components.red) + byte(components.green) + byte(components.blue)
        return components.alpha >= 1 ? opaque : opaque + byte(components.alpha)
    }
}
