import Foundation

/// `arma theme`: dresses a Space from the terminal, from flags, from
/// a theme file, or both, and writes a Space's theme out to share. Each flag
/// names one part of the look; what a flag and the file both name, the flag
/// decides. The request reaches the running Crest over the commands socket.
struct ThemeCommandLine {
    // MARK: - Types

    /// Why the arguments made no request.
    struct Problem: Error {
        let message: String
    }

    // MARK: - Static Variables

    static let usage = """
        usage: arma theme --space <name> [options]

        Apply a look to one Space of the running Crest, and share it.

          --from-file <path>            apply a theme file (JSON)
          --dark-from-file <path>       apply a theme file as the look for dark windows
          --unpair-dark                 wear the one look in light and dark windows again
          --export [<path>]             write the Space's theme as JSON to <path>, or print it
          --reset <section>             put a section back to the Space's starting look:
                                        background, icon, folders, command-palette or all

          --background <hex>[,<hex>[,<hex>]]   background, accent and pattern colors
          --style banner|gradient
          --pattern <name>              solid, split, bands, diagonal, chevron, quartered,
                                        stripes, checkered or lozenges
          --angle <degrees>             the gradient's direction
          --intensity <0-1>             how strongly the colors show
          --fade <0-1>                  the readability fade behind the controls
          --texture on|off
          --text automatic|light|dark|system
          --sidebar-text <hex>|default     the one color the sidebar's text reads in

          --icon-color <hex>|default
          --folder-color <hex>|default
          --folder-back-color <hex>|default
          --folder-intensity <0-1>
          --palette-light <hex>|default   --palette-light-opacity <0-1>   --palette-light-text <hex>|default
          --palette-dark <hex>|default    --palette-dark-opacity <0-1>    --palette-dark-text <hex>|default

        Colors are #RRGGBB or #RRGGBBAA. A theme file holds the same choices, and may add a
        "dark" object with the same sections for the look the Space wears in dark windows:

          { "name": "Dusk",
            "background": { "colors": ["#1b1f2a", "#3a2f5b"], "style": "gradient", "angle": 135 },
            "folders": { "color": "#7a8bb0" },
            "commandPalette": { "dark": { "tint": "#101218", "opacity": 0.7 } } }

        """

    // MARK: - Variables

    let space: String
    let changes: CrestTheme?
    let resets: [CrestThemeSection]
    /// Whether the Space's dark look is taken away.
    let removeDark: Bool
    /// Where the Space's theme is written, "-" for standard output, or nil
    /// when it is not asked for.
    let exportPath: String?

    // MARK: - Initializers

    /// The command `arguments` spell, after the `theme` word.
    init(arguments: [String]) throws {
        var space: String?
        var fileTheme: CrestTheme?
        var flags = CrestTheme()
        var resets: [CrestThemeSection] = []
        var removeDark = false
        var exportPath: String?
        var index = arguments.startIndex

        func value(for flag: String) throws -> String {
            index += 1
            guard arguments.indices.contains(index), !arguments[index].hasPrefix("--") else {
                throw Problem(message: "\(flag) needs a value.")
            }
            return arguments[index]
        }
        func unit(for flag: String) throws -> Double {
            let text = try value(for: flag)
            guard let number = Double(text), (0...1).contains(number) else {
                throw Problem(message: "\(flag) takes a number from 0 to 1, not '\(text)'.")
            }
            return number
        }
        func color(for flag: String) throws -> String {
            let text = try value(for: flag)
            guard text == CrestTheme.defaultColorWord || CrestThemeHex.components(text) != nil else {
                throw Problem(message: "\(flag) takes a color such as #336699, or default, not '\(text)'.")
            }
            return text
        }
        func paletteSurface(dark: Bool, _ change: (inout CrestTheme.CommandPalette.Surface) -> Void) {
            var palette = flags.commandPalette ?? .init()
            var surface = (dark ? palette.dark : palette.light) ?? .init()
            change(&surface)
            if dark { palette.dark = surface } else { palette.light = surface }
            flags.commandPalette = palette
        }

        while arguments.indices.contains(index) {
            let flag = arguments[index]
            switch flag {
            case "--space":
                space = try value(for: flag)
            case "--socket":
                _ = try value(for: flag)
            case "--from-file":
                let path = try value(for: flag)
                guard let data = FileManager.default.contents(atPath: path) else {
                    throw Problem(message: "There is no theme file at \(path).")
                }
                do {
                    fileTheme = try CrestTheme(json: data)
                } catch {
                    throw Problem(message: "\(path) is not a theme file: \(error.localizedDescription)")
                }
            case "--dark-from-file":
                let path = try value(for: flag)
                guard let data = FileManager.default.contents(atPath: path) else {
                    throw Problem(message: "There is no theme file at \(path).")
                }
                do {
                    let dark = try CrestTheme(json: data)
                    flags.dark = (flags.dark ?? .init()).merging(dark.sections)
                } catch {
                    throw Problem(message: "\(path) is not a theme file: \(error.localizedDescription)")
                }
            case "--unpair-dark":
                removeDark = true
            case "--export":
                let next = index + 1
                if arguments.indices.contains(next), !arguments[next].hasPrefix("--") {
                    exportPath = arguments[next]
                    index = next
                } else {
                    exportPath = "-"
                }
            case "--reset":
                let name = try value(for: flag)
                if name == "all" {
                    resets = CrestThemeSection.allCases
                } else if let section = CrestThemeSection(rawValue: name) {
                    resets.append(section)
                } else {
                    throw Problem(
                        message: "--reset takes background, icon, folders, command-palette or all, not '\(name)'.")
                }
            case "--background":
                let colors = try value(for: flag).split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                guard (1...3).contains(colors.count), colors.allSatisfy({ CrestThemeHex.components($0) != nil })
                else {
                    throw Problem(message: "--background takes one to three colors such as #336699,#99ccff.")
                }
                flags.background = flags.background ?? .init()
                flags.background?.colors = colors
            case "--style":
                let style = try value(for: flag)
                guard style == "banner" || style == "gradient" else {
                    throw Problem(message: "--style takes banner or gradient, not '\(style)'.")
                }
                flags.background = flags.background ?? .init()
                flags.background?.style = style
            case "--pattern":
                flags.background = flags.background ?? .init()
                flags.background?.pattern = try value(for: flag)
            case "--angle":
                let text = try value(for: flag)
                guard let angle = Double(text) else { throw Problem(message: "--angle takes degrees, not '\(text)'.") }
                flags.background = flags.background ?? .init()
                flags.background?.angle = angle
            case "--intensity":
                flags.background = flags.background ?? .init()
                flags.background?.intensity = try unit(for: flag)
            case "--fade":
                flags.background = flags.background ?? .init()
                flags.background?.readabilityFade = try unit(for: flag)
            case "--texture":
                let text = try value(for: flag)
                guard text == "on" || text == "off" else {
                    throw Problem(message: "--texture takes on or off, not '\(text)'.")
                }
                flags.background = flags.background ?? .init()
                flags.background?.texture = text == "on"
            case "--text":
                flags.background = flags.background ?? .init()
                flags.background?.textColor = try value(for: flag)
            case "--sidebar-text":
                flags.background = flags.background ?? .init()
                flags.background?.sidebarText = try color(for: flag)
            case "--icon-color":
                flags.icon = .init(color: try color(for: flag))
            case "--folder-color":
                flags.folders = flags.folders ?? .init()
                flags.folders?.color = try color(for: flag)
            case "--folder-back-color":
                flags.folders = flags.folders ?? .init()
                flags.folders?.backColor = try color(for: flag)
            case "--folder-intensity":
                flags.folders = flags.folders ?? .init()
                flags.folders?.intensity = try unit(for: flag)
            case "--palette-light", "--palette-dark":
                let tint = try color(for: flag)
                paletteSurface(dark: flag == "--palette-dark") { $0.tint = tint }
            case "--palette-light-opacity", "--palette-dark-opacity":
                let opacity = try unit(for: flag)
                paletteSurface(dark: flag == "--palette-dark-opacity") { $0.opacity = opacity }
            case "--palette-light-text", "--palette-dark-text":
                let text = try color(for: flag)
                paletteSurface(dark: flag == "--palette-dark-text") { $0.text = text }
            default:
                throw Problem(message: "Unknown option \(flag).")
            }
            index += 1
        }

        guard let space, !space.isEmpty else { throw Problem(message: "--space names the Space to theme.") }
        let merged = (fileTheme ?? CrestTheme()).merging(flags)
        let changes = merged.isEmpty ? nil : merged
        guard changes != nil || !resets.isEmpty || removeDark || exportPath != nil else {
            throw Problem(message: "Name something to change, a --reset, --unpair-dark or --export.")
        }
        self.space = space
        self.changes = changes
        self.resets = resets
        self.removeDark = removeDark
        self.exportPath = exportPath
    }

    // MARK: - Actions - Running

    /// Sends the command to Crest over `link` and writes the outcome to the
    /// terminal: the summary or the theme on standard output, a refusal on
    /// standard error. Answers the process's exit status.
    func run(over link: CommandAppLink) async -> Int32 {
        let request = CommandLinkRequest.theme(
            version: CommandLinkRequest.version, space: space, changes: changes, resets: resets,
            removeDark: removeDark, export: exportPath != nil)
        do {
            switch try await link.send(request) {
            case .applied(let summary):
                print(summary)
                return 0
            case .theme(let theme):
                return write(theme)
            case .refused(let message):
                FileHandle.standardError.write(Data((message + "\n").utf8))
                return 1
            }
        } catch let failure as CommandAppLink.Failure {
            FileHandle.standardError.write(Data((failure.message + "\n").utf8))
            return 69
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            return 70
        }
    }

    private func write(_ theme: CrestTheme) -> Int32 {
        guard let data = try? theme.json() else { return 70 }
        if exportPath == nil || exportPath == "-" {
            FileHandle.standardOutput.write(data + [0x0A])
            return 0
        }
        guard let path = exportPath, FileManager.default.createFile(atPath: path, contents: data + [0x0A]) else {
            FileHandle.standardError.write(Data("Couldn't write \(exportPath ?? "").\n".utf8))
            return 73
        }
        print("Wrote \(path)")
        return 0
    }
}
