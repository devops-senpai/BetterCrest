import CryptoKit
import Darwin
import Foundation

/// Where the helper reaches the Crest it ships inside: a Unix domain socket
/// in the person's own Crest data, one per app bundle identifier and lane, so
/// a review build never meets the installed Crest. The helper and the app
/// work it out alike from the person's real home folder, whatever home a
/// launch was given.
enum AgentSocketLocation {
    // MARK: - Types

    /// Who a socket serves: agents, through the Model Context Protocol and
    /// the person's consent, or the person at their own terminal.
    enum Lane: String, Sendable {
        case agents = "Agents"
        case commands = "Commands"
    }

    // MARK: - Static Variables

    /// The longest path a Unix domain socket address holds, less its
    /// terminator.
    static let maximumPathLength = MemoryLayout.size(ofValue: sockaddr_un().sun_path) - 1

    // MARK: - Actions - Isolation

    /// The name an isolated launch's sockets carry, from the same
    /// `CREST_ISOLATED_SESSION` and `CREST_ISOLATED_PERSISTENCE_ID` the app
    /// launched with, so a test copy that shares the installed app's bundle
    /// identifier never takes over its sockets, and a helper run with the same
    /// environment reaches the test copy. Nil for an ordinary launch.
    static func isolation(in environment: [String: String]) -> String? {
        guard environment["CREST_ISOLATED_SESSION"] == "1" else { return nil }
        let named = (environment["CREST_ISOLATED_PERSISTENCE_ID"] ?? "").lowercased().filter {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-")
        }
        return named.isEmpty ? "ephemeral" : String(named.prefix(48))
    }

    // MARK: - Actions - Paths

    /// The `lane` socket of the app whose bundle identifier is
    /// `bundleIdentifier`, or nil when there is no home folder to keep it in.
    static func path(
        forApp bundleIdentifier: String, lane: Lane = .agents,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        let bundleIdentifier = bundleIdentifier + (isolation(in: environment).map { ".isolated-\($0)" } ?? "")
        guard let home = getpwuid(getuid())?.pointee.pw_dir.map({ String(cString: $0) }), !home.isEmpty else {
            return nil
        }
        let directory = URL(fileURLWithPath: home, isDirectory: true)
            .appendingPathComponent("Library/Application Support/Arma/\(lane.rawValue)", isDirectory: true)
        let named = directory.appendingPathComponent(bundleIdentifier + ".sock", isDirectory: false).path
        if named.utf8.count <= maximumPathLength { return named }
        // A long home folder or identifier still fits as a digest.
        let digest = SHA256.hash(data: Data(bundleIdentifier.utf8)).prefix(8).map { String(format: "%02x", $0) }
            .joined()
        let hashed = directory.appendingPathComponent(digest + ".sock", isDirectory: false).path
        return hashed.utf8.count <= maximumPathLength ? hashed : nil
    }
}
