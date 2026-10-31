import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// A Space's looks as a theme file people share: written with a save panel,
/// read with an open panel and laid onto the looks. The file is the same JSON
/// `crest-browser theme` writes and reads, with a `dark` object when the
/// Space has a look of its own for dark windows.
@MainActor
struct BrowserSpaceThemeFiles {
    // MARK: - Variables

    /// The Space's name, which names the file.
    let name: String
    /// The look being written out or dressed.
    let branding: Binding<SpaceBranding>
    /// The look for dark windows, nil while the Space wears one look in both.
    let darkBranding: Binding<SpaceBranding?>

    /// The two actions as the shared editor offers them.
    var actions: BrowserSpaceThemeFileActions {
        BrowserSpaceThemeFileActions(export: { await export() }, load: { await load() })
    }

    // MARK: - Initializers

    init(name: String, branding: Binding<SpaceBranding>, darkBranding: Binding<SpaceBranding?>) {
        self.name = name
        self.branding = branding
        self.darkBranding = darkBranding
    }

    /// The files of `space` as `browser` keeps it.
    init(browser: BrowserStore, space: SpaceModel) {
        self.init(
            name: space.settings.name, branding: browser.spaceBrandingBinding(in: space),
            darkBranding: Binding(
                get: { space.settings.darkBranding },
                set: { browser.updateSpaceDarkBranding($0, in: space.id) }))
    }

    // MARK: - Actions - Exporting

    /// Asks where to save the looks as a theme and writes it there. Answers
    /// what went wrong, or nil when the theme was saved or the person cancelled.
    func export() async -> String? {
        let panel = NSSavePanel()
        panel.title = "Export Theme"
        panel.prompt = "Export"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(name) Theme.json"
        let response = await withCheckedContinuation { continuation in
            panel.begin { continuation.resume(returning: $0) }
        }
        guard response == .OK, let url = panel.url else { return nil }
        var theme = CrestTheme(look: branding.wrappedValue, dark: darkBranding.wrappedValue)
        theme.name = name
        do {
            try theme.json().write(to: url, options: .atomic)
            return nil
        } catch {
            return "The theme couldn’t be saved: \(error.localizedDescription)"
        }
    }

    // MARK: - Actions - Loading

    /// Asks for a theme file and dresses the looks in it: the top level dresses
    /// the look, and a `dark` object dresses the dark look, starting one from
    /// the dressed look when the Space had none. Answers what went wrong, or
    /// nil when the looks changed or the person cancelled.
    func load() async -> String? {
        let panel = NSOpenPanel()
        panel.title = "Load Theme"
        panel.prompt = "Load"
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        let response = await withCheckedContinuation { continuation in
            panel.begin { continuation.resume(returning: $0) }
        }
        guard response == .OK, let url = panel.url else { return nil }
        let theme: CrestTheme
        do {
            theme = try CrestTheme(json: try Data(contentsOf: url))
        } catch {
            return "\(url.lastPathComponent) is not a Crest theme."
        }
        let current = branding.wrappedValue
        let currentDark = darkBranding.wrappedValue
        do {
            let look = try current.dressed(in: theme)
            if look != current { branding.wrappedValue = look.normalized() }
            if let darkSections = theme.dark {
                let dark = try (currentDark ?? look).dressed(in: darkSections)
                if dark != currentDark { darkBranding.wrappedValue = dark.normalized() }
            }
            return nil
        } catch {
            return error.message
        }
    }
}
