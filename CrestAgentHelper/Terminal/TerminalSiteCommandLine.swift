import Foundation

/// `arma site`.
enum TerminalSiteCommandLine: TerminalSection {
    static let name = "site"
    static let summary = "List and change per-website engine rules and permissions, or clear a site"
    static let switches: Set<String> = ["data"]
    static let usage = """
        usage: arma site <action> [options]

          list [--space <s>]       sites with an engine rule or a kept permission
          engine <site> chromium|webkit|servo|default
                                   open <site> in an engine; default removes the rule
          permission <site> <permission> allow|block|ask [--space <s>]
                                   answer a permission for <site>; ask forgets the answer
          clear <site> [--space <s>] [--data]
                                   forget <site>'s engine rule and its permissions;
                                   --data also removes its cookies, storage and cache

        A site is a host, such as example.com, or an address, such as
        https://example.com:8443. Engine rules apply in every Space; permissions and
        data belong to one Space: --space names it, or the front window's is used.

        Permissions: camera, microphone, camera-and-microphone, location,
        notifications, popups, automatic-downloads, external-applications,
        screen-sharing.

        """

    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        let space = arguments.option("space")
        switch action {
        case "list", "ls":
            return .site(.list(space: space))
        case "engine":
            let site = try arguments.take("a site")
            let text = try arguments.take("an engine")
            guard text.lowercased() != "default" else { return .site(.engine(site: site, engine: nil)) }
            let engine = try TerminalArguments.choice(text, as: TerminalEngine.self, for: "The engine")
            return .site(.engine(site: site, engine: engine))
        case "permission":
            let site = try arguments.take("a site")
            let permission = try arguments.take("a permission")
            let decision = try TerminalArguments.choice(
                try arguments.take("allow, block or ask"), as: TerminalSiteDecision.self, for: "The answer")
            return .site(.permission(site: site, permission: permission, decision: decision, space: space))
        case "clear":
            return .site(.clear(site: try arguments.take("a site"), space: space, data: arguments.has("data")))
        default:
            throw TerminalArguments.Problem(message: "arma site has no action '\(action)'.")
        }
    }
}
