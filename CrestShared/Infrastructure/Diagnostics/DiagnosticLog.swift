import Foundation
import os

/// A category of Crest's unified log. The application layer writes through
/// it, so the stores that report a core's refusal name where the message goes
/// without depending on the logging framework. A message is written public,
/// whole, as it reads.
struct DiagnosticLog: Sendable {
    // MARK: - Static Variables

    static let links = DiagnosticLog(category: "Links")
    /// Which pages each window shows, the engine told to show or hide a page,
    /// Picture in Picture and what memory pressure takes back. Pages are named
    /// by their identities, never their addresses.
    static let pages = DiagnosticLog(category: "Pages")
    static let popups = DiagnosticLog(category: "Popups")
    /// Arma's Servo engine: the library it loaded, and the pages it built,
    /// loaded and closed, named by their identities.
    static let servo = DiagnosticLog(category: "Servo")
    static let shortcuts = DiagnosticLog(category: "Shortcuts")
    static let sitePermissions = DiagnosticLog(category: "SitePermissions")
    /// How the cards of a split tile the content area, the drops and carries
    /// that change it, and the frames the cards settle on. Cards are named by
    /// their tab identities, never their addresses.
    static let splits = DiagnosticLog(category: "Splits")
    static let windows = DiagnosticLog(category: "Windows")

    // MARK: - Variables

    private let logger: Logger

    // MARK: - Initializers

    private init(category: String) {
        logger = Logger(subsystem: "com.senpaimedia.arma", category: category)
    }

    // MARK: - Actions - Describing

    /// How a message names `error`: a rejection by its rule alone, because
    /// what it carries can name an address or a site the log must not keep,
    /// and any other error as it describes itself.
    static func describe(_ error: any Error) -> String {
        guard let rejection = error as? Rejection else { return String(describing: error) }
        return Mirror(reflecting: rejection).children.first?.label ?? String(describing: rejection)
    }

    // MARK: - Actions - Writing

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    func notice(_ message: String) {
        logger.notice("\(message, privacy: .public)")
    }
}
