import AppKit

/// `arma site`, run in the app through the core intents Settings › Engines
/// and Settings › Privacy send: website engine rules, which apply in every
/// Space, and one Space's kept site permissions and website data.
extension TerminalSiteCommand {
    // MARK: - Types

    private struct SiteRow: Encodable {
        let site: String
        let engine: String?
        let permissions: [PermissionEntry]
    }

    private struct PermissionEntry: Encodable {
        let permission: String
        let decision: String
        let detail: String?
    }

    private struct SiteClearing: Encodable {
        let site: String
        let space: String
        let engineRules: Int
        let permissions: Int
        let dataRemoved: [String]?
    }

    private typealias Refusal = BrowserMacTerminal.Refusal

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) async throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        switch self {
        case .list(let name):
            return list(in: try terminal.unlocked(try terminal.space(name)), terminal: terminal)
        case .engine(let site, let engine):
            return try choose(engine, for: try Self.origin(site), in: terminal)
        case .permission(let site, let permission, let decision, let name):
            let space = try terminal.unlocked(try terminal.space(name))
            return try answer(
                try Self.permission(permission), for: try Self.origin(site), with: decision, in: space,
                terminal: terminal)
        case .clear(let site, let name, let data):
            let space = try terminal.unlocked(try terminal.space(name))
            return await clear(try Self.origin(site), in: space, removingData: data, terminal: terminal)
        }
    }

    // MARK: - Actions - Listing

    @MainActor
    private func list(in space: SpaceModel, terminal: BrowserMacTerminal) -> TerminalOutput {
        let rules = terminal.browser.core.state.enginePreferences.rules
        let records = terminal.application.pages.permissionCenter.records(in: space.id)
        let sites = Set(rules.map(\.origin) + records.map(\.origin)).sorted { $0.displayName < $1.displayName }
        let rows = sites.map { origin in
            SiteRow(
                site: origin.displayName,
                engine: rules.first { $0.origin == origin }.map { String(localized: $0.engine.title) },
                permissions: records.filter { $0.origin == origin }.map { record in
                    PermissionEntry(
                        permission: BrowserTerminalSetting.kebab(record.permission.name),
                        decision: String(localized: record.decision.title), detail: record.detail)
                })
        }
        guard !rows.isEmpty else {
            return TerminalOutput(
                text: "No website rules, and no kept permissions in \(space.settings.name).",
                value: ["sites": rows])
        }
        let text = BrowserMacTerminal.table(
            ["SITE", "ENGINE", "PERMISSIONS"],
            rows.map { row in
                [
                    row.site, row.engine ?? "default",
                    row.permissions.map { "\($0.permission): \($0.decision)" }.joined(separator: ", "),
                ]
            })
        return TerminalOutput(
            text: text + "\n\nEngine rules apply in every Space; permissions are \(space.settings.name)'s.",
            value: ["sites": rows])
    }

    // MARK: - Actions - Engines

    /// Opens `origin` in `engine` from now on, or in the default engine for
    /// nil. Open pages keep their engine.
    @MainActor
    private func choose(_ engine: TerminalEngine?, for origin: SiteOrigin, in terminal: BrowserMacTerminal)
        throws(Refusal) -> TerminalOutput
    {
        let core = terminal.browser.core
        do {
            guard let engine else {
                try core.send(ForgetEngineRule(origin: origin))
                return TerminalOutput(text: "\(origin.displayName) opens in the default engine.")
            }
            let kind = TerminalTabCommand.kind(of: engine)
            guard core.state.engines?.engines.contains(where: { $0.kind == kind }) == true else {
                throw Refusal("This Arma has no \(engine.rawValue) engine.")
            }
            try core.send(EditEngineRule(previousOrigin: nil, origin: origin, engine: kind))
            return TerminalOutput(text: "\(origin.displayName) opens in \(String(localized: kind.title)).")
        } catch let refusal as Refusal {
            throw refusal
        } catch let rejection as Rejection {
            throw Refusal(rejection.explanation)
        } catch {
            throw Refusal(error.personFacingDescription)
        }
    }

    // MARK: - Actions - Permissions

    /// Allows or blocks `permission` for `origin` in `space` for good, or
    /// forgets the answer so the site asks again.
    @MainActor
    private func answer(
        _ permission: SitePermission, for origin: SiteOrigin, with decision: TerminalSiteDecision,
        in space: SpaceModel, terminal: BrowserMacTerminal
    ) throws(Refusal) -> TerminalOutput {
        let center = terminal.application.pages.permissionCenter
        let name = BrowserTerminalSetting.kebab(permission.name)
        guard let kept = Self.decision(decision) else {
            let records = center.records(in: space.id).filter { $0.origin == origin && $0.permission == permission }
            for record in records { center.reset(recordID: record.id) }
            return TerminalOutput(
                text: records.isEmpty
                    ? "\(origin.displayName) had no \(name) answer in \(space.settings.name)."
                    : "\(origin.displayName) will ask for \(name) again in \(space.settings.name).")
        }
        center.setDecision(kept, for: permission, origin: origin, in: space.id)
        let keeps = center.records(in: space.id).contains {
            $0.origin == origin && $0.permission == permission && $0.decision == kept
        }
        guard keeps else {
            throw Refusal("Arma did not keep that answer for \(origin.displayName).")
        }
        return TerminalOutput(
            text: "\(origin.displayName): \(name) is \(String(localized: kept.title)) in \(space.settings.name).")
    }

    /// The kept answer `decision` names, or nil for one that asks again.
    private static func decision(_ decision: TerminalSiteDecision) -> SitePermissionDecision? {
        switch decision {
        case .allow: .grantPersistently
        case .block: .denyPersistently
        case .ask: nil
        }
    }

    // MARK: - Actions - Clearing

    /// Forgets every engine rule and every permission of `origin`'s host in
    /// `space`, and its website data there when `removingData`.
    @MainActor
    private func clear(
        _ origin: SiteOrigin, in space: SpaceModel, removingData: Bool, terminal: BrowserMacTerminal
    ) async -> TerminalOutput {
        let core = terminal.browser.core
        let rules = core.state.enginePreferences.rules.filter { $0.origin.host == origin.host }
        for rule in rules { _ = try? core.send(ForgetEngineRule(origin: rule.origin)) }
        let center = terminal.application.pages.permissionCenter
        let records = center.records(in: space.id).filter { $0.origin.host == origin.host }
        for record in records { center.reset(recordID: record.id) }
        var lines = [
            "Forgot \(rules.count) engine rule\(rules.count == 1 ? "" : "s") and \(records.count) permission\(records.count == 1 ? "" : "s") of \(origin.host) in \(space.settings.name)."
        ]
        var removed: [String]?
        if removingData {
            let list = BrowserWebsiteDataList(core: core, profileID: space.profileID, ephemeral: false)
            await list.read()
            let sites = (list.sites ?? []).filter { Self.site($0.site, covers: origin.host) }
            removed = sites.map(\.site)
            if sites.isEmpty {
                lines.append("\(origin.host) keeps no website data in \(space.settings.name).")
            } else {
                await list.remove(sites)
                lines.append(
                    list.removalFailed
                        ? "Some of \(origin.host)'s website data couldn’t be removed."
                        : "Removed the cookies, storage and cache of \(sites.map(\.site).joined(separator: ", ")).")
            }
        }
        let result = SiteClearing(
            site: origin.host, space: space.settings.name, engineRules: rules.count, permissions: records.count,
            dataRemoved: removed)
        return TerminalOutput(text: lines.joined(separator: "\n"), value: result)
    }

    /// Whether the stored-data site `site`, a host or the domain the engine
    /// files it under, holds `host`'s data.
    private static func site(_ site: String, covers host: String) -> Bool {
        let site = site.lowercased()
        return site == host || host.hasSuffix("." + site) || site.hasSuffix("." + host)
    }

    // MARK: - Actions - Reading

    /// The origin `text` names: a host means its HTTPS origin.
    private static func origin(_ text: String) throws(Refusal) -> SiteOrigin {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: address), let scheme = url.scheme, WebScheme.named(scheme.lowercased()) != nil,
            url.user == nil, url.password == nil, let host = url.host(), !host.isEmpty,
            !host.contains(where: \.isWhitespace), let origin = SiteOrigin(url: url)
        else { throw Refusal("'\(text)' is not an HTTP or HTTPS website.") }
        return origin
    }

    /// The permission `text` names, by its name in any case, with or without
    /// hyphens.
    private static func permission(_ text: String) throws(Refusal) -> SitePermission {
        let wanted = BrowserTerminalSetting.spelling(text)
        guard let permission = SitePermission.all.first(where: { BrowserTerminalSetting.spelling($0.name) == wanted })
        else {
            let names = SitePermission.all.map { BrowserTerminalSetting.kebab($0.name) }.joined(separator: ", ")
            throw Refusal("A permission is one of \(names), not '\(text)'.")
        }
        return permission
    }
}
