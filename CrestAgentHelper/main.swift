import Darwin
import Foundation

// bettercrest, the helper that reaches the Crest it ships inside:
//
//   bettercrest mcp
//   bettercrest theme --space <name> [options]
//
// `mcp` speaks the Model Context Protocol over its standard streams for an
// agent, and needs Crest running with agents turned on. `theme` dresses one
// Space from the terminal, and needs only Crest running.

let usage = "usage: bettercrest mcp\n       bettercrest theme --space <name> [options]\n"
let arguments = Array(CommandLine.arguments.dropFirst())

/// The `lane` socket of the Crest this helper ships inside, at
/// BetterCrest.app/Contents/Helpers/bettercrest, unless a review run names one.
@MainActor func socketPath(lane: AgentSocketLocation.Lane) -> String? {
    if let index = arguments.firstIndex(of: "--socket"), arguments.indices.contains(index + 1) {
        return arguments[index + 1]
    }
    guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else { return nil }
    let app = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    guard app.pathExtension == "app", let identifier = Bundle(url: app)?.bundleIdentifier else { return nil }
    return AgentSocketLocation.path(forApp: identifier, lane: lane)
}

signal(SIGPIPE, SIG_IGN)
switch arguments.first {
case "mcp":
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    let streams = AgentLineChannel(input: STDIN_FILENO, output: STDOUT_FILENO)
    let endpoint = AgentHelperEndpoint(
        output: streams, link: AgentAppLink(path: socketPath(lane: .agents)), version: version)
    for await line in streams.lines() {
        await endpoint.receive(line)
    }
    exit(0)
case "theme":
    let command: ThemeCommandLine
    do {
        command = try ThemeCommandLine(arguments: Array(arguments.dropFirst()))
    } catch let problem as ThemeCommandLine.Problem {
        FileHandle.standardError.write(Data((problem.message + "\n\n" + ThemeCommandLine.usage).utf8))
        exit(64)
    }
    exit(await command.run(over: CommandAppLink(path: socketPath(lane: .commands))))
default:
    FileHandle.standardError.write(Data(usage.utf8))
    exit(64)
}
