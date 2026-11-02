# CrestAgentHelper

`arma`, the command-line helper agents run as an MCP server
(`arma mcp`). It speaks the Model Context Protocol over its standard
streams, answers discovery and the tool list itself, and hands each tool call
to the Arma app it ships inside over the agent socket. Mac only.

## Goal

Let an agent see Arma's tools even while Arma is closed, and reach the
running app only for the calls that need it.

## Contents

| File | What it is |
| --- | --- |
| `main.swift` | Entry point: argument handling and the socket it connects to |
| `AgentHelperEndpoint.swift` | The MCP endpoint over standard streams, modern and legacy protocol revisions |
| `AgentHelperMethod.swift` | The MCP methods the endpoint hears and how it answers each |
| `AgentAppLink.swift` | The socket link to the app, reconnected after Arma restarts |
| `AgentLinkResponse+AgentAppLink.swift` | Reading the app's answers off the link |
| `AgentLineChannel.swift` | Newline-delimited messages over one file descriptor |
| `ThemeCommandLine.swift` | The first form of `arma theme`, `--space <name> [options]`: changes a Space's look, and so the theme it uses |
| `CommandAppLink.swift` | The link `arma theme` and the terminal sections use to reach the running app over the commands socket |
| `Terminal/TerminalCommandLine.swift` | `arma <section> <action>`: the `TerminalSection` protocol, the list of sections, help, `--json`, and sending a command |
| `Terminal/TerminalArguments.swift` | The words after a section: values in order, `--options` and switches |
| `Terminal/Terminal*CommandLine.swift` | One section each (`space`, `tab`, `window`, `folder`, `split`, `command`, `page`, `extension`, `history`, `archive`, `download`, `settings`, `site`, `automation`, `theme`, `crest`): its usage and how its words become a command |

## Depends on

`CrestAgents/`, which holds the protocol and tool definitions and is compiled
into the same `CrestBrowserHelper` target (`project.yml`). The `Crest` target
embeds the tool in `Contents/Helpers`; for the Chromium host the packager
copies it there (`project.yml`).

## Rules

- Keep the target arm64-native (`CONTRIBUTING.md`, "Validation").
- Test copies of Arma that the helper connects to are quit, unregistered and deleted before handing off (skill, "Verification and reporting").

## Read next

`CrestAgents/CONTEXT.md`, then `HelpCenter/docs/browsing/coding-agents.md`
for what the person sees.
