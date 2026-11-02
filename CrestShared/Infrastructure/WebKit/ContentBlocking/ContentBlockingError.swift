import Foundation

enum BrowserContentBlockingError: LocalizedError {
    case compilationFailed
    case ruleListUnavailable

    var errorDescription: String? {
        switch self {
        case .compilationFailed:
            "Arma couldn’t compile its native content-blocking rules."
        case .ruleListUnavailable:
            "Arma’s native content-blocking rules are unavailable."
        }
    }
}
