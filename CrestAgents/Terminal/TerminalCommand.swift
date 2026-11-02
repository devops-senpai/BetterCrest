import Foundation

// The commands a person runs against the running Arma from their own terminal
// with `arma <section> <action>`, as they cross the commands socket. Each
// section is one typed command in a file of its own; the helper parses the
// words into it, and the app runs it and answers a `TerminalOutput`.

// MARK: - Types

/// One command from the terminal, by the part of Arma it acts on.
enum TerminalCommand: Codable, Sendable {
    case space(TerminalSpaceCommand)
    case tab(TerminalTabCommand)
    case window(TerminalWindowCommand)
    case folder(TerminalFolderCommand)
    case split(TerminalSplitCommand)
    case command(TerminalMenuCommand)
    case `extension`(TerminalExtensionCommand)
    case history(TerminalHistoryCommand)
    case archive(TerminalArchiveCommand)
    case download(TerminalDownloadCommand)
    case page(TerminalPageCommand)
    case settings(TerminalSettingsCommand)
    case site(TerminalSiteCommand)
    case automation(TerminalAutomationCommand)
    case theme(TerminalThemeCommand)
    case crest(TerminalCrestCommand)
}

/// What a terminal command answers: the lines the person reads, and the same
/// result as JSON for `--json`.
struct TerminalOutput: Codable, Sendable {
    let text: String
    let json: String?

    init(text: String, json: String? = nil) {
        self.text = text
        self.json = json
    }

    /// `value` as JSON beside `text`.
    init(text: String, value: some Encodable) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        self.text = text
        json = (try? encoder.encode(value)).flatMap { String(data: $0, encoding: .utf8) }
    }
}

/// A browser engine a person names at the terminal.
enum TerminalEngine: String, Codable, Sendable, CaseIterable {
    case chromium
    case webkit
    case servo
}
