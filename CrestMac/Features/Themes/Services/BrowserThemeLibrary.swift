import CryptoKit
import Foundation
import Observation

/// The themes a person saved on this Mac: each a theme file, in the format
/// Export Theme writes and `arma theme` reads, kept in Arma's data folder
/// under a name of its own.
///
/// The library lives in files rather than the core for now, so it neither
/// syncs nor travels with the session; a theme is put on a Space by dressing
/// the Space's looks in it, as a loaded theme file is. Which theme each Space
/// wears is this Mac's own too, in the library's links file: a Space that
/// chose a theme wears it, and editing the theme, under Themes or from a
/// Space wearing it, dresses every Space wearing it.
@Observable
@MainActor
final class BrowserThemeLibrary {
    // MARK: - Types

    /// One saved theme: its file's identity, the name the list shows, and the
    /// looks it holds.
    struct Entry: Identifiable, Equatable {
        let id: UUID
        var theme: CrestTheme

        var name: String { theme.name ?? String(localized: "Untitled Theme") }

        /// What the palette and the list show beneath the name.
        var detail: String {
            theme.dark == nil ? String(localized: "One look") : String(localized: "Light and dark looks")
        }
    }

    /// Which saved theme each Space wears, as the library's links file holds it.
    private struct Links: Codable, Equatable {
        /// Space to the theme it wears.
        var spaces: [UUID: UUID] = [:]
    }

    // MARK: - Static Variables

    /// The library of this launch's data folder.
    static let shared = BrowserThemeLibrary(directory: defaultDirectory(for: .current))

    /// How long edits rest before they are written and passed on, so a drag
    /// is one write rather than one for each sample.
    private static let settleDelay = Duration.milliseconds(400)

    // MARK: - Variables

    private(set) var entries: [Entry] = []
    private var links = Links()
    private let directory: URL?
    /// The pictures of the themes the Themes page edits, each kept under its
    /// theme's identity, as a Space's is under the Space's.
    let previewBackdrops = BrowserSpaceBackdropStore(
        directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("ArmaThemePreviews-\(UUID().uuidString)", isDirectory: true))
    @ObservationIgnored private var pendingSpaceEdits: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var pendingThemeEdits: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var picturesToCapture: Set<UUID> = []

    /// The saved themes as the command palette offers them.
    var paletteThemes: [PaletteTheme] {
        entries.map { PaletteTheme(id: $0.id, name: $0.name, detail: $0.detail) }
    }

    // MARK: - Initializers

    init(directory: URL?) {
        self.directory = directory
        reload()
        loadLinks()
        installBundledThemes()
    }

    /// The installed app's Themes folder, or, for a review launch, one kept
    /// apart from it; a launch that keeps nothing keeps its themes in memory.
    static func defaultDirectory(for environment: BrowserLaunchEnvironment) -> URL? {
        guard
            var directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent(ProductIdentity.storageDirectoryName, isDirectory: true)
                .appendingPathComponent("Themes", isDirectory: true)
        else { return nil }
        if environment.requiresIsolation {
            guard let isolationID = environment.persistentIsolationID else { return nil }
            let namespace = SHA256.hash(data: Data(isolationID.utf8)).map { String(format: "%02x", $0) }.joined()
            directory = directory.appendingPathComponent("Isolated", isDirectory: true)
                .appendingPathComponent(namespace, isDirectory: true)
        }
        return directory
    }

    // MARK: - Actions - Reading

    func entry(_ id: UUID) -> Entry? {
        entries.first { $0.id == id }
    }

    /// The saved theme Space `spaceID` wears, or nil for a look of its own.
    func themeID(of spaceID: UUID) -> UUID? {
        guard let id = links.spaces[spaceID], entry(id) != nil else { return nil }
        return id
    }

    /// The Spaces of `browser` wearing the theme `id`.
    func spaces(wearing id: UUID, in browser: BrowserStore) -> [SpaceModel] {
        browser.spaceModels.filter { links.spaces[$0.id] == id }
    }

    /// The theme a Space wears now, named `name`.
    static func theme(of space: SpaceModel, named name: String) -> CrestTheme {
        var theme = CrestTheme(look: space.settings.look, dark: space.settings.darkBranding)
        theme.name = name
        theme.backgroundImage = backgroundImage(of: space.id, in: .shared)
        return theme
    }

    /// The picture `store` keeps under `ownerID`, with how it sits, as a
    /// theme carries it.
    static func backgroundImage(of ownerID: UUID, in store: BrowserSpaceBackdropStore) -> CrestTheme.BackgroundImage? {
        guard let backdrop = store.backdrop(for: ownerID), let image = store.imageData(for: ownerID) else {
            return nil
        }
        let backing = backdrop.tabBacking
        return CrestTheme.BackgroundImage(
            data: image.data.base64EncodedString(), format: image.format, anchor: backdrop.anchor.name,
            size: backdrop.size.name, growsToWidth: backdrop.growsToWidth, growsToHeight: backdrop.growsToHeight,
            tiles: backdrop.tiles, imageOpacity: backdrop.imageOpacity, tintOpacity: backdrop.tintOpacity,
            blur: backdrop.blur, tabBacking: backing.reach.name,
            tabBackingColor: backing.color.map(CrestTheme.text) ?? CrestTheme.defaultColorWord,
            tabBackingOpacity: backing.opacity, tabBackingBlur: backing.blur)
    }

    /// How a theme's picture sits, its unnamed choices at their defaults.
    private static func placement(of image: CrestTheme.BackgroundImage) -> BrowserSpaceBackdropStore.Backdrop {
        var backdrop = BrowserSpaceBackdropStore.Backdrop(file: "")
        backdrop.anchor = BrowserSpaceBackdropStore.Anchor.all.first { $0.name == image.anchor } ?? backdrop.anchor
        backdrop.size = BrowserSpaceBackdropStore.Size.all.first { $0.name == image.size } ?? backdrop.size
        backdrop.growsToWidth = image.growsToWidth ?? backdrop.growsToWidth
        backdrop.growsToHeight = image.growsToHeight ?? backdrop.growsToHeight
        backdrop.tiles = image.tiles ?? backdrop.tiles
        backdrop.imageOpacity = image.imageOpacity ?? backdrop.imageOpacity
        backdrop.tintOpacity = image.tintOpacity ?? backdrop.tintOpacity
        backdrop.blur = image.blur ?? backdrop.blur
        var backing = backdrop.tabBacking
        backing.reach =
            BrowserSpaceBackdropStore.TabBackingReach.all.first { $0.name == image.tabBacking } ?? backing.reach
        if let text = image.tabBackingColor { backing.color = (try? CrestTheme.color(text)) ?? nil }
        backing.opacity = image.tabBackingOpacity ?? backing.opacity
        backing.blur = image.tabBackingBlur ?? backing.blur
        backdrop.tabBacking = backing
        return backdrop
    }

    /// Gives `ownerID` in `store` the theme's picture, or takes its picture
    /// away when the theme has none.
    private static func applyBackgroundImage(
        _ image: CrestTheme.BackgroundImage?, to ownerID: UUID, in store: BrowserSpaceBackdropStore
    ) throws {
        guard let image else {
            store.remove(for: ownerID)
            return
        }
        guard let data = Data(base64Encoded: image.data) else { throw CocoaError(.fileReadCorruptFile) }
        try store.setImage(data: data, format: image.format, placed: placement(of: image), for: ownerID)
    }

    /// Whether Space `space` already wears everything `theme` names: its
    /// looks, whether it has a dark one, and its picture as it sits.
    private static func wears(_ theme: CrestTheme, _ space: SpaceModel) -> Bool {
        let current = space.settings.look
        let currentDark = space.settings.darkBranding
        guard (theme.dark == nil) == (currentDark == nil),
            let (look, dark) = try? current.dressed(in: theme, dark: currentDark),
            look.normalized() == current.normalized(), dark?.normalized() == currentDark?.normalized()
        else { return false }
        let store = BrowserSpaceBackdropStore.shared
        guard let image = theme.backgroundImage else { return store.backdrop(for: space.id) == nil }
        guard let backdrop = store.backdrop(for: space.id), let data = Data(base64Encoded: image.data),
            store.imageData(for: space.id)?.data == data
        else { return false }
        return backdrop == backdrop.placed(like: placement(of: image))
    }

    // MARK: - Actions - Applying

    /// Dresses the Space `spaceID` in the saved theme `id`, answering what
    /// went wrong, or nil once its looks changed.
    func apply(_ id: UUID, to spaceID: UUID, in browser: BrowserStore) -> String? {
        guard let entry = entry(id), let space = browser.spaceModel(spaceID) else {
            return String(localized: "That theme is no longer saved.")
        }
        let current = space.settings.look
        let currentDark = space.settings.darkBranding
        do {
            var (look, dark) = try current.dressed(in: entry.theme, dark: currentDark)
            // A theme with one look takes away a dark look of the Space's own.
            if entry.theme.dark == nil { dark = nil }
            if look != current { browser.updateSpaceBranding(look.normalized(), in: spaceID) }
            if dark != currentDark { browser.updateSpaceDarkBranding(dark?.normalized(), in: spaceID) }
        } catch {
            return error.message
        }
        do {
            try Self.applyBackgroundImage(entry.theme.backgroundImage, to: spaceID, in: .shared)
        } catch {
            return String(localized: "The theme’s colors are on, but its background image could not be read.")
        }
        DiagnosticLog.themes.notice("Theme \(id) put on Space \(spaceID)")
        return nil
    }

    /// Dresses Space `spaceID` in the saved theme `id` and has it wear that
    /// theme from now on, answering what went wrong, or nil.
    func choose(_ id: UUID, for spaceID: UUID, in browser: BrowserStore) -> String? {
        pendingSpaceEdits.removeValue(forKey: spaceID)?.cancel()
        if let problem = apply(id, to: spaceID, in: browser) { return problem }
        links.spaces[spaceID] = id
        saveLinks()
        return nil
    }

    /// Saves Space `space`'s look as a new theme named for it, which it wears
    /// from now on, answering the theme's identity.
    @discardableResult
    func saveAsTheme(_ space: SpaceModel) -> UUID {
        let id = add(Self.theme(of: space, named: space.settings.name))
        links.spaces[space.id] = id
        saveLinks()
        return id
    }

    /// Has Space `space`, wearing no saved theme, wear one without changing
    /// how it looks: a saved theme it already wears in full, or else its look
    /// saved as a new theme named for it.
    func adopt(_ space: SpaceModel) {
        guard themeID(of: space.id) == nil else { return }
        let id = entries.first { Self.wears($0.theme, space) }?.id ?? saveAsTheme(space)
        links.spaces[space.id] = id
        saveLinks()
        DiagnosticLog.themes.notice("Space \(space.id) wears theme \(id)")
    }

    /// Notes that Space `spaceID`'s look was edited from the Space. Once the
    /// edits rest, they are saved over the theme it wears, and every other
    /// Space wearing it is dressed in it again.
    func spaceEdited(_ spaceID: UUID, in browser: BrowserStore) {
        guard links.spaces[spaceID] != nil else { return }
        pendingSpaceEdits[spaceID]?.cancel()
        pendingSpaceEdits[spaceID] = Task { [weak self, weak browser] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled, let self, let browser else { return }
            self.pendingSpaceEdits[spaceID] = nil
            self.settleSpaceEdit(spaceID, in: browser)
        }
    }

    private func settleSpaceEdit(_ spaceID: UUID, in browser: BrowserStore) {
        guard let id = themeID(of: spaceID), let entry = entry(id), let space = browser.spaceModel(spaceID),
            !Self.wears(entry.theme, space)
        else { return }
        replaceLooks(of: id, with: Self.theme(of: space, named: entry.name))
        pass(id, on: browser, except: spaceID)
        DiagnosticLog.themes.notice("Theme \(id) changed from Space \(spaceID)")
    }

    /// Dresses every Space wearing theme `id`, but `exception`, in it again.
    private func pass(_ id: UUID, on browser: BrowserStore, except exception: UUID? = nil) {
        for space in spaces(wearing: id, in: browser) where space.id != exception {
            _ = apply(id, to: space.id, in: browser)
        }
    }

    // MARK: - Actions - Editing

    /// Puts theme `id`'s picture, as `previewBackdrops` keeps it, ready to
    /// preview and edit.
    func preparePreview(_ id: UUID) {
        // A picture still being edited is newer in the preview than in the theme.
        guard let entry = entry(id), !picturesToCapture.contains(id) else { return }
        try? Self.applyBackgroundImage(entry.theme.backgroundImage, to: id, in: previewBackdrops)
    }

    /// Changes theme `id` now; once the edits rest it is written and every
    /// Space wearing it is dressed in it again.
    func edit(_ id: UUID, in browser: BrowserStore, _ change: (inout CrestTheme) -> Void) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        var theme = entries[index].theme
        change(&theme)
        theme.name = entries[index].theme.name
        guard theme != entries[index].theme else { return }
        entries[index].theme = theme
        settleThemeEdit(id, in: browser)
    }

    /// Notes that theme `id`'s picture changed in `previewBackdrops`; once
    /// the edits rest the theme carries it and its Spaces wear it.
    func pictureEdited(_ id: UUID, in browser: BrowserStore) {
        picturesToCapture.insert(id)
        settleThemeEdit(id, in: browser)
    }

    private func settleThemeEdit(_ id: UUID, in browser: BrowserStore) {
        pendingThemeEdits[id]?.cancel()
        pendingThemeEdits[id] = Task { [weak self, weak browser] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled, let self, let browser,
                let index = self.entries.firstIndex(where: { $0.id == id })
            else { return }
            self.pendingThemeEdits[id] = nil
            if self.picturesToCapture.remove(id) != nil {
                self.entries[index].theme.backgroundImage = Self.backgroundImage(of: id, in: self.previewBackdrops)
            }
            self.write(self.entries[index])
            self.pass(id, on: browser)
        }
    }

    // MARK: - Mutators

    /// Saves `theme` as a new entry, answering its identity.
    @discardableResult
    func add(_ theme: CrestTheme) -> UUID {
        let entry = Entry(id: UUID(), theme: theme)
        entries.append(entry)
        write(entry)
        sort()
        DiagnosticLog.themes.notice("Theme \(entry.id) saved")
        return entry.id
    }

    /// Saves each theme Arma ships with that this library has never had,
    /// under its own identity, so a new library starts with them and one
    /// the person deleted stays deleted. A theme saved under the same name
    /// counts as had.
    private func installBundledThemes() {
        guard let directory else { return }
        let record = directory.appendingPathComponent("bundled.json")
        var installed = (try? JSONDecoder().decode(Set<UUID>.self, from: Data(contentsOf: record))) ?? []
        var changed = false
        for bundled in BrowserBundledTheme.all where !installed.contains(bundled.id) {
            installed.insert(bundled.id)
            changed = true
            guard entry(bundled.id) == nil, !entries.contains(where: { $0.name == bundled.name }),
                let theme = bundled.theme
            else { continue }
            let entry = Entry(id: bundled.id, theme: theme)
            entries.append(entry)
            write(entry)
            DiagnosticLog.themes.notice("Bundled theme \(bundled.id) installed")
        }
        sort()
        guard changed else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(installed).write(to: record, options: .atomic)
    }

    /// Saves a theme of the plain look, answering its identity.
    func addNew() -> UUID {
        add(CrestTheme(look: .neutral).named(String(localized: "New Theme")))
    }

    /// Saves a copy of theme `id`, answering the copy's identity.
    func duplicate(_ id: UUID) -> UUID? {
        guard let entry = entry(id) else { return nil }
        return add(entry.theme.named(String(localized: "\(entry.name) Copy")))
    }

    /// Saves the theme file at `url` as a new entry, named for the file when
    /// it names nothing itself, answering its identity.
    func importFile(at url: URL) throws -> UUID {
        var theme = try CrestTheme(json: Data(contentsOf: url))
        if theme.name?.isEmpty ?? true { theme.name = url.deletingPathExtension().lastPathComponent }
        return add(theme)
    }

    /// Writes the entry `id` to `url` as a theme file.
    func export(_ id: UUID, to url: URL) throws {
        guard let entry = entry(id) else { return }
        try entry.theme.json().write(to: url, options: .atomic)
    }

    func rename(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].theme.name = trimmed
        write(entries[index])
        sort()
    }

    /// Replaces the looks of entry `id` with `theme`'s, keeping its name.
    func replaceLooks(of id: UUID, with theme: CrestTheme) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        var replaced = theme
        replaced.name = entries[index].theme.name
        entries[index].theme = replaced
        write(entries[index])
    }

    /// Removes theme `id`, which no Space should wear any longer.
    func remove(_ id: UUID) {
        pendingThemeEdits.removeValue(forKey: id)?.cancel()
        entries.removeAll { $0.id == id }
        links.spaces = links.spaces.filter { $0.value != id }
        saveLinks()
        previewBackdrops.remove(for: id)
        DiagnosticLog.themes.notice("Theme \(id) removed")
        guard let file = file(for: id) else { return }
        try? FileManager.default.removeItem(at: file)
    }

    /// Reads the folder again, keeping every file that holds a theme.
    func reload() {
        guard let directory,
            let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return }
        entries = files.compactMap { file in
            guard file.pathExtension == "json",
                let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
                let data = try? Data(contentsOf: file), let theme = try? CrestTheme(json: data)
            else { return nil }
            return Entry(id: id, theme: theme)
        }
        sort()
    }

    private var linksFile: URL? {
        directory?.appendingPathComponent("links.json", isDirectory: false)
    }

    private func loadLinks() {
        guard let linksFile, let data = try? Data(contentsOf: linksFile),
            let stored = try? JSONDecoder().decode(Links.self, from: data)
        else { return }
        links = stored
    }

    private func saveLinks() {
        guard let directory, let linksFile else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(links).write(to: linksFile, options: .atomic)
        } catch {
            DiagnosticLog.themes.notice("Theme links were not saved: \(DiagnosticLog.describe(error))")
        }
    }

    private func sort() {
        entries.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func file(for id: UUID) -> URL? {
        directory?.appendingPathComponent(id.uuidString + ".json", isDirectory: false)
    }

    private func write(_ entry: Entry) {
        guard let directory, let file = file(for: entry.id) else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try entry.theme.json().write(to: file, options: .atomic)
        } catch {
            DiagnosticLog.themes.notice("Theme \(entry.id) was not saved: \(DiagnosticLog.describe(error))")
        }
    }
}

extension CrestTheme {
    /// This theme named `name`.
    func named(_ name: String) -> CrestTheme {
        var theme = self
        theme.name = name
        return theme
    }
}
