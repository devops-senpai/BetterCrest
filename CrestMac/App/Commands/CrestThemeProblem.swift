import Foundation

/// Why a theme could not dress a Space.
enum CrestThemeProblem: Error {
    case unknownStyle(String)
    case unknownPattern(String)
    case unknownTextColor(String)
    case badColor(String)

    /// What the person reads at the terminal.
    var message: String {
        switch self {
        case .unknownStyle(let style):
            "The style '\(style)' is not banner or gradient."
        case .unknownPattern(let pattern):
            "The pattern '\(pattern)' is not one Arma draws. Try \(SpaceBannerPattern.all.map(\.name).joined(separator: ", "))."
        case .unknownTextColor(let mode):
            "The text color '\(mode)' is not automatic, light, dark or system."
        case .badColor(let text):
            "'\(text)' is not a color. Colors are #RRGGBB or #RRGGBBAA, or the word default."
        }
    }
}
