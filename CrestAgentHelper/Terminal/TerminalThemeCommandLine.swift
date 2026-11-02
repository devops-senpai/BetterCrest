import Foundation

/// `arma theme`.
enum TerminalThemeCommandLine: TerminalSection {
    static let name = "theme"
    static let summary = "Make, edit and pick the themes that color Arma's windows"
    static let switches: Set<String> = ["dark", "unpair-dark"]
    static let usage = """
        usage: arma theme <action> [options]

          list                          saved themes, the Spaces using each; * marks the
                                        shown Space's
          show <theme>                  a theme as a theme file (JSON); save it with > file
          new <name> [--from-space <space>] [--from-file <path>] [look options]
                                        save a theme, from a Space's look, a file, or plain
          duplicate <theme> [--name <name>]
          rename <theme> <name>
          delete <theme>                delete a theme no Space uses
          import <path> [--name <name>] save a theme file as a theme
          edit [<theme>] [--space <space>] [--dark] [--unpair-dark] [--from-file <path>]
               [look options]           change a theme, or the one a Space uses, and every
                                        Space using it; --dark edits its dark look
          use <theme> [--space <space>] have a Space, or the shown one, use a theme

        Look options:
          --background <hex>[,<hex>[,<hex>]]   background, accent and pattern colors
          --style banner|gradient
          --pattern <name>              solid, split, bands, diagonal, chevron, quartered,
                                        stripes, checkered or lozenges
          --angle <degrees>             the gradient's direction
          --intensity <0-1>             how strongly the colors show
          --fade <0-1>                  the readability fade behind the controls
          --texture on|off
          --text automatic|light|dark|system
          --sidebar-text <hex>|default  the one color the sidebar's text reads in
          --sidebar-secondary-text <hex>|default
                                        the sidebar's quieter text, such as New Tab
          --folder-color <hex>|default
          --folder-back-color <hex>|default
          --folder-outline-color <hex>|default
          --folder-intensity <0-1>
          --palette-light <hex>|default  --palette-light-opacity <0-1>  --palette-light-text <hex>|default
          --palette-dark <hex>|default   --palette-dark-opacity <0-1>   --palette-dark-text <hex>|default

        A theme is named by its name (any case). Colors are #RRGGBB or #RRGGBBAA. A Space's
        crest and icon are not part of its theme: shape and color them with arma crest.

        """

    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        switch action {
        case "list":
            return .theme(.list)
        case "show", "export":
            return .theme(.show(theme: try arguments.take("the theme")))
        case "new", "create":
            let name = try arguments.take("the new theme's name")
            return .theme(
                .create(name: name, fromSpace: arguments.option("from-space"), look: try look(from: arguments)))
        case "duplicate", "copy":
            return .theme(.duplicate(theme: try arguments.take("the theme"), name: arguments.option("name")))
        case "rename":
            let theme = try arguments.take("the theme")
            return .theme(.rename(theme: theme, name: try arguments.take("the new name")))
        case "delete", "remove":
            return .theme(.delete(theme: try arguments.take("the theme")))
        case "import":
            let path = try arguments.take("the theme file")
            var theme = try file(path)
            if let name = arguments.option("name") { theme.name = name }
            if theme.name?.isEmpty ?? true {
                theme.name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            }
            return .theme(.create(name: theme.name ?? "Imported Theme", fromSpace: nil, look: theme))
        case "edit", "set":
            let theme = arguments.takeIfPresent()
            let space = arguments.option("space")
            guard theme != nil || space != nil else {
                throw TerminalArguments.Problem(message: "Name the theme, or a Space with --space.")
            }
            let look = try look(from: arguments)
            guard look != nil || arguments.has("unpair-dark") else {
                throw TerminalArguments.Problem(message: "Name something to change.")
            }
            return .theme(
                .edit(
                    theme: theme, space: space, look: look, dark: arguments.has("dark"),
                    unpairDark: arguments.has("unpair-dark")))
        case "use", "pick":
            return .theme(.use(theme: try arguments.take("the theme"), space: arguments.option("space")))
        default:
            throw TerminalArguments.Problem(message: "arma theme has no action '\(action)'.")
        }
    }

    // MARK: - Actions - Look options

    /// The theme file at `path`.
    static func file(_ path: String) throws(TerminalArguments.Problem) -> CrestTheme {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw TerminalArguments.Problem(message: "There is no theme file at \(path).")
        }
        do {
            return try CrestTheme(json: data)
        } catch {
            throw TerminalArguments.Problem(message: "\(path) is not a theme file: \(error.localizedDescription)")
        }
    }

    /// The look `--from-file` and the look options name, the options over
    /// the file, or nil for none.
    static func look(from arguments: TerminalArguments) throws(TerminalArguments.Problem) -> CrestTheme? {
        var flags = CrestTheme()
        func color(_ name: String) throws(TerminalArguments.Problem) -> String? {
            guard let text = arguments.option(name) else { return nil }
            guard text == CrestTheme.defaultColorWord || CrestThemeHex.components(text) != nil else {
                throw TerminalArguments.Problem(
                    message: "--\(name) takes a color such as #336699, or default, not '\(text)'.")
            }
            return text
        }
        func unit(_ name: String) throws(TerminalArguments.Problem) -> Double? {
            guard let number = try arguments.number(name) else { return nil }
            guard (0...1).contains(number) else {
                throw TerminalArguments.Problem(message: "--\(name) takes a number from 0 to 1.")
            }
            return number
        }
        var background = CrestTheme.Background()
        if let text = arguments.option("background") {
            let colors = text.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            guard (1...3).contains(colors.count), colors.allSatisfy({ CrestThemeHex.components($0) != nil }) else {
                throw TerminalArguments.Problem(
                    message: "--background takes one to three colors such as #336699,#99ccff.")
            }
            background.colors = colors
        }
        if let style = arguments.option("style") {
            guard style == "banner" || style == "gradient" else {
                throw TerminalArguments.Problem(message: "--style takes banner or gradient, not '\(style)'.")
            }
            background.style = style
        }
        background.pattern = arguments.option("pattern")
        background.angle = try arguments.number("angle")
        background.intensity = try unit("intensity")
        background.readabilityFade = try unit("fade")
        if let texture = arguments.option("texture") {
            guard texture == "on" || texture == "off" else {
                throw TerminalArguments.Problem(message: "--texture takes on or off, not '\(texture)'.")
            }
            background.texture = texture == "on"
        }
        background.textColor = arguments.option("text")
        background.sidebarText = try color("sidebar-text")
        background.sidebarSecondaryText = try color("sidebar-secondary-text")
        if background != CrestTheme.Background() { flags.background = background }

        var folders = CrestTheme.Folders()
        folders.color = try color("folder-color")
        folders.backColor = try color("folder-back-color")
        folders.outlineColor = try color("folder-outline-color")
        folders.intensity = try unit("folder-intensity")
        if folders != CrestTheme.Folders() { flags.folders = folders }

        var palette = CrestTheme.CommandPalette()
        for dark in [false, true] {
            let prefix = dark ? "palette-dark" : "palette-light"
            var surface = CrestTheme.CommandPalette.Surface()
            surface.tint = try color(prefix)
            surface.opacity = try unit(prefix + "-opacity")
            surface.text = try color(prefix + "-text")
            guard surface != CrestTheme.CommandPalette.Surface() else { continue }
            if dark { palette.dark = surface } else { palette.light = surface }
        }
        if palette != CrestTheme.CommandPalette() { flags.commandPalette = palette }

        let file = try arguments.option("from-file").map { (path) throws(TerminalArguments.Problem) in
            try Self.file(path)
        }
        let merged = (file ?? CrestTheme()).merging(flags)
        return merged.isEmpty ? nil : merged
    }
}
