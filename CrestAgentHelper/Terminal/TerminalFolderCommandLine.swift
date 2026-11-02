import Foundation

/// `arma folder`.
enum TerminalFolderCommandLine: TerminalSection {
    static let name = "folder"
    static let summary = "List, create, rename, delete and color folders, and file tabs in them"
    static let switches: Set<String> = ["open"]
    static let usage = """
        usage: arma folder <action> [options]

          list [--space <s>]       folders as a tree, in the saved and open sections,
                                   with the tabs each holds
          create <name> [--space <s>] [--in <path>] [--open]
                                   make a folder, inside <path> when given; saved,
                                   or in the open tabs with --open
          rename <path> <name> [--space <s>]
                                   rename a folder
          delete <path> [--space <s>]
                                   delete a folder; its tabs stay in its section and
                                   the folders inside it move up one level
          add <tab>... --to <path> [--space <s>]
                                   file tabs into a folder
          open <path> | close <path> [--space <s>]
                                   expand or collapse a folder in the sidebar
          color <path> <#hex|default> [--space <s>]
                                   give a folder its own color, or its Space's again

        A folder path joins folder names with /, such as Work/Clients; one name is
        enough when no other folder has it. Without --space, the front window's
        Space. A tab is current, its id, or the start of its id from arma tab list.

        """

    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        let space = arguments.option("space")
        switch action {
        case "list", "ls":
            return .folder(.list(space: space))
        case "create", "new":
            let name = try words(&arguments, naming: "a name")
            return .folder(
                .create(name: name, space: space, parent: arguments.option("in"), open: arguments.has("open")))
        case "rename":
            let folder = try arguments.take("a folder")
            return .folder(.rename(folder: folder, name: try words(&arguments, naming: "a new name"), space: space))
        case "delete", "remove", "rm":
            return .folder(.delete(folder: try arguments.take("a folder"), space: space))
        case "add", "file":
            guard let folder = arguments.option("to") else {
                throw TerminalArguments.Problem(message: "Give the folder with --to.")
            }
            var tabs = [try arguments.take("a tab")]
            while let tab = arguments.takeIfPresent() { tabs.append(tab) }
            return .folder(.add(tabs: tabs, folder: folder, space: space))
        case "open", "expand":
            return .folder(.expand(folder: try arguments.take("a folder"), space: space, expanded: true))
        case "close", "collapse":
            return .folder(.expand(folder: try arguments.take("a folder"), space: space, expanded: false))
        case "color", "colour":
            let folder = try arguments.take("a folder")
            let color = try arguments.take("a color, as #RRGGBB or default")
            let isDefault = ["default", "none", "space"].contains(color.lowercased())
            return .folder(.color(folder: folder, hex: isDefault ? nil : color, space: space))
        default:
            throw TerminalArguments.Problem(message: "arma folder has no action '\(action)'.")
        }
    }

    /// The words left, as one name.
    private static func words(
        _ arguments: inout TerminalArguments, naming name: String
    ) throws(TerminalArguments.Problem) -> String {
        var words = [try arguments.take(name)]
        while let word = arguments.takeIfPresent() { words.append(word) }
        return words.joined(separator: " ")
    }
}
