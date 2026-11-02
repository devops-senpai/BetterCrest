import Foundation

/// `arma space`.
enum TerminalSpaceCommandLine: TerminalSection {
    static let name = "space"
    static let summary = "List Spaces, show one, or switch the front window to one"
    static let switches: Set<String> = []
    static let usage = """
        usage: arma space <action> [options]

          list                    every Space; * marks the one the front window shows
          show [<space>]          a Space's pinned, saved and open tabs and its folders
          switch <space>          show <space> in the front window

        A Space is named by its name (any case) or its identifier.

        """

    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        switch action {
        case "list", "ls":
            return .space(.list)
        case "show":
            return .space(.show(space: arguments.takeIfPresent() ?? arguments.option("space")))
        case "switch", "use":
            return .space(.switchTo(space: try arguments.take("a Space")))
        default:
            throw TerminalArguments.Problem(message: "arma space has no action '\(action)'.")
        }
    }
}
