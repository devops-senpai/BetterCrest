import Foundation

/// `arma split`.
enum TerminalSplitCommandLine: TerminalSection {
    static let name = "split"
    static let summary = "Show tabs side by side in Split View, and change or end a split"
    static let switches: Set<String> = ["rows"]
    static let usage = """
        usage: arma split <action> [options]

          list [--space <s>]       splits with their layout and tabs
          create <tab> <tab> [<tab>...] [--rows]
                                   show the tabs together in a new Split View, in
                                   columns, or in stacked rows with --rows
          add <tab> --to <tab>     add a tab to the split the other tab is in
          remove <tab>             take a tab out of its split
          break <tab>              end the split the tab is in; its tabs stay
          arrange <tab> <layout>   lay out the tab's split, such as two-across,
                                   two-stacked, three-across, grid or four-stacked

        A tab is current, its id, or the start of its id from arma tab list. The
        tabs of a split share one Space; the front window shows that Space to
        change it.

        """

    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        switch action {
        case "list", "ls":
            return .split(.list(space: arguments.option("space")))
        case "create", "new":
            var tabs = [try arguments.take("a tab"), try arguments.take("a second tab")]
            while let tab = arguments.takeIfPresent() { tabs.append(tab) }
            return .split(.create(tabs: tabs, rows: arguments.has("rows")))
        case "add", "join":
            guard let target = arguments.option("to") else {
                throw TerminalArguments.Problem(message: "Give a tab of the split with --to.")
            }
            return .split(.add(tab: try arguments.take("a tab"), target: target))
        case "remove", "leave":
            return .split(.remove(tab: try arguments.take("a tab")))
        case "break", "undo", "dissolve", "separate":
            return .split(.dissolve(tab: try arguments.take("a tab")))
        case "arrange", "layout":
            let tab = try arguments.take("a tab")
            return .split(.arrange(tab: tab, layout: try arguments.take("a layout")))
        default:
            throw TerminalArguments.Problem(message: "arma split has no action '\(action)'.")
        }
    }
}
