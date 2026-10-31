import Darwin
import Foundation

/// The helper's link to the Crest it ships inside for one command the person
/// runs: connect, send the request, read the one answer, and hang up.
struct CommandAppLink {
    // MARK: - Types

    /// Why a command reached no Crest.
    enum Failure: Error {
        /// Crest is not running, or this launch offers no commands socket.
        case unreachable
        /// Crest hung up before it answered.
        case closed

        /// What the person reads at the terminal.
        var message: String {
            switch self {
            case .unreachable:
                "Arma isn't running. Open Arma, then run the command again."
            case .closed:
                "Arma closed the connection before it answered."
            }
        }
    }

    // MARK: - Variables

    let path: String?

    // MARK: - Actions - Commands

    /// Sends `request` and answers what Crest answered. Throws a `Failure`
    /// when Crest could not be reached or hung up.
    func send(_ request: CommandLinkRequest) async throws -> CommandLinkResponse {
        guard let path, let descriptor = AgentAppLink.connect(path) else { throw Failure.unreachable }
        let channel = AgentLineChannel(input: descriptor, output: descriptor)
        defer { channel.close() }
        guard let line = try? JSONEncoder().encode(request), channel.send(line) else { throw Failure.unreachable }
        for await answer in channel.lines() {
            if let response = try? JSONDecoder().decode(CommandLinkResponse.self, from: answer) { return response }
        }
        throw Failure.closed
    }
}
