import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The WebExtensions installed for Servo, with a way to install a Firefox
/// add-on or an unpacked extension and to remove one. Servo runs only an
/// extension's content scripts and styles.
struct BrowserServoExtensionsSection: View {
    // MARK: - Variables

    let store: ServoExtensionStore
    @State private var failure: String?

    // MARK: - Actions - Presentation

    var body: some View {
        Section {
            if store.extensions.isEmpty {
                Text("No extensions").foregroundStyle(.secondary)
            }
            ForEach(store.extensions) { servoExtension in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(servoExtension.name)
                        Text(
                            servoExtension.isPartial
                                ? String(localized: "\(servoExtension.version) · Page scripts only")
                                : servoExtension.version
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Remove Extension", systemImage: "minus.circle") { store.remove(servoExtension) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .help("Remove this extension")
                }
            }
            HStack {
                Spacer()
                Button("Install Extension…") { chooseExtension() }
                    .disabled(!store.canInstall)
            }
            if let failure { Text(failure).foregroundStyle(.red) }
        } header: {
            Text("Servo extensions")
        } footer: {
            CrestFormFootnote(
                "Servo runs an extension’s page scripts and styles. Removing one takes effect when Arma restarts.")
        }
    }

    // MARK: - Actions - Installing

    private func chooseExtension() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "xpi") ?? .zip, .zip, .folder]
        panel.message = String(localized: "Choose a Firefox add-on (.xpi) or an unpacked extension’s folder.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.install(from: url)
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }
}
