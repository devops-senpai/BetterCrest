import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Settings › Themes: the themes saved on this Mac in a list, with buttons
/// beneath it to make, copy and remove one and bring theme files in and out;
/// beside it the chosen theme's name, its dark look, and the Forge's sidebar
/// steps with its picture and tab backing. Editing a theme here edits that
/// theme, and dresses every Space wearing it again.
struct BrowserThemesSettingsPane: View {
    // MARK: - Variables

    let browser: BrowserStore

    @State private var library = BrowserThemeLibrary.shared
    @State private var selection: UUID?
    @State private var name = ""
    /// Whether the controls edit the theme's dark look rather than its light one.
    @State private var editsDark = false
    @State private var step = BrowserCrestStudioStep.sidebar
    /// The theme waiting on the person to confirm its removal.
    @State private var notice: String?
    /// What the list button under the pointer does, named between the buttons.
    @State private var hoveredAction: LocalizedStringKey?

    /// The steps that edit what a theme carries.
    private static let themeSteps: [BrowserCrestStudioStep] = [.start, .sidebar, .other]

    private var selected: BrowserThemeLibrary.Entry? {
        selection.flatMap(library.entry)
    }

    // MARK: - Actions - Presentation

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            list
                .frame(width: 200)
                .padding(CrestSpacing.large)
            Divider()
            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { if selection == nil { selection = library.entries.first?.id } }
        .onChange(of: selection, initial: true) { previous, _ in
            if let previous { commitName(of: previous) }
            name = selected?.name ?? ""
            editsDark = false
            if let selection { library.preparePreview(selection) }
        }
        .accessibilityIdentifier("settings-form-themes")
    }

    // MARK: - List

    private var list: some View {
        VStack(spacing: 0) {
            List(library.entries, selection: $selection) { entry in
                HStack(spacing: CrestSpacing.small) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                        Text(subtitle(of: entry)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if entry.id == shownSpaceThemeID {
                        Image(systemName: "star.fill")
                            .help("The theme of the Space this window shows")
                            .accessibilityLabel("Theme of the shown Space")
                    }
                }
                .tag(entry.id)
                .contextMenu {
                    Group {
                        Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(entry.id) }
                        Button("Export Theme…", systemImage: "square.and.arrow.up") { export(entry.id) }
                        Divider()
                        Button("Delete Theme", systemImage: "trash", role: .destructive) { requestRemoval(entry.id) }
                    }
                    .crestMenuActionLabelStyle()
                }
            }
            .listStyle(.bordered)
            .overlay {
                if library.entries.isEmpty {
                    Text("No Saved Themes").foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 0) {
                glyph("plus", label: "New Theme") { selection = library.addNew() }
                glyph("plus.square.on.square", label: "Duplicate Theme") { selection.map(duplicate) }
                    .disabled(selection == nil)
                glyph("minus", label: "Delete Theme") { selection.map(requestRemoval) }
                    .disabled(selection == nil)
                Spacer(minLength: CrestSpacing.small)
                if let hoveredAction {
                    Text(hoveredAction)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: CrestSpacing.small)
                glyph("square.and.arrow.down", label: "Import Theme…") { importFiles() }
                glyph("square.and.arrow.up", label: "Export Theme…") { selection.map(export) }
                    .disabled(selection == nil)
            }
            .padding(.top, CrestSpacing.small)
            if let notice {
                Text(notice).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, CrestSpacing.small)
            }
        }
    }

    /// The theme the Space this window shows wears, which the list stars.
    private var shownSpaceThemeID: UUID? {
        library.themeID(of: browser.selectedSpaceID)
    }

    /// The Spaces wearing a theme, or what looks it holds when none does.
    private func subtitle(of entry: BrowserThemeLibrary.Entry) -> String {
        let spaces = library.spaces(wearing: entry.id, in: browser)
        return spaces.isEmpty ? entry.detail : spaces.map(\.settings.name).formatted(.list(type: .and))
    }

    private func wearers(of id: UUID) -> String {
        library.spaces(wearing: id, in: browser).map(\.settings.name).formatted(.list(type: .and))
    }

    private func glyph(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(CrestChromeButtonStyle())
        .help(label)
        .accessibilityLabel(label)
        .onHover { inside in
            if inside {
                hoveredAction = label
            } else if hoveredAction == label {
                hoveredAction = nil
            }
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editor: some View {
        if let entry = selected {
            VStack(spacing: 0) {
                header(entry)
                BrowserCrestForge(
                    branding: editsDark && entry.theme.dark != nil ? darkLook(entry.id) : lightLook(entry.id),
                    symbol: .constant(baseSpace?.settings.symbol ?? "paintpalette"), step: $step,
                    offeredSteps: Self.themeSteps
                )
                .id("\(entry.id)-\(editsDark)")
                .environment(\.browserSpaceSidebarSections, backdropSections(entry.id))
            }
        } else {
            Text("Choose a theme, or make a new one.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func header(_ entry: BrowserThemeLibrary.Entry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
                    .onSubmit { commitName(of: entry.id) }
                Toggle("Dark look", isOn: hasDarkLook(entry.id))
                    .toggleStyle(.switch)
                    .help("Give this theme a look of its own while windows are dark")
                if entry.theme.dark != nil {
                    Picker("Editing", selection: $editsDark) {
                        Text("Light").tag(false)
                        Text("Dark").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                Spacer(minLength: 0)
            }
            let spaces = library.spaces(wearing: entry.id, in: browser)
            if !spaces.isEmpty {
                Text("Used by \(spaces.map(\.settings.name).formatted(.list(type: .and)))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: BrowserCrestForgeMetrics.columnWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, BrowserSettingsLayout.formMinimumInset)
        .padding(.vertical, 10)
    }

    // MARK: - Looks

    /// The Space whose crest the editor shows the theme on: one wearing it,
    /// else the one the window shows.
    private var baseSpace: SpaceModel? {
        selection.flatMap { library.spaces(wearing: $0, in: browser).first }
            ?? browser.spaceModel(browser.selectedSpaceID)
    }

    private var baseLook: SpaceBranding {
        baseSpace?.settings.look ?? .neutral
    }

    /// Theme `id`'s light look on the base Space's crest; editing it edits the theme.
    private func lightLook(_ id: UUID) -> Binding<SpaceBranding> {
        Binding(
            get: { shownLight(id) },
            set: { look in library.edit(id, in: browser) { $0.sections = CrestTheme.Sections(look: look) } })
    }

    /// Theme `id`'s dark look, started from its light one.
    private func darkLook(_ id: UUID) -> Binding<SpaceBranding> {
        Binding(
            get: {
                let light = shownLight(id)
                guard let dark = library.entry(id)?.theme.dark else { return light }
                return (try? light.dressed(in: dark)) ?? light
            },
            set: { look in library.edit(id, in: browser) { $0.dark = CrestTheme.Sections(look: look) } })
    }

    private func shownLight(_ id: UUID) -> SpaceBranding {
        guard let theme = library.entry(id)?.theme else { return baseLook }
        return (try? baseLook.dressed(in: theme.sections)) ?? baseLook
    }

    /// Whether theme `id` has a dark look: turning it on starts one from the
    /// light look, turning it off lets it go.
    private func hasDarkLook(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { library.entry(id)?.theme.dark != nil },
            set: { wanted in
                library.edit(id, in: browser) { $0.dark = wanted ? $0.sections : nil }
                if !wanted { editsDark = false }
            })
    }

    /// Theme `id`'s picture and tab backing, edited in the library's preview store.
    private func backdropSections(_ id: UUID) -> BrowserSpaceSidebarSections {
        let target = BrowserSpaceBackdropSection.Target(
            store: library.previewBackdrops, ownerID: id, branding: shownLight(id),
            changed: { [library, browser] in library.pictureEdited(id, in: browser) })
        return BrowserSpaceSidebarSections { AnyView(BrowserSpaceBackdropSection(target: target)) }
    }

    // MARK: - Mutators

    private func commitName(of id: UUID) {
        guard let entry = library.entry(id), name != entry.name else { return }
        library.rename(id, to: name)
    }

    private func duplicate(_ id: UUID) {
        if let copy = library.duplicate(id) { selection = copy }
    }

    /// Removes theme `id`, unless a Space wears it: every Space wears a
    /// theme, so its Spaces pick another first.
    private func requestRemoval(_ id: UUID) {
        guard library.entry(id) != nil else { return }
        guard library.spaces(wearing: id, in: browser).isEmpty else {
            notice = String(localized: "\(wearers(of: id)) uses this theme; choose another for it first.")
            return
        }
        notice = nil
        library.remove(id)
        if selection == id { selection = library.entries.first?.id }
    }

    private func importFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        var last: UUID?
        for url in panel.urls {
            last = (try? library.importFile(at: url)) ?? last
        }
        notice = last == nil ? String(localized: "That file is not an Arma theme.") : nil
        if let last { selection = last }
    }

    private func export(_ id: UUID) {
        guard let entry = library.entry(id) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(entry.name).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try library.export(id, to: url) } catch { notice = error.localizedDescription }
    }
}
