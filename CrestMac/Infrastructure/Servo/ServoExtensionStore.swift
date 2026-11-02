import CryptoKit
import Foundation
import Observation

/// The WebExtensions installed for Servo, each unpacked in a folder of its
/// own. Installing one unpacks a Firefox add-on (`.xpi`) or copies an
/// unpacked extension's folder; Servo runs an extension's content scripts in
/// pages that load after it is installed, and stops once it is removed and
/// Servo next starts.
@MainActor
@Observable
final class ServoExtensionStore {
    // MARK: - Types

    enum InstallError: LocalizedError {
        case unreadable
        case nothingToRun(String)

        var errorDescription: String? {
            switch self {
            case .unreadable: String(localized: "The extension has no readable manifest.")
            case .nothingToRun(let name): String(localized: "\(name) has no content scripts Servo can run.")
            }
        }
    }

    // MARK: - Static Variables

    static let shared = ServoExtensionStore(directory: defaultDirectory(for: .current))

    // MARK: - Variables

    /// Where the extensions are unpacked, or nil for a launch that keeps none.
    private let directory: URL?
    private(set) var extensions: [ServoExtension] = []
    /// Hears each extension as it is installed, so a running Servo applies it.
    @ObservationIgnored var installed: ((ServoExtension) -> Void)?

    // MARK: - Initializers

    init(directory: URL?) {
        self.directory = directory
        reload()
    }

    /// The installed app's Servo extensions folder, or for a review launch one
    /// kept apart from it; a launch that keeps nothing keeps none.
    static func defaultDirectory(for environment: BrowserLaunchEnvironment) -> URL? {
        guard
            var directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent(ProductIdentity.storageDirectoryName, isDirectory: true)
                .appendingPathComponent("ServoExtensions", isDirectory: true)
        else { return nil }
        if environment.requiresIsolation {
            guard let isolationID = environment.persistentIsolationID else { return nil }
            let namespace = SHA256.hash(data: Data(isolationID.utf8)).map { String(format: "%02x", $0) }.joined()
            directory = directory.appendingPathComponent("Isolated", isDirectory: true)
                .appendingPathComponent(namespace, isDirectory: true)
        }
        return directory
    }

    // MARK: - Actions - Extensions

    /// Whether this launch can keep extensions.
    var canInstall: Bool { directory != nil }

    /// Installs the add-on or unpacked extension at `source`, replacing one
    /// installed from a file of the same name.
    @discardableResult
    func install(from source: URL) throws -> ServoExtension {
        guard let directory else { throw InstallError.unreadable }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = source.deletingPathExtension().lastPathComponent
        let staging = directory.appendingPathComponent(".installing-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        var isFolder: ObjCBool = false
        FileManager.default.fileExists(atPath: source.path, isDirectory: &isFolder)
        if isFolder.boolValue {
            try FileManager.default.copyItem(at: source, to: staging)
        } else {
            try Self.unzip(source, into: staging)
        }
        guard let candidate = ServoExtension(folder: staging) else { throw InstallError.unreadable }
        guard candidate.userScript != nil else { throw InstallError.nothingToRun(candidate.name) }
        let destination = directory.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: staging, to: destination)
        reload()
        guard let installed = extensions.first(where: { $0.id == name }) else { throw InstallError.unreadable }
        DiagnosticLog.servo.notice("Installed extension \(installed.name) \(installed.version)")
        self.installed?(installed)
        return installed
    }

    func remove(_ servoExtension: ServoExtension) {
        try? FileManager.default.removeItem(at: servoExtension.folder)
        DiagnosticLog.servo.notice("Removed extension \(servoExtension.name)")
        reload()
    }

    private func reload() {
        guard let directory,
            let folders = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        else {
            extensions = []
            return
        }
        extensions = folders.compactMap(ServoExtension.init(folder:))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func unzip(_ archive: URL, into folder: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, folder.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw InstallError.unreadable }
    }
}
