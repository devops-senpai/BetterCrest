import AppKit

/// `arma download`, run in the app over the core's download records through
/// the same download center calls the sidebar's Downloads list makes.
extension TerminalDownloadCommand {
    // MARK: - Types

    private typealias Refusal = BrowserMacTerminal.Refusal

    /// One download with the Space whose profile it belongs to.
    private struct FoundDownload {
        let item: DownloadState
        let space: SpaceModel
    }

    private struct DownloadRow: Encodable {
        let id: UUID
        let file: String
        let state: String
        let progress: Double
        let bytesReceived: Int64
        let totalBytes: Int64?
        let space: String
        let destination: String?
        let message: String?
        let createdAt: Date
    }

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        let center = terminal.application.pages.downloadCenter
        switch self {
        case .list:
            return list(Self.downloads(in: terminal))
        case .open(let reference):
            let file = try Self.file(of: try Self.download(reference, in: terminal))
            NSWorkspace.shared.open(file)
            return TerminalOutput(text: "Opened \(file.lastPathComponent).")
        case .reveal(let reference):
            let file = try Self.file(of: try Self.download(reference, in: terminal))
            NSWorkspace.shared.activateFileViewerSelecting([file])
            return TerminalOutput(text: "Showing \(file.lastPathComponent) in Finder.")
        case .cancel(let reference):
            let found = try Self.download(reference, in: terminal)
            guard found.item.phase.isLive else { throw Refusal("\(found.item.filename) is not downloading.") }
            center.cancel(found.item.id)
            return TerminalOutput(text: "Canceled \(found.item.filename).")
        case .retry(let reference):
            let found = try Self.download(reference, in: terminal)
            guard found.item.phase.canRetry else {
                throw Refusal(
                    "Arma retries only a download the site's choices blocked; download \(found.item.filename) again from its page."
                )
            }
            let access = terminal.application.spaceAccess
            let retried = center.retryAutomaticDownload(found.item.id, matching: found.space.identity.assignment) {
                terminal.browser.unlockedSpace(matching: $0, accessController: access) != nil
            }
            guard retried else { throw Refusal("Arma could not retry \(found.item.filename).") }
            return TerminalOutput(text: "Retrying \(found.item.filename).")
        case .clear:
            let ended = Self.downloads(in: terminal).filter { !$0.item.phase.isLive }
            for found in ended { center.clear(found.item.id) }
            let cleared = ended.filter { center.item($0.item.id) == nil }.count
            return TerminalOutput(
                text: cleared == 1 ? "Cleared 1 download." : "Cleared \(cleared) downloads.",
                value: ["cleared": cleared])
        }
    }

    // MARK: - Actions - Listing

    @MainActor
    private func list(_ downloads: [FoundDownload]) -> TerminalOutput {
        let rows = downloads.map { found in
            DownloadRow(
                id: found.item.id, file: found.item.filename, state: found.item.phase.name,
                progress: found.item.progress, bytesReceived: found.item.telemetry.bytesReceived,
                totalBytes: found.item.telemetry.totalBytes, space: found.space.settings.name,
                destination: found.item.destinationURL?.path, message: found.item.message,
                createdAt: found.item.createdAt)
        }
        let text =
            rows.isEmpty
            ? "No downloads."
            : BrowserMacTerminal.table(
                ["ID", "STATE", "DONE", "SIZE", "SPACE", "FILE"],
                rows.map { row in
                    [
                        BrowserMacTerminal.short(row.id), row.state, "\(Int((row.progress * 100).rounded()))%",
                        Self.size(row), row.space, row.file,
                    ]
                })
        return TerminalOutput(text: text, value: ["downloads": rows])
    }

    /// `row`'s size, as the bytes received of the whole when it is known.
    private static func size(_ row: DownloadRow) -> String {
        let received = ByteCountFormatter.string(fromByteCount: row.bytesReceived, countStyle: .file)
        guard let total = row.totalBytes else { return row.bytesReceived > 0 ? received : "-" }
        let whole = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        return row.bytesReceived >= total ? whole : "\(received) of \(whole)"
    }

    // MARK: - Actions - Finding

    /// Every download of an unlocked Space, newest first.
    @MainActor
    private static func downloads(in terminal: BrowserMacTerminal) -> [FoundDownload] {
        let spaces = terminal.spaces.filter { !terminal.application.spaceAccess.isLocked($0) }
        return terminal.application.pages.downloadCenter.items.compactMap { item in
            spaces.first { $0.profileID == item.profileID }.map { FoundDownload(item: item, space: $0) }
        }.sorted { $0.item.createdAt > $1.item.createdAt }
    }

    /// The download `reference` names: its identifier or the start of it.
    @MainActor
    private static func download(_ reference: String, in terminal: BrowserMacTerminal) throws(Refusal)
        -> FoundDownload
    {
        let wanted = reference.trimmingCharacters(in: .whitespaces).lowercased()
        guard wanted.count >= 4 else { throw Refusal("Give at least 4 characters of the download's id.") }
        let matches = downloads(in: terminal).filter { $0.item.id.uuidString.lowercased().hasPrefix(wanted) }
        switch matches.count {
        case 1: return matches[0]
        case 0: throw Refusal("No download's id starts with '\(reference)'. Run arma download list.")
        default: throw Refusal("\(matches.count) downloads' ids start with '\(reference)'. Give more of it.")
        }
    }

    /// The file finished download `found` saved, while it is still there.
    private static func file(of found: FoundDownload) throws(Refusal) -> URL {
        guard found.item.phase.isComplete, let file = found.item.destinationURL else {
            throw Refusal("\(found.item.filename) has not finished downloading.")
        }
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw Refusal("\(file.lastPathComponent) is no longer at \(file.deletingLastPathComponent().path).")
        }
        return file
    }
}
