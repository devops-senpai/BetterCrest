import AppKit
import UniformTypeIdentifiers

/// The theme commands: putting a saved theme on the Space the window shows,
/// saving that Space's looks as a theme, and theme files in and out.
extension BrowserCommandActions {
    // MARK: - Actions - Themes

    /// The Space the window shows, while it is unlocked.
    private var themedSpace: SpaceModel? {
        guard let space = browser.spaceModel(browser.selectedSpaceID), !spaceAccess.isLocked(space) else { return nil }
        return space
    }

    /// Puts the saved theme `id` on the Space the window shows, which wears
    /// it from then on.
    func applySavedTheme(_ id: UUID) {
        guard let space = themedSpace else { return }
        let library = BrowserThemeLibrary.shared
        if let problem = library.choose(id, for: space.id, in: browser) {
            chrome.showNotice(BrowserNotice(message: problem, systemImage: "exclamationmark.triangle.fill"))
        } else if let name = library.entry(id)?.name {
            chrome.showNotice(
                BrowserNotice(message: String(localized: "Theme “\(name)” Applied"), systemImage: "paintpalette"))
        }
    }

    /// Saves the looks of the Space the window shows as a theme named for
    /// it, which the Space wears from then on.
    func saveSpaceTheme() {
        guard let space = themedSpace else { return }
        BrowserThemeLibrary.shared.saveAsTheme(space)
        chrome.showNotice(BrowserNotice(message: String(localized: "Theme Saved"), systemImage: "paintpalette"))
    }

    /// Asks for theme files and saves each in the library.
    func importTheme() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Import Theme")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = true
        panel.begin { [chrome] response in
            guard response == .OK else { return }
            MainActor.assumeIsolated {
                let imported = panel.urls.filter { (try? BrowserThemeLibrary.shared.importFile(at: $0)) != nil }
                chrome.showNotice(
                    imported.isEmpty
                        ? BrowserNotice(
                            message: String(localized: "That file is not an Arma theme."),
                            systemImage: "exclamationmark.triangle.fill")
                        : BrowserNotice(message: String(localized: "Theme Imported"), systemImage: "paintpalette"))
            }
        }
    }

    /// Writes the looks of the Space the window shows to a theme file.
    func exportTheme() {
        guard let space = themedSpace else { return }
        let theme = BrowserThemeLibrary.theme(of: space, named: space.settings.name)
        let panel = NSSavePanel()
        panel.title = String(localized: "Export Theme")
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(space.settings.name).json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? theme.json().write(to: url, options: .atomic)
        }
    }
}
