import SwiftUI

/// One folder's colors in place of its Space's, kept in the Space's shown
/// look under the folder's path, such as `.HomeLab.proxmox`, so a theme
/// carries them to any Space that has that folder.
struct BrowserFolderAppearanceEditor: View {
    let configuration: BrowserFolderGroupConfiguration

    private var space: SpaceModel { configuration.context.space }
    private var folder: FolderStateModel { configuration.folder }
    private var path: String { space.folderPath(of: folder) }

    /// Whether the Space shows its look for dark windows now, which is the
    /// look these colors are kept in.
    private var editsDarkLook: Bool {
        BrowserDeviceAppearanceStore.shared.shownColorScheme == .dark && space.settings.darkBranding != nil
    }

    private var look: SpaceBranding { space.settings.shownLook }

    var body: some View {
        VStack(alignment: .leading, spacing: CrestSpacing.medium) {
            VStack(alignment: .leading, spacing: CrestSpacing.extraExtraSmall) {
                Text("Folder Appearance").font(.subheadline.weight(.semibold))
                Text(verbatim: path).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Form {
                BrowserFolderColorWell(
                    title: "Folder color", value: setting(\.color), fallback: look.folderColor ?? .folderDefault)
                BrowserFolderColorWell(
                    title: "Back color", value: setting(\.backColor),
                    fallback: look.folderBackColor ?? (look.folderColor ?? .folderDefault).folderBackShade)
                BrowserFolderColorWell(
                    title: "Outline color", value: setting(\.outlineColor),
                    fallback: look.folderOutlineColor ?? (look.folderColor ?? .folderDefault).folderBackShade)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            Button("Use Space Folder Colors", systemImage: "arrow.uturn.backward") { useSpaceColors() }
                .disabled(!isOverridden)
        }
        .padding(CrestSpacing.large)
        .frame(width: 320)
        // The popover opens from the sidebar, which may draw in the Space's
        // scheme, so its text drops the Space's tone and color, and the popover
        // itself, glass included, takes the window's scheme in every engine.
        .foregroundStyle(.primary)
        .preferredColorScheme(BrowserDeviceAppearanceStore.shared.shownColorScheme)
    }

    private var isOverridden: Bool {
        look.folderOverride(of: folder, in: space) != nil || folder.color.map { $0 != .folderDefault } ?? false
    }

    private func setting(_ keyPath: WritableKeyPath<FolderColorOverride, BrandColor?>) -> CrestSettingValue<BrandColor?>
    {
        CrestSettingValue(
            Binding(
                get: { look.folderOverride(of: folder, in: space)?[keyPath: keyPath] },
                set: { color in save(look.withFolderOverride(path) { $0[keyPath: keyPath] = color }) }),
            default: nil)
    }

    private func useSpaceColors() {
        save(
            look.withFolderOverride(path) {
                $0 = FolderColorOverride(path: path, color: nil, backColor: nil, outlineColor: nil)
            })
        if folder.color.map({ $0 != .folderDefault }) ?? false {
            configuration.browser.clearFolderColor(folder.id, matching: configuration.assignment)
        }
    }

    private func save(_ next: SpaceBranding) {
        guard configuration.isCurrentAndUnlocked else { return }
        var next = next
        next.hasCustomAppearance = true
        if editsDarkLook {
            configuration.browser.updateSpaceDarkBranding(next.normalized(), in: space.id)
        } else {
            configuration.browser.updateSpaceBranding(next.normalized(), in: space.id)
        }
    }
}

/// A color well that opens a color wheel in a popover, which closes like any
/// other when the person clicks elsewhere.
private struct BrowserFolderColorWell: View {
    let title: LocalizedStringKey
    let value: CrestSettingValue<BrandColor?>
    let fallback: BrandColor

    @State private var isOpen = false

    var body: some View {
        CrestSettingRow(title, setting: value.resettable(title)) {
            Button {
                isOpen.toggle()
            } label: {
                Capsule()
                    .fill((value.wrappedValue ?? fallback).color)
                    .frame(width: 44, height: 22)
                    .overlay(Capsule().strokeBorder(.primary.opacity(0.18)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(title))
            .popover(isPresented: $isOpen, arrowEdge: .trailing) {
                BrowserColorWheelPicker(
                    color: Binding(get: { value.wrappedValue ?? fallback }, set: { value.binding.wrappedValue = $0 }),
                    title: title
                )
                .presentationCompactAdaptation(.popover)
            }
        }
    }
}
