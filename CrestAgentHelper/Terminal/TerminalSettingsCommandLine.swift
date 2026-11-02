import Foundation

/// `arma settings`.
enum TerminalSettingsCommandLine: TerminalSection {
    static let name = "settings"
    static let summary = "Read and change settings, and export or import browser data"
    static let switches: Set<String> = ["yes", "force"]
    static let usage = """
        usage: arma settings <action> [options]

          list [--section <name>] [--space <s>]
                                   every setting: key, value, allowed values and
                                   where it is in Settings
          get <key> [--space <s>]  one setting's value
          set <key> <value> [--space <s>]
                                   change a setting
          reset <key> [--space <s>]
                                   put a setting back to its default
          export <file> [--format browser-data|bookmarks] [--force]
                                   write the Spaces, their settings, tabs and history
                                   (or the bookmarks) to <file>; --force replaces it
          import <file> --yes      add the Spaces, tabs and history of a browser-data
                                   file after your own; it replaces nothing

        A section is the first part of a key, such as general, tabs, links, search,
        engines, appearance, agents or space. Keys that start with space. belong to
        one Space: --space names it, or the front window's Space is used.

        """

    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        let space = arguments.option("space")
        switch action {
        case "list", "ls":
            return .settings(.list(section: arguments.takeIfPresent() ?? arguments.option("section"), space: space))
        case "get":
            return .settings(.get(key: try arguments.take("a key"), space: space))
        case "set":
            let key = try arguments.take("a key")
            return .settings(.set(key: key, value: try arguments.take("a value"), space: space))
        case "reset":
            return .settings(.reset(key: try arguments.take("a key"), space: space))
        case "export":
            let path = try absolute(try arguments.take("a file"))
            var format = TerminalExportFormat.browserData
            if let text = arguments.option("format") {
                format = try TerminalArguments.choice(text, as: TerminalExportFormat.self, for: "--format")
            }
            return .settings(.export(path: path, format: format, replaces: arguments.has("force")))
        case "import":
            let path = try absolute(try arguments.take("a file"))
            guard arguments.has("yes") else {
                throw TerminalArguments.Problem(
                    message:
                        "Importing adds every Space in the file, with its tabs and history, after your own Spaces. Nothing is replaced. Run it again with --yes to import."
                )
            }
            return .settings(.importFile(path: path, confirmed: true))
        default:
            throw TerminalArguments.Problem(message: "arma settings has no action '\(action)'.")
        }
    }

    // MARK: - Actions - Files

    /// `path` from the helper's working directory, which Arma does not share.
    private static func absolute(_ path: String) throws(TerminalArguments.Problem) -> String {
        guard !path.isEmpty else { throw TerminalArguments.Problem(message: "Give a file.") }
        let expanded = (path as NSString).expandingTildeInPath
        let base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return URL(fileURLWithPath: expanded, relativeTo: base).standardizedFileURL.path
    }
}
