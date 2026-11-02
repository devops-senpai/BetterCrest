import Foundation

/// `arma automation`.
enum TerminalAutomationCommandLine: TerminalSection {
    static let name = "automation"
    static let summary = "Let Playwright, Puppeteer, Selenium and others drive Arma's Chromium tabs"
    static let switches: Set<String> = []
    static let usage = """
        usage: arma automation <action> [options]

          status                 whether automation is on, what it reaches, and how to connect
          on [--profile <space|ephemeral>] [--tabs opened|all] [--port <n>]
                                 let testing frameworks connect, after Arma restarts
          off                    close the port, after Arma restarts
          set [--profile …] [--tabs …] [--port …]
                                 change what it reaches without turning it on or off
          restart                quit and reopen Arma so the settings take effect

        --profile names a Space whose profile tools drive, or ephemeral for an empty
        profile that is forgotten when Arma quits. --tabs opened lets tools see only
        the tabs they open; all lets them see the profile's existing tabs too.

        """

    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        func settings(isOn: Bool?) throws(TerminalArguments.Problem) -> TerminalCommand {
            var port: Int?
            if let number = try arguments.number("port") { port = Int(number) }
            let tabs = arguments.option("tabs")
            if let tabs, !["opened", "all"].contains(tabs) {
                throw TerminalArguments.Problem(message: "--tabs is opened or all, not '\(tabs)'.")
            }
            return .automation(.set(isOn: isOn, profile: arguments.option("profile"), tabs: tabs, port: port))
        }
        switch action {
        case "status":
            return .automation(.status)
        case "on", "enable":
            return try settings(isOn: true)
        case "off", "disable":
            return try settings(isOn: false)
        case "set":
            return try settings(isOn: nil)
        case "restart":
            return .automation(.restart)
        default:
            throw TerminalArguments.Problem(message: "arma automation has no action '\(action)'.")
        }
    }
}
