import Darwin
import Foundation

/// Arma's Servo engine, `libarma_servo.dylib`, loaded when the app carries it.
/// The library is optional: a build without it offers no Servo engine. Its C
/// API runs on the main thread, except the wake it calls from any thread when
/// Servo has work for the main thread.
@MainActor
final class ServoLibrary {
    // MARK: - Types

    typealias Wake = @convention(c) (UnsafeMutableRawPointer?) -> Void
    typealias Frame = @convention(c) (UnsafeMutableRawPointer?) -> Void
    typealias Event = @convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?) -> Void

    /// A symbol the library does not export.
    private struct MissingSymbol: Error {
        let name: String
    }

    // MARK: - Static Variables

    /// The library's file name, beside the app's other frameworks.
    static let fileName = "libarma_servo.dylib"

    /// The library this launch loaded, or nil when the app carries none.
    static let shared: ServoLibrary? = load()

    // MARK: - Variables

    let engineNew: @convention(c) (UnsafePointer<CChar>?, UnsafeMutableRawPointer?, Wake?) -> OpaquePointer?
    let engineSpin: @convention(c) (OpaquePointer?) -> Void
    let engineFree: @convention(c) (OpaquePointer?) -> Void
    let engineClearCookies: @convention(c) (OpaquePointer?) -> Void
    let engineAddUserScript: @convention(c) (OpaquePointer?, UnsafePointer<CChar>?) -> Void
    let pageNew:
        @convention(c) (
            OpaquePointer?, UnsafeMutableRawPointer?, UInt32, UInt32, Float, UnsafePointer<CChar>?,
            UnsafeMutableRawPointer?, Frame?, Event?
        ) -> OpaquePointer?
    let pageFree: @convention(c) (OpaquePointer?) -> Void
    let pagePaint: @convention(c) (OpaquePointer?) -> Void
    let pageResize: @convention(c) (OpaquePointer?, UInt32, UInt32) -> Void
    let pageSetVisible: @convention(c) (OpaquePointer?, Int32) -> Void
    let pageSetFocused: @convention(c) (OpaquePointer?, Int32) -> Void
    let pageLoad: @convention(c) (OpaquePointer?, UnsafePointer<CChar>?) -> Void
    let pageTraverse: @convention(c) (OpaquePointer?, Int32) -> Void
    let pageReload: @convention(c) (OpaquePointer?) -> Void
    let pageScroll: @convention(c) (OpaquePointer?, Double, Double, Float, Float) -> Void
    let pageMouseButton: @convention(c) (OpaquePointer?, Int32, Int32, Float, Float) -> Void
    let pageMouseMove: @convention(c) (OpaquePointer?, Float, Float) -> Void
    let pageKey: @convention(c) (OpaquePointer?, Int32, UnsafePointer<CChar>?, UInt32) -> Void

    // MARK: - Initializers

    private init(handle: UnsafeMutableRawPointer) throws {
        func symbol<Function>(_ name: String) throws -> Function {
            guard let address = dlsym(handle, name) else { throw MissingSymbol(name: name) }
            return unsafeBitCast(address, to: Function.self)
        }
        engineNew = try symbol("arma_servo_engine_new")
        engineSpin = try symbol("arma_servo_engine_spin")
        engineFree = try symbol("arma_servo_engine_free")
        engineClearCookies = try symbol("arma_servo_engine_clear_cookies")
        engineAddUserScript = try symbol("arma_servo_engine_add_user_script")
        pageNew = try symbol("arma_servo_page_new")
        pageFree = try symbol("arma_servo_page_free")
        pagePaint = try symbol("arma_servo_page_paint")
        pageResize = try symbol("arma_servo_page_resize")
        pageSetVisible = try symbol("arma_servo_page_set_visible")
        pageSetFocused = try symbol("arma_servo_page_set_focused")
        pageLoad = try symbol("arma_servo_page_load")
        pageTraverse = try symbol("arma_servo_page_traverse")
        pageReload = try symbol("arma_servo_page_reload")
        pageScroll = try symbol("arma_servo_page_scroll")
        pageMouseButton = try symbol("arma_servo_page_mouse_button")
        pageMouseMove = try symbol("arma_servo_page_mouse_move")
        pageKey = try symbol("arma_servo_page_key")
    }

    // MARK: - Actions - Loading

    /// Loads the library from `ARMA_SERVO_LIBRARY`, or from the app's
    /// frameworks; nil when neither holds one that exports the whole API.
    private static func load() -> ServoLibrary? {
        let candidates = [
            ProcessInfo.processInfo.environment["ARMA_SERVO_LIBRARY"],
            Bundle.main.privateFrameworksURL?.appendingPathComponent(fileName).path,
        ].compactMap { $0 }
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            guard let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) else {
                let reason = dlerror().map { String(cString: $0) } ?? "unknown"
                DiagnosticLog.servo.error("Servo at \(path) did not load: \(reason)")
                continue
            }
            do {
                let library = try ServoLibrary(handle: handle)
                DiagnosticLog.servo.notice("Loaded Servo from \(path)")
                return library
            } catch {
                DiagnosticLog.servo.error("Servo at \(path) lacks \(String(describing: error))")
            }
        }
        return nil
    }
}
