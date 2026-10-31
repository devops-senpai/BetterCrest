import Foundation

enum BrowserContentBlockingError: LocalizedError {
    case compilationFailed
    case ruleListUnavailable

    var errorDescription: String? {
        switch self {
        case .compilationFailed:
            "BetterCrest couldn’t compile its native content-blocking rules."
        case .ruleListUnavailable:
            "BetterCrest’s native content-blocking rules are unavailable."
        }
    }
}
