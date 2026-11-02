import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The picture behind a sidebar and window, and the backing under the
/// sidebar's tabs: the picture, the corner it holds to, how big it is drawn,
/// how strongly it shows, how strongly the colors lie over it and how soft it
/// is; then where the backing lies, its color, how strongly it shows and how
/// frosted the picture is behind it. Sections of the Forge's Sidebar step,
/// for a Space or for a saved theme. Kept on this Mac only.
struct BrowserSpaceBackdropSection: View {
    // MARK: - Types

    /// Where the controls read and write: a Space's picture in the shared
    /// store, or a theme's in the library's preview store, under its owner's
    /// identity; the look its preview wears; and what to do after each change.
    struct Target {
        let store: BrowserSpaceBackdropStore
        let ownerID: UUID
        let branding: SpaceBranding
        let changed: @MainActor () -> Void
    }

    // MARK: - Variables

    let target: Target

    @State private var problem: String?
    @State private var choosesBackingColor = false
    @Environment(\.colorScheme) private var colorScheme

    private var store: BrowserSpaceBackdropStore { target.store }

    private var backdrop: BrowserSpaceBackdropStore.Backdrop? { store.backdrop(for: target.ownerID) }

    // MARK: - Actions - Presentation

    var body: some View {
        Section("Background Image") {
            HStack(spacing: CrestSpacing.medium) {
                preview
                VStack(alignment: .leading, spacing: CrestSpacing.small) {
                    Button(backdrop == nil ? "Choose Image…" : "Change Image…", action: chooseImage)
                    if backdrop != nil {
                        Button("Remove Image", role: .destructive) {
                            store.remove(for: target.ownerID)
                            target.changed()
                        }
                    }
                    if let problem {
                        Text(problem).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if let backdrop {
                Picker("Anchor", selection: binding(\.anchor, backdrop.anchor)) {
                    ForEach(BrowserSpaceBackdropStore.Anchor.all) { anchor in
                        Text(anchor.title).tag(anchor)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Size", selection: binding(\.size, backdrop.size)) {
                    ForEach(BrowserSpaceBackdropStore.Size.all) { size in
                        Text(size.title).tag(size)
                    }
                }
                if backdrop.size == .original {
                    LabeledContent("Grow to fit") {
                        HStack(spacing: CrestSpacing.medium) {
                            Toggle("Width", isOn: binding(\.growsToWidth, backdrop.growsToWidth))
                            Toggle("Height", isOn: binding(\.growsToHeight, backdrop.growsToHeight))
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                Toggle("Repeat", isOn: binding(\.tiles, backdrop.tiles))
                slider("Image", value: binding(\.imageOpacity, backdrop.imageOpacity))
                slider("Space colors", value: binding(\.tintOpacity, backdrop.tintOpacity))
                slider("Blur", value: binding(\.blur, backdrop.blur))
            }
        }
        if let backdrop {
            tabBackingSection(backdrop.tabBacking)
        }
    }

    /// The layer under the sidebar's tabs, which only a picture needs.
    @ViewBuilder
    private func tabBackingSection(_ backing: BrowserSpaceBackdropStore.TabBacking) -> some View {
        Section("Tab Backing") {
            Picker("Tab backing", selection: binding(\.tabBacking.reach, backing.reach)) {
                ForEach(BrowserSpaceBackdropStore.TabBackingReach.all) { reach in
                    Text(reach.title).tag(reach)
                }
            }
            if backing.reach != .off {
                LabeledContent("Color") {
                    HStack(spacing: CrestSpacing.medium) {
                        Picker("Color", selection: automaticColor(backing)) {
                            Text("Automatic").tag(true)
                            Text("Custom").tag(false)
                        }
                        .labelsHidden()
                        .fixedSize()
                        colorWell(backing)
                    }
                }
                slider("Opacity", value: binding(\.tabBacking.opacity, backing.opacity))
                slider("Blur", value: binding(\.tabBacking.blur, backing.blur))
            }
        }
    }

    /// The backing's color as a well that opens the color wheel the folder
    /// colors use; choosing a color makes it the backing's own.
    private func colorWell(_ backing: BrowserSpaceBackdropStore.TabBacking) -> some View {
        let shown = backing.shownColor(over: target.branding, in: colorScheme)
        return Button {
            choosesBackingColor.toggle()
        } label: {
            Capsule()
                .fill(shown.color)
                .frame(width: 44, height: 22)
                .overlay(Capsule().strokeBorder(.primary.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .help("Tab backing color")
        .accessibilityLabel("Tab backing color")
        .popover(isPresented: $choosesBackingColor, arrowEdge: .trailing) {
            BrowserColorWheelPicker(
                color: Binding(
                    get: { store.backdrop(for: target.ownerID)?.tabBacking.color ?? shown },
                    set: { color in update { $0.tabBacking.color = color } }),
                title: "Tab Backing"
            )
        }
    }

    private func automaticColor(_ backing: BrowserSpaceBackdropStore.TabBacking) -> Binding<Bool> {
        Binding(
            get: { store.backdrop(for: target.ownerID)?.tabBacking.color == nil },
            set: { automatic in
                let shown = backing.shownColor(over: target.branding, in: colorScheme)
                update { $0.tabBacking.color = automatic ? nil : shown }
            })
    }

    private var preview: some View {
        ZStack {
            BrowserSpaceBackdropLayer(spaceID: target.ownerID, branding: target.branding, store: store)
        }
        .frame(width: 96, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.15)))
        .accessibilityHidden(true)
    }

    private func slider(_ title: LocalizedStringKey, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: 0...1) { Text(title) }
                    .labelsHidden()
                Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<BrowserSpaceBackdropStore.Backdrop, Value>, _ current: Value)
        -> Binding<Value>
    {
        Binding(
            get: { store.backdrop(for: target.ownerID)?[keyPath: keyPath] ?? current },
            set: { next in update { $0[keyPath: keyPath] = next } })
    }

    // MARK: - Mutators

    private func update(_ change: (inout BrowserSpaceBackdropStore.Backdrop) -> Void) {
        store.update(target.ownerID, change)
        target.changed()
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.setImage(at: url, for: target.ownerID)
            problem = nil
            target.changed()
        } catch {
            problem = String(localized: "That file is not an image Arma can show.")
        }
    }
}
