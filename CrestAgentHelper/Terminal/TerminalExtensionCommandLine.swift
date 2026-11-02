import Foundation

/// `arma extension`.
enum TerminalExtensionCommandLine: TerminalSection {
    // MARK: - Static Variables

    static let name = "extension"
    static let summary = "List, install, remove, turn on and off Chromium and Servo extensions"
    static let switches: Set<String> = []
    static let usage = """
        usage: arma extension <action> [options]

          list [--space <s>] [--engine chromium|servo]
                                   extensions with their id, version, engine, whether
                                   they are on, and the Spaces they are in
          install <source> [--space <s>]
                                   a Chrome Web Store id or listing address installs into
                                   the Space (the front window's by default) once you
                                   review it in Arma; an .xpi or an unpacked extension's
                                   folder installs into Servo
          remove <extension> [--space <s>]
                                   remove it from the Space, or from every Space
          enable <extension> [--space <s>] | disable <extension> [--space <s>]
                                   turn a Chromium extension on or off
          info <extension>         what it is, asks for and where it runs

        An extension is its id, the start of its id, or its name in any case.

        """

    /// A Chrome Web Store extension id: 32 letters from a to p.
    private static let webStoreLetters = Set("abcdefghijklmnop")

    // MARK: - Actions - Parsing

    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        let space = arguments.option("space")
        switch action {
        case "list", "ls":
            var engine: TerminalEngine?
            if let text = arguments.option("engine") {
                engine = try TerminalArguments.choice(text, as: TerminalEngine.self, for: "--engine")
                guard engine != .webkit else {
                    throw TerminalArguments.Problem(message: "WebKit runs no extensions; give chromium or servo.")
                }
            }
            return .extension(.list(space: space, engine: engine))
        case "install", "add":
            return .extension(.install(source: try source(try arguments.take("an extension to install")), space: space))
        case "remove", "uninstall", "rm":
            return .extension(.remove(reference: try arguments.take("an extension"), space: space))
        case "enable", "on":
            return .extension(.enable(reference: try arguments.take("an extension"), space: space))
        case "disable", "off":
            return .extension(.disable(reference: try arguments.take("an extension"), space: space))
        case "info", "show":
            return .extension(.info(reference: try arguments.take("an extension")))
        default:
            throw TerminalArguments.Problem(message: "arma extension has no action '\(action)'.")
        }
    }

    /// Where `text` says to install from: a file or folder that exists here,
    /// read from the terminal's own directory, a Web Store listing's address,
    /// or a bare Web Store id.
    private static func source(_ text: String) throws(TerminalArguments.Problem) -> TerminalExtensionCommand.Source {
        let expanded = (text as NSString).expandingTildeInPath
        let file =
            expanded.hasPrefix("/")
            ? URL(fileURLWithPath: expanded)
            : URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(expanded)
        if FileManager.default.fileExists(atPath: file.path) { return .file(path: file.standardizedFileURL.path) }
        if let url = URL(string: text), let host = url.host?.lowercased(),
            host == "chromewebstore.google.com" || host == "chrome.google.com"
        {
            guard let id = url.pathComponents.last(where: isWebStoreID) else {
                throw TerminalArguments.Problem(message: "'\(text)' names no extension in the Chrome Web Store.")
            }
            return .webStore(id: id)
        }
        if isWebStoreID(text) { return .webStore(id: text) }
        throw TerminalArguments.Problem(
            message: "'\(text)' is no file or folder here, Chrome Web Store address, or Web Store id.")
    }

    private static func isWebStoreID(_ text: String) -> Bool {
        text.count == 32 && text.allSatisfy(webStoreLetters.contains)
    }
}
