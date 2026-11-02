import Foundation

/// `arma theme`: the themes saved on this Mac, which Spaces pick. A theme
/// holds every color of the window but a Space's own crest; `arma crest`
/// shapes that.
enum TerminalThemeCommand: Codable, Sendable {
    /// Every saved theme, the Spaces wearing each, and the shown Space's marked.
    case list
    /// One theme as a theme file, to read or to save.
    case show(theme: String)
    /// Saves a new theme named `name`: a Space's look, a theme file's, or the
    /// plain look, with `look`'s choices over it.
    case create(name: String, fromSpace: String?, look: CrestTheme?)
    /// Saves a copy of a theme, named `name` or "<theme> Copy".
    case duplicate(theme: String, name: String?)
    case rename(theme: String, name: String)
    /// Deletes a theme no Space wears.
    case delete(theme: String)
    /// Changes a theme, or the one `space` wears, and every Space wearing it:
    /// `look`'s choices in its light look, or its dark look with `dark`, and
    /// its dark look taken away with `unpairDark`.
    case edit(theme: String?, space: String?, look: CrestTheme?, dark: Bool, unpairDark: Bool)
    /// Has a Space, or the shown one, wear a theme.
    case use(theme: String, space: String?)
}
