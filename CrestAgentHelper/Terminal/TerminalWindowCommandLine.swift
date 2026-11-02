import Foundation

/// `arma window`.
enum TerminalWindowCommandLine: TerminalSection {
    static let name = "window"
    static let summary = "List, move, resize, tile, minimize and zoom Arma's windows"
    static let switches: Set<String> = []
    static let usage = """
        usage: arma window <action> [<window>] [options]

          list                          windows front to back: number, Space, frame, screen
          focus [<window>]              bring a window forward
          move [<window>] <x> <y> [--screen <n>]
                                        put the top-left corner at x, y points from the
                                        screen's top left (screen 1 is the main screen)
          resize [<window>] <width> <height>
          tile [<window>] <region>      left, right, top, bottom, top-left, top-right,
                                        bottom-left, bottom-right or full
          center | minimize | restore | zoom | fullscreen [<window>]
          open [--space <s>]            open a new window
          close [<window>]

        A window is its number from arma window list, front (the default) or its id.

        """

    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        /// The window, when there are more values than the `count` the
        /// action takes after it; else the front one.
        func window(before count: Int) -> String {
            arguments.positionals.count > count ? (arguments.takeIfPresent() ?? "front") : "front"
        }
        switch action {
        case "list", "ls":
            return .window(.list)
        case "focus":
            return .window(.focus(window: window(before: 0)))
        case "move":
            let target = window(before: 2)
            let x = try TerminalArguments.number(try arguments.take("x"), for: "x")
            let y = try TerminalArguments.number(try arguments.take("y"), for: "y")
            return .window(.move(window: target, x: x, y: y, screen: try arguments.number("screen").map { Int($0) }))
        case "resize", "size":
            let target = window(before: 2)
            let width = try TerminalArguments.number(try arguments.take("a width"), for: "The width")
            let height = try TerminalArguments.number(try arguments.take("a height"), for: "The height")
            return .window(.resize(window: target, width: width, height: height))
        case "tile":
            let target = window(before: 1)
            let region = try TerminalArguments.choice(
                try arguments.take("a region"), as: TerminalWindowRegion.self, for: "The region")
            return .window(.tile(window: target, region: region))
        case "center":
            return .window(.center(window: window(before: 0)))
        case "minimize":
            return .window(.minimize(window: window(before: 0)))
        case "restore":
            return .window(.restore(window: window(before: 0)))
        case "zoom", "maximize":
            return .window(.zoom(window: window(before: 0)))
        case "fullscreen":
            return .window(.fullScreen(window: window(before: 0)))
        case "open", "new":
            return .window(.open(space: arguments.option("space")))
        case "close":
            return .window(.close(window: window(before: 0)))
        default:
            throw TerminalArguments.Problem(message: "arma window has no action '\(action)'.")
        }
    }
}
