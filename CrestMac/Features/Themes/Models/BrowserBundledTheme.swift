import Foundation

/// A theme Arma ships with, as a theme file in its resources, saved into
/// the theme library on first launch and offered by setup: each made to
/// welcome someone, Arc's people, coders, or those who want to make a
/// browser their own.
struct BrowserBundledTheme: Identifiable, Sendable {
    // MARK: - Static Variables

    static let arcSky = BrowserBundledTheme(
        id: UUID(uuidString: "A2C0B1E5-5A11-4C3B-9F1E-0A7C5B1D2E01")!, resource: "ArcSky",
        pitch: "Light and airy, for anyone coming from Arc")
    static let catppuccin = BrowserBundledTheme(
        id: UUID(uuidString: "A2C0B1E5-5A11-4C3B-9F1E-0A7C5B1D2E02")!, resource: "CatppuccinLatteMocha",
        pitch: "Catppuccin Latte by day and Mocha by night")
    static let macchiato = BrowserBundledTheme(
        id: UUID(uuidString: "A2C0B1E5-5A11-4C3B-9F1E-0A7C5B1D2E03")!, resource: "CatppuccinMacchiato",
        pitch: "Catppuccin's soft dark flavor, for long sessions")
    static let mocha = BrowserBundledTheme(
        id: UUID(uuidString: "A2C0B1E5-5A11-4C3B-9F1E-0A7C5B1D2E05")!, resource: "CatppuccinMocha",
        pitch: "Catppuccin's darkest flavor, with warm peach folders")
    static let frappe = BrowserBundledTheme(
        id: UUID(uuidString: "A2C0B1E5-5A11-4C3B-9F1E-0A7C5B1D2E06")!, resource: "CatppuccinFrappe",
        pitch: "Catppuccin's muted middle flavor, with teal folders")
    static let jellyFish = BrowserBundledTheme(
        id: UUID(uuidString: "A2C0B1E5-5A11-4C3B-9F1E-0A7C5B1D2E04")!, resource: "JellyFish",
        pitch: "A picture behind your tabs, made your own")

    /// Every bundled theme, in the order setup offers them.
    static let all = [arcSky, catppuccin, macchiato, mocha, frappe, jellyFish]

    // MARK: - Variables

    let id: UUID
    /// The theme file's name in the app's resources.
    let resource: String
    /// One line on who the theme is for, under it in setup.
    let pitch: LocalizedStringResource

    /// The theme its file holds, or nil when the app lacks it.
    var theme: CrestTheme? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? CrestTheme(json: data)
    }

    /// The theme's name as its file names it.
    var name: String { theme?.name ?? resource }
}
