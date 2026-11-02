import Foundation

/// Why a theme could not dress a Space.
enum CrestThemeProblem: Error {
    case unknownStyle(String)
    case unknownPattern(String)
    case unknownTextColor(String)
    case badColor(String)

    /// What the person reads at the terminal.
    var message: String {
        switch self {
        case .unknownStyle(let style):
            "The style '\(style)' is not banner or gradient."
        case .unknownPattern(let pattern):
            "The pattern '\(pattern)' is not one Crest draws. Try \(SpaceBannerPattern.all.map(\.name).joined(separator: ", "))."
        case .unknownTextColor(let mode):
            "The text color '\(mode)' is not automatic, light, dark or system."
        case .badColor(let text):
            "'\(text)' is not a color. Colors are #RRGGBB or #RRGGBBAA, or the word default."
        }
    }
}

/// A theme read from a Space's looks, and laid onto them.
extension CrestTheme {
    // MARK: - Initializers

    /// Everything `look` chooses that a theme can carry, and the same of
    /// `dark` when the Space has a look of its own for dark windows.
    init(look: SpaceBranding, dark: SpaceBranding? = nil) {
        self.init(sections: Sections(look: look), dark: dark.map(Sections.init(look:)))
    }

    // MARK: - Actions - Colors

    /// `color` as a theme spells it.
    static func text(_ color: BrandColor) -> String {
        CrestThemeHex.text(.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha))
    }

    /// The color `text` spells, nil for the word `default`, or a problem for
    /// anything else.
    static func color(_ text: String) throws(CrestThemeProblem) -> BrandColor? {
        if text == defaultColorWord { return nil }
        guard let parts = CrestThemeHex.components(text) else { throw .badColor(text) }
        return BrandColor(red: parts.red, green: parts.green, blue: parts.blue, alpha: parts.alpha)
    }
}

extension CrestTheme.Sections {
    // MARK: - Initializers

    /// Everything `look` chooses that a theme can carry.
    init(look: SpaceBranding) {
        self.init(
            background: CrestTheme.Background(
                colors: look.colors.colors.map(CrestTheme.text),
                style: look.themeMode.name,
                pattern: look.bannerPattern.name,
                angle: look.gradientAngle,
                intensity: look.bannerStrength,
                readabilityFade: look.readabilityFade,
                texture: look.showsTexture,
                textColor: look.textColorMode.name,
                sidebarText: look.sidebarTextColor.map(CrestTheme.text) ?? CrestTheme.defaultColorWord),
            icon: CrestTheme.Icon(color: look.symbolColor.map(CrestTheme.text) ?? CrestTheme.defaultColorWord),
            folders: CrestTheme.Folders(
                color: look.folderColor.map(CrestTheme.text) ?? CrestTheme.defaultColorWord,
                backColor: look.folderBackColor.map(CrestTheme.text) ?? CrestTheme.defaultColorWord,
                intensity: look.folderColorIntensity),
            commandPalette: CrestTheme.CommandPalette(
                light: Self.surface(look.commandPalette?.light),
                dark: Self.surface(look.commandPalette?.dark)))
    }

    private static func surface(_ surface: SpacePaletteSurface?) -> CrestTheme.CommandPalette.Surface {
        CrestTheme.CommandPalette.Surface(
            tint: surface?.tint.map(CrestTheme.text) ?? CrestTheme.defaultColorWord, opacity: surface?.opacity ?? 0,
            text: surface?.textColor.map(CrestTheme.text) ?? CrestTheme.defaultColorWord)
    }
}

extension SpaceBranding {
    // MARK: - Actions - Themes

    /// This look dressed in everything `theme`'s top-level sections name, the
    /// rest kept. Throws a problem for a word or color the theme misspells,
    /// changing nothing.
    func dressed(in theme: CrestTheme) throws(CrestThemeProblem) -> SpaceBranding {
        try dressed(in: theme.sections)
    }

    /// This look dressed in everything `sections` name, the rest kept.
    func dressed(in sections: CrestTheme.Sections) throws(CrestThemeProblem) -> SpaceBranding {
        var look = self
        if let background = sections.background {
            if let colors = background.colors {
                var parsed: [BrandColor] = []
                for text in colors {
                    guard let color = try CrestTheme.color(text) else { throw .badColor(text) }
                    parsed.append(color)
                }
                look.colors = ColorPalette(colors: parsed)
            }
            if let style = background.style {
                guard let mode = SpaceThemeMode.named(style) else { throw .unknownStyle(style) }
                look.themeMode = mode
            }
            if let name = background.pattern {
                guard let pattern = SpaceBannerPattern.named(name) else { throw .unknownPattern(name) }
                look.bannerPattern = pattern
                if background.style == nil { look.themeMode = .banner }
            }
            if let angle = background.angle {
                look.gradientAngle = angle
                if background.style == nil, background.pattern == nil { look.themeMode = .gradient }
            }
            if let intensity = background.intensity { look.bannerStrength = intensity }
            if let fade = background.readabilityFade { look.readabilityFade = fade }
            if let texture = background.texture { look.showsTexture = texture }
            if let name = background.textColor {
                guard let mode = SpaceTextColorMode.named(name) else { throw .unknownTextColor(name) }
                look.textColorMode = mode
            }
            if let text = background.sidebarText { look.sidebarTextColor = try CrestTheme.color(text) }
        }
        if let icon = sections.icon, let text = icon.color {
            look.symbolColor = try CrestTheme.color(text)
        }
        if let folders = sections.folders {
            if let text = folders.color { look.folderColor = try CrestTheme.color(text) }
            if let text = folders.backColor { look.folderBackColor = try CrestTheme.color(text) }
            if let intensity = folders.intensity { look.folderColorIntensity = intensity }
        }
        if let palette = sections.commandPalette {
            try look.dressSurface(in: palette.light, dark: false)
            try look.dressSurface(in: palette.dark, dark: true)
        }
        if look != self { look.hasCustomAppearance = true }
        return look
    }

    /// This look with `section` back to what `starting` gives it.
    func resetting(_ section: CrestThemeSection, to starting: SpaceBranding) -> SpaceBranding {
        var look = self
        switch section {
        case .background:
            look.colors = starting.colors
            look.themeMode = starting.themeMode
            look.bannerPattern = starting.bannerPattern
            look.gradientAngle = starting.gradientAngle
            look.bannerStrength = starting.bannerStrength
            look.readabilityFade = starting.readabilityFade
            look.showsTexture = starting.showsTexture
            look.textColorMode = starting.textColorMode
            look.sidebarTextColor = starting.sidebarTextColor
        case .icon:
            look.symbolColor = starting.symbolColor
        case .folders:
            look.folderColor = starting.folderColor
            look.folderBackColor = starting.folderBackColor
            look.folderColorIntensity = starting.folderColorIntensity
        case .commandPalette:
            look.commandPalette = starting.commandPalette
        }
        return look
    }

    // MARK: - Mutators

    private mutating func dressSurface(in surface: CrestTheme.CommandPalette.Surface?, dark: Bool)
        throws(CrestThemeProblem)
    {
        guard let surface else { return }
        var current = (commandPalette ?? .neutral).surface(dark: dark)
        if let text = surface.tint { current = current.tinted(try CrestTheme.color(text)) }
        if let opacity = surface.opacity { current.opacity = opacity }
        if let text = surface.text { current.textColor = try CrestTheme.color(text) }
        setPaletteSurface(current, dark: dark)
    }
}
