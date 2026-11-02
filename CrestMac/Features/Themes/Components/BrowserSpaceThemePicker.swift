import SwiftUI

/// The theme a Space wears, heading its Appearance page, and the other Spaces
/// wearing the same theme. Themes are edited under Settings › Themes; a Space
/// only picks one. A Space wearing none yet is given one when the page opens.
struct BrowserSpaceThemePicker: View {
    // MARK: - Variables

    let browser: BrowserStore
    let space: SpaceModel

    @State private var library = BrowserThemeLibrary.shared
    @State private var problem: String?

    private var themeID: UUID? { library.themeID(of: space.id) }

    private var currentName: String {
        themeID.flatMap(library.entry)?.name ?? String(localized: "No Theme")
    }

    /// The other Spaces wearing this Space's theme, as a sentence lists them.
    private var alsoUsedBy: String? {
        guard let themeID else { return nil }
        let names = library.spaces(wearing: themeID, in: browser).filter { $0.id != space.id }.map(\.settings.name)
        guard !names.isEmpty else { return nil }
        return String(localized: "Also used by \(names.formatted(.list(type: .and)))")
    }

    // MARK: - Actions - Presentation

    var body: some View {
        HStack(spacing: CrestSpacing.medium) {
            Text("Theme")
            Menu {
                Group {
                    ForEach(library.entries) { entry in
                        Toggle(isOn: chosen(entry.id)) {
                            Label(entry.name, systemImage: "paintpalette")
                        }
                    }
                }
                .crestMenuActionLabelStyle()
            } label: {
                Text(currentName)
            }
            .fixedSize()
            .help("The theme this Space wears; edit themes in Settings › Themes")
            .accessibilityIdentifier("space-theme-picker")
            if let alsoUsedBy {
                Text(alsoUsedBy)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let problem {
                Text(problem).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .task(id: space.id) { library.adopt(space) }
    }

    /// Whether the Space wears theme `id`; choosing one dresses the Space in it.
    private func chosen(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { themeID == id },
            set: { isOn in
                guard isOn else { return }
                problem = library.choose(id, for: space.id, in: browser)
            })
    }
}
