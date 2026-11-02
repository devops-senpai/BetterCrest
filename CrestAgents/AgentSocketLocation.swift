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

    // MARK: - Actions - Paths

    /// The `lane` socket of the app whose bundle identifier is
    /// `bundleIdentifier`, or nil when there is no home folder to keep it in.
    static func path(forApp bundleIdentifier: String, lane: Lane = .agents) -> String? {
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
