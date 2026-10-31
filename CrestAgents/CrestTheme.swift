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
        /// The color a folder without one of its own wears, or `default`.
        var color: String?
        /// The color of that folder's back face, or `default` to shade the front.
        var backColor: String?
        /// How strongly folders tint their rows, 0 through 1.
        var intensity: Double?
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

/// How a theme spells a color: `#RRGGBB`, or `#RRGGBBAA` when it is not
/// opaque, each component a byte.
enum CrestThemeHex {
    // MARK: - Types

    /// A color's components, each 0 through 1.
    struct Components: Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }

    // MARK: - Actions - Reading

    /// The components `text` spells, or nil when it is not a hex color. A
    /// leading `#` is optional, and three-digit shorthand doubles each digit.
    static func components(_ text: String) -> Components? {
        var digits = Substring(text.trimmingCharacters(in: .whitespaces))
        if digits.hasPrefix("#") { digits = digits.dropFirst() }
        if digits.count == 3 || digits.count == 4 {
            digits = Substring(digits.flatMap { [$0, $0] })
        }
        guard digits.count == 6 || digits.count == 8, let value = UInt64(digits, radix: 16) else { return nil }
        let hasAlpha = digits.count == 8
        let shift: UInt64 = hasAlpha ? 8 : 0
        func channel(_ offset: UInt64) -> Double { Double((value >> (offset + shift)) & 0xFF) / 255 }
        return Components(
            red: channel(16), green: channel(8), blue: channel(0),
            alpha: hasAlpha ? Double(value & 0xFF) / 255 : 1)
    }

    // MARK: - Actions - Writing

    /// `components` as a theme spells them.
    static func text(_ components: Components) -> String {
        func byte(_ value: Double) -> String {
            String(format: "%02x", Int((min(max(value, 0), 1) * 255).rounded()))
        }
        let opaque = "#" + byte(components.red) + byte(components.green) + byte(components.blue)
        return components.alpha >= 1 ? opaque : opaque + byte(components.alpha)
    }
}
