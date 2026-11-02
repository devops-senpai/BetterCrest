import Foundation

/// `arma page`. The word after `page` is the tab, and the action follows it.
/// Paths are read here, against the terminal's own folder, so a script file
/// travels as its text and a capture goes where the person meant.
enum TerminalPageCommandLine: TerminalSection {
    static let name = "page"
    static let summary = "Read, capture, script and act inside a tab's page (Settings › Agents turns it on)"
    static let switches: Set<String> = ["double", "full"]
    static let usage = """
        usage: arma page <tab> <action> [options]

          info                       address, title, engine, loading and zoom
          text [--max <chars>]       the page's readable text, as Markdown
          snapshot                   the page as an outline whose elements carry uids
          screenshot [--out <file.png>] [--full] [--uid <uid>]
                                     capture what the page shows, all of it with --full,
                                     or one element; prints the PNG's path
          eval <js> | --file <path>  run an expression, or statements that return a value,
                                     in the page; prints the result as JSON
          click <uid> | <x>,<y> [--double]
          hover <uid> | <x>,<y>      a uid from snapshot, or a point in CSS pixels from
                                     the page's top left
          type <text>                type into the focused element
          fill <uid> <text>          replace a field's text, or pick a menu's option
          key <key> [--modifiers cmd,shift,option,control]
                                     press a key such as Enter, Escape, ArrowDown or a
          scroll <dx> <dy> | --to top|bottom
          wait --text <t> | --url <part> [--timeout <seconds>] | --seconds <n>
          dialog accept|dismiss [--text <reply>]
                                     answer the page's alert, confirm or prompt
          console [--since <n>]      console messages Arma kept, after sequence n
          network [--since <n>]      network requests Arma kept, after sequence n

        A tab is current (the front window's), its id, or the start of its id from
        arma tab list. Turn on Settings › Agents › Command-line page control first.

        """

    static func command(action tab: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        let verb = try arguments.take("an action after the tab, such as text or click")
        return .page(TerminalPageCommand(tab: tab, action: try action(verb, &arguments)))
    }

    // MARK: - Actions - Parsing

    private static func action(_ verb: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalPageCommand.Action
    {
        switch verb {
        case "info":
            return .info
        case "text":
            let limit = try arguments.number("max").map { Int($0) } ?? 100_000
            guard (1...2_000_000).contains(limit) else {
                throw TerminalArguments.Problem(message: "--max is between 1 and 2000000.")
            }
            return .text(limit: limit)
        case "snapshot":
            return .snapshot
        case "screenshot", "capture":
            let path = arguments.option("out").map { URL(fileURLWithPath: $0).standardizedFileURL.path }
            return .screenshot(path: path, fullPage: arguments.has("full"), uid: arguments.option("uid"))
        case "eval", "evaluate":
            if let path = arguments.option("file") {
                guard let source = try? String(contentsOfFile: path, encoding: .utf8) else {
                    throw TerminalArguments.Problem(message: "Arma could not read '\(path)'.")
                }
                return .eval(source: source)
            }
            return .eval(source: try rest(&arguments, named: "a script, or --file"))
        case "click":
            return .click(try target(try arguments.take("a uid or x,y")), double: arguments.has("double"))
        case "hover":
            return .hover(try target(try arguments.take("a uid or x,y")))
        case "type":
            return .type(text: try rest(&arguments, named: "the text to type"))
        case "fill":
            let uid = try arguments.take("a uid")
            var words: [String] = []
            while let word = arguments.takeIfPresent() { words.append(word) }
            return .fill(uid: uid, text: words.joined(separator: " "))
        case "key", "press":
            let key = try arguments.take("a key")
            var modifiers: [TerminalPageCommand.Modifier] = []
            for name in (arguments.option("modifiers") ?? "").split(separator: ",") {
                guard let modifier = TerminalPageCommand.Modifier.named(name.trimmingCharacters(in: .whitespaces))
                else {
                    throw TerminalArguments.Problem(
                        message: "--modifiers takes cmd, shift, option and control, not '\(name)'.")
                }
                modifiers.append(modifier)
            }
            return .key(key, modifiers: modifiers)
        case "scroll":
            if let edge = arguments.option("to") {
                return .scroll(.to(try TerminalArguments.choice(edge, as: TerminalPageCommand.Edge.self, for: "--to")))
            }
            let dx = try TerminalArguments.number(try arguments.take("dx and dy, or --to"), for: "dx")
            let dy = try TerminalArguments.number(try arguments.take("dy"), for: "dy")
            return .scroll(.by(dx: dx, dy: dy))
        case "wait":
            return .wait(try wait(&arguments))
        case "dialog":
            let answer = try arguments.take("accept or dismiss")
            switch answer {
            case "accept", "ok": return .dialog(accept: true, text: arguments.option("text"))
            case "dismiss", "cancel": return .dialog(accept: false, text: nil)
            default: throw TerminalArguments.Problem(message: "dialog takes accept or dismiss, not '\(answer)'.")
            }
        case "console":
            return .console(since: Int64(try arguments.number("since") ?? 0))
        case "network":
            return .network(since: Int64(try arguments.number("since") ?? 0))
        default:
            throw TerminalArguments.Problem(message: "arma page has no action '\(verb)'.")
        }
    }

    /// Where `word` aims: `x,y` in CSS pixels, or a uid.
    private static func target(_ word: String) throws(TerminalArguments.Problem) -> TerminalPageCommand.Target {
        let parts = word.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return .element(uid: word) }
        return .point(
            x: try TerminalArguments.number(String(parts[0]), for: "x"),
            y: try TerminalArguments.number(String(parts[1]), for: "y"))
    }

    private static func wait(_ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalPageCommand.Wait
    {
        let timeout = try arguments.number("timeout") ?? 10
        guard (0...300).contains(timeout) else {
            throw TerminalArguments.Problem(message: "--timeout is between 0 and 300 seconds.")
        }
        if let text = arguments.option("text") { return .text(text, timeout: timeout) }
        if let url = arguments.option("url") { return .url(url, timeout: timeout) }
        if let seconds = try arguments.number("seconds") {
            guard (0...300).contains(seconds) else {
                throw TerminalArguments.Problem(message: "--seconds is between 0 and 300.")
            }
            return .seconds(seconds)
        }
        throw TerminalArguments.Problem(message: "Give --text, --url or --seconds.")
    }

    /// The remaining words as one text, named `name` when there are none.
    private static func rest(_ arguments: inout TerminalArguments, named name: String) throws(TerminalArguments.Problem)
        -> String
    {
        var words: [String] = []
        while let word = arguments.takeIfPresent() { words.append(word) }
        guard !words.isEmpty else { throw TerminalArguments.Problem(message: "Give \(name).") }
        return words.joined(separator: " ")
    }
}
