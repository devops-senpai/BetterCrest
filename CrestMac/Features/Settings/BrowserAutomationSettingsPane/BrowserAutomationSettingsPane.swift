import AppKit
import SwiftUI

/// Settings › Automation: whether testing frameworks may drive Arma's
/// Chromium engine, which profile they drive, which of its tabs they see,
/// the port they connect to, and how to connect each one.
struct BrowserAutomationSettingsPane: View {
    // MARK: - Types

    /// The person's profiles, each named by the Spaces that browse in it.
    private struct ProfileChoice: Identifiable {
        let id: UUID
        let spaces: [SpaceModel]
    }

    // MARK: - Variables

    let browser: BrowserStore

    @State private var preferences = BrowserAutomationPreferences.shared
    @State private var portText = ""

    private var values: BrowserAutomationPreferences.Values { preferences.values }

    /// The version of Arma's Chromium, which a ChromeDriver must match.
    private var driverVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CrestChromiumEngineVersion") as? String
            ?? String(localized: "matching Arma's Chromium")
    }

    private var profiles: [ProfileChoice] {
        var order: [UUID] = []
        var spaces: [UUID: [SpaceModel]] = [:]
        for space in browser.spaceModels {
            if spaces[space.profileID] == nil { order.append(space.profileID) }
            spaces[space.profileID, default: []].append(space)
        }
        return order.map { ProfileChoice(id: $0, spaces: spaces[$0] ?? []) }
    }

    // MARK: - Actions - Presentation

    var body: some View {
        BrowserSettingsPane(.automation) {
            Section {
                Toggle(
                    "Allow testing frameworks",
                    isOn: Binding(get: { values.isOn }, set: { preferences.setOn($0) }))
                if preferences.needsRestart {
                    LabeledContent {
                        Button("Restart Arma") { preferences.restart() }
                    } label: {
                        Label("Restart Arma to apply these changes.", systemImage: "arrow.clockwise.circle.fill")
                            .foregroundStyle(.orange)
                    }
                } else if preferences.launched.isOn {
                    LabeledContent("Listening on", value: "127.0.0.1:\(preferences.launched.port)")
                }
            } footer: {
                CrestFormFootnote(
                    "Playwright, Puppeteer, Selenium and other tools on this Mac can drive Arma’s Chromium tabs in the profile below, and read the sites signed in there. Only programs on this Mac can connect."
                )
            }
            Section {
                Picker("Profile", selection: Binding(get: { values.profile }, set: { preferences.setProfile($0) })) {
                    Text("Ephemeral").tag(BrowserAutomationPreferences.Profile.ephemeral)
                    ForEach(profiles) { profile in
                        Text(verbatim: profile.spaces.map(\.settings.name).joined(separator: ", "))
                            .tag(BrowserAutomationPreferences.Profile.profile(profile.id))
                    }
                }
                Picker("Tabs it can see", selection: Binding(get: { values.tabs }, set: { preferences.setTabs($0) })) {
                    ForEach(BrowserAutomationPreferences.TabReach.allCases) { reach in
                        Text(reach.title).tag(reach)
                    }
                }
                .disabled(values.profile == .ephemeral)
                LabeledContent("Port") {
                    TextField(
                        "Port", text: $portText, prompt: Text(verbatim: "\(BrowserAutomationPreferences.defaultPort)")
                    )
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .onSubmit(applyPort)
                }
            } footer: {
                CrestFormFootnote(
                    values.profile == .ephemeral
                        ? "Ephemeral starts empty, with no sign-ins, and is forgotten when automation stops or Arma quits."
                        : "Its tools see only that profile’s Spaces, never your other profiles."
                )
            }
            .disabled(!values.isOn)
            Section {
                ForEach(BrowserAutomationFramework.all) { framework in
                    BrowserAutomationFrameworkRow(
                        framework: framework, setup: framework.setup(values.port, driverVersion))
                }
            } header: {
                Text("Setup")
            } footer: {
                CrestFormFootnote(
                    "Selenium, WebdriverIO and Katalon connect through ChromeDriver \(driverVersion). WebKit pages can’t be driven by these tools."
                )
            }
        }
        .onAppear { portText = "\(values.port)" }
        .onChange(of: values, initial: true) { recordHost() }
        .accessibilityIdentifier("automation-settings")
    }

    /// The Space the person is using hosts an Ephemeral profile's tabs.
    private func recordHost() {
        preferences.recordHost(fallback: (browser.shownSpace ?? browser.spaceModels.first)?.profileID)
    }

    private func applyPort() {
        guard let port = Int(portText), BrowserAutomationPreferences.ports.contains(port) else {
            portText = "\(values.port)"
            return
        }
        preferences.setPort(port)
    }
}

/// One framework's setup, shown on request, with a button that copies it.
private struct BrowserAutomationFrameworkRow: View {
    let framework: BrowserAutomationFramework
    let setup: String

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: CrestSpacing.small) {
                Text(verbatim: setup)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Copy", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(setup, forType: .string)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(CrestChromeButtonStyle())
                .help("Copy")
            }
            .padding(.vertical, CrestSpacing.extraSmall)
        } label: {
            LabeledContent {
                Text(verbatim: framework.language).foregroundStyle(.secondary)
            } label: {
                Text(verbatim: framework.name)
                Text(framework.summary)
            }
        }
    }
}
