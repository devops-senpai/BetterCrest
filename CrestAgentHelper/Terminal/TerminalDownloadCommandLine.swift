import Foundation

/// `arma download`.
enum TerminalDownloadCommandLine: TerminalSection {
    // MARK: - Static Variables

    static let name = "download"
    static let summary = "List downloads, open or reveal their files, cancel, retry and clear them"
    static let switches: Set<String> = []
    static let usage = """
        usage: arma download <action> [options]

          list                     downloads with their id, state, progress, size and Space
          open <download>          open a finished download's file
          reveal <download>        show a finished download's file in Finder
          cancel <download>        stop a download while it runs
          retry <download>         download again one the site's choices blocked
          clear                    remove every download that ended from the list;
                                   the files stay

        A download is its id, or the start of its id from arma download list.

        """

    // MARK: - Actions - Parsing

    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        switch action {
        case "list", "ls":
            return .download(.list)
        case "open":
            return .download(.open(download: try arguments.take("a download")))
        case "reveal", "show":
            return .download(.reveal(download: try arguments.take("a download")))
        case "cancel", "stop":
            return .download(.cancel(download: try arguments.take("a download")))
        case "retry":
            return .download(.retry(download: try arguments.take("a download")))
        case "clear":
            return .download(.clear)
        default:
            throw TerminalArguments.Problem(message: "arma download has no action '\(action)'.")
        }
    }
}
