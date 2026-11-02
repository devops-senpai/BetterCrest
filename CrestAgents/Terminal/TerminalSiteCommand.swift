import Foundation

/// `arma site`: the rules Arma keeps per website, which engine opens it and
/// what it may ask for, and its stored data.
///
/// A site is named by its host, such as `example.com`, or by an address,
/// such as `https://example.com:8443`; a bare host means its HTTPS origin.
/// Engine rules apply in every Space; permissions belong to one Space, chosen
/// with `--space` or the front window's.
enum TerminalSiteCommand: Codable, Sendable {
    /// Every site with an engine rule or a kept permission in `space`.
    case list(space: String?)
    /// Opens `site` in `engine`, or the default engine for nil.
    case engine(site: String, engine: TerminalEngine?)
    /// Answers `permission` for `site` in `space` with `decision`.
    case permission(site: String, permission: String, decision: TerminalSiteDecision, space: String?)
    /// Forgets `site`'s engine rule and its permissions in `space`, and
    /// removes what it stores in that Space when `data`.
    case clear(site: String, space: String?, data: Bool)
}

/// How a site's permission is answered, as Settings › Privacy offers it.
enum TerminalSiteDecision: String, Codable, Sendable, CaseIterable {
    case allow
    case block
    case ask
}
