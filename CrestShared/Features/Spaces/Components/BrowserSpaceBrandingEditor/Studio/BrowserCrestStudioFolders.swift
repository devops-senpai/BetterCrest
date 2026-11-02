import SwiftUI

/// The Space's folder colors: the color a folder without its own wears, the
/// color of its back face, the line drawn around it, and how strongly folders
/// tint their rows. Its Reset puts them back to the starting look's.
struct BrowserCrestStudioFolders: View {
    let context: BrowserCrestStudioContext
    /// Whether the rows sit in a settings section of their own, as in the
    /// Forge, rather than in a Studio group.
    var isEmbedded = false

    // A chosen color is never the default, whatever look the Space opened with.
    private var color: CrestSettingValue<BrandColor?> { context.setting(\.folderColor, default: nil) }
    private var backColor: CrestSettingValue<BrandColor?> { context.setting(\.folderBackColor, default: nil) }
    /// No outline unless one is chosen.
    private var outlineColor: CrestSettingValue<BrandColor?> { context.setting(\.folderOutlineColor, default: nil) }
    private var intensity: CrestSettingValue<Double> { context.setting(\.folderColorIntensity, default: 0) }

    private var resets: [CrestResettableSetting] {
        [
            color.resettable("Folder color"), backColor.resettable("Back color"),
            outlineColor.resettable("Outline color"), intensity.resettable("Intensity"),
        ]
    }

    var body: some View {
        if isEmbedded {
            Section {
                rows
            } header: {
                HStack {
                    Text("Folders")
                    Spacer()
                    BrowserCrestStudioResetButton(title: "Folders", settings: resets)
                }
            }
        } else {
            BrowserCrestStudioGroup(title: "Folders", systemImage: "folder", resets: resets) {
                rows
            }
        }
    }

    @ViewBuilder
    private var rows: some View {
        BrowserCrestStudioColorPickerRow(title: "Folder color", value: color, fallback: .folderDefault)
        BrowserCrestStudioColorPickerRow(
            title: "Back color", value: backColor, fallback: context.value.resolvedFolderColor.folderBackShade)
        BrowserCrestStudioColorPickerRow(
            title: "Outline color", value: outlineColor, fallback: context.value.resolvedFolderColor.folderBackShade)
        BrowserCrestStudioSlider(title: "Intensity", value: intensity)
    }
}
