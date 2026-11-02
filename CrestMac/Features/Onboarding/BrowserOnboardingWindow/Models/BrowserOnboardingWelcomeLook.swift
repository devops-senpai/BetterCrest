import Foundation

/// The looks the welcome page fades between: Catppuccin's three dark
/// flavors in stripes, under Arma's own arms, so the welcome shows Arma's
/// logo and stays dark enough for its light text.
enum BrowserOnboardingWelcomeLook {
    // MARK: - Static Variables

    /// Frappé, Macchiato and Mocha: each flavor's base, mauve and blue.
    static let all: [SpaceBranding] = [
        look(base: 0x303446, mauve: 0xCA9EE6, blue: 0x8CAAEE),
        look(base: 0x24273A, mauve: 0xC6A0F6, blue: 0x8AADF4),
        look(base: 0x1E1E2E, mauve: 0xCBA6F7, blue: 0x89B4FA),
    ]

    // MARK: - Actions - Looks

    /// The welcome's look `index` turns into, round and round.
    static func look(at index: Int) -> SpaceBranding {
        all[index % all.count]
    }

    /// A flavor's colors in stripes, its field the base, with the logo's
    /// guidon, pale and bird as the crest.
    private static func look(base: Int, mauve: Int, blue: Int) -> SpaceBranding {
        var look = SpaceHouse.winter.look
        look.colors = ColorPalette(colors: [color(base), color(mauve), color(blue)])
        look.themeMode = .banner
        look.bannerPattern = .stripes
        look.bannerStrength = 1
        look.crest.backplate = .flag
        look.crest.ordinary = .pale
        look.crest.symbol = .sparrow
        look.crest.charge = nil
        return look.normalized()
    }

    private static func color(_ hex: Int) -> BrandColor {
        BrandColor(
            red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: 1)
    }
}
