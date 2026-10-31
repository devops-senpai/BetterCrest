import AppKit
import SwiftUI

/// A Space's Appearance page: the Crest Studio's Forge beside the window's
/// live sidebar, or the studio with its own preview where Settings can't show
/// that sidebar.
struct BrowserSpaceEditorView: View {
    @Environment(\.browserSettingsUsesLiveSidebar) private var usesLiveSidebar
    @Environment(\.browserSettingsTabState) private var tabState
    @State private var standaloneScroll = BrowserNativeScrollState()
    @State private var standaloneStep = BrowserCrestStudioStep.shape

    private var scrollState: BrowserNativeScrollState {
        tabState?.scroll(forKey: "space-\(space.id)-appearance") ?? standaloneScroll
    }

    let browser: BrowserStore
    let space: SpaceModel

    /// Whether the controls edit the look for dark windows, while the Space
    /// has one, rather than its light look.
    @State private var editsDark = false

    var body: some View {
        VStack(spacing: 0) {
            appearancePicker
            Group {
                if usesLiveSidebar {
                    BrowserCrestForge(branding: branding, symbol: symbol, step: forgeStep)
                } else {
                    appearanceEditor
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(
            \.browserSpaceThemeFiles,
            BrowserSpaceThemeFiles(name: space.settings.name, branding: lightBranding, darkBranding: darkBranding)
                .actions
        )
        .accessibilityIdentifier("space-customization-controls")
    }

    /// Whether the Space keeps a look of its own for dark windows, and which
    /// of the two the controls edit.
    private var appearancePicker: some View {
        HStack(spacing: 16) {
            Toggle("Dark look", isOn: hasDarkLook)
                .toggleStyle(.switch)
                .help("Give this Space a look of its own while windows are dark")
            if hasDarkLook.wrappedValue {
                Picker("Editing", selection: $editsDark) {
                    Text("Light").tag(false)
                    Text("Dark").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    /// Whether the Space has a dark look: turning it on starts one from the
    /// light look, turning it off lets it go.
    private var hasDarkLook: Binding<Bool> {
        Binding(
            get: { space.settings.darkBranding != nil },
            set: { wanted in
                browser.updateSpaceDarkBranding(wanted ? space.settings.look : nil, in: space.id)
                if !wanted { editsDark = false }
            })
    }

    private var appearanceEditor: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 620
            let dense = geometry.size.height < 640
            HStack(alignment: .top, spacing: 0) {
                if wide {
                    VStack(spacing: 16) {
                        BrowserCrestStudioPreview(
                            branding: branding.wrappedValue, symbol: symbol.wrappedValue,
                            name: space.settings.name, space: BrowserSpaceAppearance(space: space),
                            heroSize: geometry.size.height < 480 ? 96 : 140,
                            sidebarHeight: max(100, min(230, geometry.size.height - 300)))
                        Spacer(minLength: 0)
                    }
                    .frame(width: min(280, geometry.size.width * 0.32))
                    .padding(14)
                }
                ScrollView {
                    BrowserSpaceBrandingEditor(
                        branding: branding, symbol: symbol, previewName: space.settings.name,
                        compact: !wide, showsPreview: !wide, editableName: name
                    )
                    .id(space.id)
                    .padding(dense ? 14 : 20)
                    .frame(maxWidth: 680, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .browserNativeScrollState(scrollState)
                .contentMargins(.trailing, 12, for: .scrollContent)
                .defaultScrollAnchor(.top, for: .initialOffset)
            }
        }
    }

    private var forgeStep: Binding<BrowserCrestStudioStep> {
        Binding(
            get: { tabState?.forgeStep ?? standaloneStep },
            set: { if let tabState { tabState.forgeStep = $0 } else { standaloneStep = $0 } })
    }

    private var name: Binding<String> {
        browser.spaceNameBinding(in: space)
    }

    private var symbol: Binding<String> {
        browser.spaceSymbolBinding(in: space)
    }

    /// The look the controls edit: the dark one while that is chosen and exists.
    private var branding: Binding<SpaceBranding> {
        editsDark && space.settings.darkBranding != nil ? browser.spaceDarkBrandingBinding(in: space) : lightBranding
    }

    private var lightBranding: Binding<SpaceBranding> {
        browser.spaceBrandingBinding(in: space)
    }

    private var darkBranding: Binding<SpaceBranding?> {
        Binding(
            get: { space.settings.darkBranding },
            set: { browser.updateSpaceDarkBranding($0, in: space.id) })
    }
}
