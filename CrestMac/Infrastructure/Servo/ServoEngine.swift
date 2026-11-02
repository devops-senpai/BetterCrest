import Foundation

/// The process's one Servo instance. Servo's options are global to the
/// process, so every page shares it and its store of site data, kept in
/// `profileDirectory`, or in memory without one. Servo wakes it from any
/// thread; it spins Servo on the main thread.
@MainActor
final class ServoEngine {
    // MARK: - Static Variables

    /// The engine Servo's wake reaches, while one runs.
    private static weak var running: ServoEngine?

    // MARK: - Variables

    private let library: ServoLibrary
    let handle: OpaquePointer

    // MARK: - Initializers

    /// Starts Servo, or answers nil when it does not start.
    init?(library: ServoLibrary, profileDirectory: URL?) {
        if let profileDirectory {
            try? FileManager.default.createDirectory(at: profileDirectory, withIntermediateDirectories: true)
        }
        let wake: ServoLibrary.Wake = { _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { ServoEngine.running?.spin() } }
        }
        guard let handle = library.engineNew(profileDirectory?.path, nil, wake) else {
            DiagnosticLog.servo.error("Servo did not start")
            return nil
        }
        self.library = library
        self.handle = handle
        Self.running = self
        DiagnosticLog.servo.notice("Servo started (keeps site data: \(profileDirectory != nil))")
    }

    // MARK: - Actions - Running

    func spin() {
        library.engineSpin(handle)
    }

    /// Runs `script` in every page's documents that load from now on.
    func addUserScript(_ script: String) {
        library.engineAddUserScript(handle, script)
    }

    /// Runs the content scripts of `extensions` in the pages that load from
    /// now on.
    func apply(_ extensions: [ServoExtension]) {
        for servoExtension in extensions {
            guard let script = servoExtension.userScript else { continue }
            addUserScript(script)
            DiagnosticLog.servo.notice("Extension \(servoExtension.name) runs in Servo pages")
        }
    }

    /// Forgets every site's cookies.
    func clearCookies() {
        library.engineClearCookies(handle)
    }
}
