import Foundation

// A Space's look as a document people share: JSON with one section for each
// part of the look, every field optional so a theme can change only what it
// names. Colors are hex strings, `#RRGGBB` or `#RRGGBBAA`; the word `default`
// in a color field lets a chosen color go. A `dark` object holds the same
// sections for the look the Space wears while windows are dark. The helper
// reads and writes it without the app; the app turns it into a Space's
// branding.

// MARK: - Types

/// One part of a Space's look a theme or a reset names.
enum CrestThemeSection: String, Codable, CaseIterable, Sendable {
    case background
    case icon
    case folders
    case commandPalette = "command-palette"
}

/// A theme as the file holds it: the look, and the look for dark windows.
struct CrestTheme: Codable, Equatable, Sendable {
    /// The sidebar behind the tabs: its colors, how they are laid, and how
    /// the text over them reads.
    struct Background: Codable, Equatable, Sendable {
        /// One to three colors: background, accent, pattern.
        var colors: [String]?
        /// `banner` or `gradient`.
        var style: String?
        /// The banner's pattern, such as `solid` or `diagonal`.
        var pattern: String?
        /// The gradient's direction, in degrees.
        var angle: Double?
        /// How strongly the colors show, 0 through 1.
        var intensity: Double?
        /// How far the banner fades behind the controls, 0 through 1.
        var readabilityFade: Double?
        var texture: Bool?
        /// `automatic`, `light`, `dark` or `system`.
        var textColor: String?
        /// The one color the sidebar's text reads in, or `default` to follow `textColor`.
        var sidebarText: String?
    }

    /// The Space's icon.
    struct Icon: Codable, Equatable, Sendable {
        /// The icon's color, or `default` to follow the Space's colors.
        var color: String?
    }

    /// The sidebar's folders.
    struct Folders: Codable, Equatable, Sendable {
        /// One folder's colors in place of the Space's, each `default` or
        /// absent to follow them.
        struct Override: Codable, Equatable, Sendable {
            var color: String?
            var backColor: String?
            var outlineColor: String?
        }

        /// The color a folder without one of its own wears, or `default`.
        var color: String?
        /// The color of that folder's back face, or `default` to shade the front.
        var backColor: String?
        /// The line drawn around that folder, or `default` for none.
        var outlineColor: String?
        /// How strongly folders tint their rows, 0 through 1.
        var intensity: Double?
        /// Colors for single folders by path, such as `.HomeLab.proxmox`,
        /// replacing every override the Space had.
        var overrides: [String: Override]?
    }

    /// The command palette's card, in each appearance.
    struct CommandPalette: Codable, Equatable, Sendable {
        struct Surface: Codable, Equatable, Sendable {
            /// The tint over the system material, or `default` for the material alone.
            var tint: String?
            /// How far the tint covers the material, 0 through 1.
            var opacity: Double?
            /// The one color the card's text reads in, or `default` for the system's.
            var text: String?
        }

        var light: Surface?
        var dark: Surface?
    }

    /// The four sections of one look, as the file's top level and its `dark`
    /// object each hold them.
    struct Sections: Codable, Equatable, Sendable {
        var background: Background?
        var icon: Icon?
        var folders: Folders?
        var commandPalette: CommandPalette?

        /// Whether the sections name anything at all.
        var isEmpty: Bool {
            background == nil && icon == nil && folders == nil && commandPalette == nil
        }

        /// These sections with every field `other` names taking over.
        func merging(_ other: Sections) -> Sections {
            var merged = self
            if let background = other.background {
                var section = merged.background ?? Background()
                if let value = background.colors { section.colors = value }
                if let value = background.style { section.style = value }
                if let value = background.pattern { section.pattern = value }
                if let value = background.angle { section.angle = value }
                if let value = background.intensity { section.intensity = value }
                if let value = background.readabilityFade { section.readabilityFade = value }
                if let value = background.texture { section.texture = value }
                if let value = background.textColor { section.textColor = value }
                if let value = background.sidebarText { section.sidebarText = value }
                merged.background = section
            }
            if let icon = other.icon {
                var section = merged.icon ?? Icon()
                if let value = icon.color { section.color = value }
                merged.icon = section
            }
            if let folders = other.folders {
                var section = merged.folders ?? Folders()
                if let value = folders.color { section.color = value }
                if let value = folders.backColor { section.backColor = value }
                if let value = folders.outlineColor { section.outlineColor = value }
                if let value = folders.overrides {
                    section.overrides = (section.overrides ?? [:]).merging(value) { $1 }
                }
                if let value = folders.intensity { section.intensity = value }
                merged.folders = section
            }
            if let palette = other.commandPalette {
                var section = merged.commandPalette ?? CommandPalette()
                section.light = Self.merged(section.light, with: palette.light)
                section.dark = Self.merged(section.dark, with: palette.dark)
                merged.commandPalette = section
            }
            return merged
        }

        private static func merged(_ surface: CommandPalette.Surface?, with other: CommandPalette.Surface?)
            -> CommandPalette.Surface?
        {
            guard let other else { return surface }
            var merged = surface ?? CommandPalette.Surface()
            if let value = other.tint { merged.tint = value }
            if let value = other.opacity { merged.opacity = value }
            if let value = other.text { merged.text = value }
            return merged
        }
    }

    /// The picture behind a Space's sidebar and window, carried in the theme
    /// itself so a theme file brings it along, and how it sits. A theme
    /// without one takes a Space's picture away when it is put on.
    struct BackgroundImage: Codable, Equatable, Sendable {
        /// The picture's bytes, Base64.
        var data: String
        /// The picture's file extension, such as `png` or `jpg`.
        var format: String
        var anchor: String?
        var size: String?
        var growsToWidth: Bool?
        var growsToHeight: Bool?
        var tiles: Bool?
        var imageOpacity: Double?
        var tintOpacity: Double?
        var blur: Double?
        /// Where the sidebar lays its tab backing: `off`, `rows` or `sidebar`.
        var tabBacking: String?
        /// The tab backing's color, or `default` for the Space's own.
        var tabBackingColor: String?
        var tabBackingOpacity: Double?
        var tabBackingBlur: Double?
    }

    // MARK: - Static Variables

    /// The word a color field holds to let a chosen color go.
    static let defaultColorWord = "default"

    // MARK: - Variables

    var name: String?
    var background: Background?
    var icon: Icon?
    var folders: Folders?
    var commandPalette: CommandPalette?
    /// The look for dark windows, or nil to wear the look above in both.
    var dark: Sections?
    /// The Space's picture, or nil for none.
    var backgroundImage: BackgroundImage?

    /// The top-level sections: the look, or the light look of a pair.
    var sections: Sections {
        get { Sections(background: background, icon: icon, folders: folders, commandPalette: commandPalette) }
        set {
            background = newValue.background
            icon = newValue.icon
            folders = newValue.folders
            commandPalette = newValue.commandPalette
        }
    }

    /// Whether the theme names anything at all.
    var isEmpty: Bool {
        sections.isEmpty && (dark?.isEmpty ?? true)
    }

    /// The sections the theme names, as a sentence lists them.
    var sectionTitles: [String] {
        [
            (background != nil, "background"), (icon != nil, "icon"), (folders != nil, "folders"),
            (commandPalette != nil, "command palette"), (dark != nil, "dark look"),
            (backgroundImage != nil, "background image"),
        ].filter(\.0).map(\.1)
    }

    // MARK: - Initializers

    init(name: String? = nil, sections: Sections = Sections(), dark: Sections? = nil) {
        self.name = name
        self.dark = dark
        self.sections = sections
    }

    /// The theme a JSON document holds.
    init(json data: Data) throws {
        self = try JSONDecoder().decode(CrestTheme.self, from: data)
    }

    // MARK: - Actions - Documents

    /// This theme as a document, its sections in a fixed order.
    func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    // MARK: - Actions - Merging

    /// This theme with every field `other` names taking over, in the look and
    /// in the dark look alike.
    func merging(_ other: CrestTheme) -> CrestTheme {
        var merged = self
        if let name = other.name { merged.name = name }
        merged.sections = sections.merging(other.sections)
        if let otherDark = other.dark { merged.dark = (dark ?? Sections()).merging(otherDark) }
        return merged
    }
}
