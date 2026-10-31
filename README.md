<div align="center">
  <h1>Arma</h1>
  <p><strong>An open source browser for Mac, iPhone, and iPad.</strong></p>
  <p>Built with SwiftUI, running Chromium and WebKit on Mac, with separate Spaces for different parts of your life.</p>
  <p>
    <a href="https://github.com/devops-senpai/BetterCrest/actions/workflows/ci.yml"><img alt="Build Arma" src="https://github.com/devops-senpai/BetterCrest/actions/workflows/ci.yml/badge.svg"></a>
    <a href="LICENSE"><img alt="MPL-2.0 license" src="https://img.shields.io/badge/license-MPL--2.0-315f93"></a>
  </p>
</div>

Arma is a fork of [Crest](https://github.com/pauljoda/Crest) by Paul Davis.
It carries Crest's main branch plus fixes, speedups and features that are
not upstream. Arma is not affiliated with or endorsed by Crest or Paul
Davis. The repository keeps the name BetterCrest; the browser is Arma. The
user guides live in this repository under `HelpCenter/docs/`.

## What Arma adds

Everything below is in Arma and not in upstream Crest. Each line is one
change; the commit of the same name has the detail.

### Features

- **Per-Space themes.** A Space's Appearance page chooses the color its folders wear and their back face, one exact text color for the sidebar, and a tint, opacity and text color for the command palette in light and dark. Each group has its own Reset.
- **A dark look per Space.** A Space can keep a second complete look that it wears while windows are dark.
- **Theme files.** Export a Space's look as JSON and load one from a file, from the Appearance page or the Space's menu. Catppuccin Latte, Frappé, Macchiato and Mocha ship as examples.
- **Emblem app icons.** Settings offers 44 more app icons, one per emblem banner in `Brand/AppIcons`, beside the default icon and its palette variants.
- **Themes from the terminal.** `arma theme --space <name>` sets any part of a look, applies or exports theme files, pairs a light and a dark file, and resets sections, over a socket only this app's own helper can use.

### Performance

- Closing, deleting or moving a large selection of tabs finishes without a pause in Spaces with thousands of tabs.
- The command palette keeps up as you type in Spaces with thousands of tabs.
- Switching to the most recent tab answers right away in Spaces with thousands of tabs.
- Keeping a window's recent tabs current checks them against the Space once instead of searching every tab for each.
- Closing and moving tabs stays quick in Spaces with many folders.
- The sidebar stays responsive with many pages loaded: a tab's row looks up only its own page.
- Renaming or navigating a tab no longer checks every open tab's saved icon.
- Following a link in a Space with a long history no longer rebuilds every visited link on the page.
- Opening a tab whose page was unloaded no longer waits for other tabs' states to finish saving.
- Saving device records writes each list through one prepared statement instead of one per row.
- Moving the pointer over pages does less work while no link preview is waiting to appear.
- The blurred page previews behind a locked Space appear sooner.
- Each Mac window brings its pages up to date once per session change instead of repeating the tab icon and password passes.
- The Now Playing widget decodes its artwork once per image instead of on every redraw.
- A page a coding agent watches records each message and request without copying everything it already kept.
- The Space previews on the setup pages ask the core to resolve the draft only when it changes.
- On iPhone and iPad, each open page's state is saved once as the app leaves the foreground instead of twice.

### Security and privacy

- Coding agents reading a page's network requests no longer see sign-in headers a site spells its own way, such as X-CSRFToken, X-Auth-Token or an API key header.
- Importing a password file with an oversized field is refused at once instead of stalling the app.
- Closing a tab a coding agent was watching frees the console messages and network requests kept for it.

### Bug fixes

- Dragging the window by the empty sidebar strip works every time; a trackpad press there often moved nothing, and a press right after a drag counted as a double-click.
- What's New in Settings lists the newest changes instead of the ones whose names sort last.
- A tab an extension closes during an engine switch stays closed instead of coming back empty.
- New tabs opened from a link, the palette, history or a local document load once instead of twice.
- Clicking a command palette row right after typing opens it, and the arrow keys move the selection once results arrive.
- Switching Spaces in Passwords settings while the previous list was still loading no longer blanks the new list.
- Notifications from background websites and extensions keep appearing after many have been dismissed.
- On iPhone, Undo in Crest Studio steps back one change at a time.
- On iPad, a page's alerts, sign-in prompts and export sheets appear in the window that shows the page.
- On iPad, a site's location request no longer waits forever when Settings opens beside the app.
- On iPad, a closed window lets go of its pages, so its memory comes back and a restored window opens its tabs.

### Repository and tooling

- The patch version is derived from history and each release note is its own file, so branches stop conflicting on every merge.
- `Scripts/sync-upstream.sh` merges upstream Crest in one step and leaves only real code conflicts to a person.
- `Scripts/sync-upstream-engine.sh` mirrors upstream's prebuilt Chromium engine for the current engine key, so the fork never builds Chromium.
- `ROUTING.md` and a `CONTEXT.md` in every folder that groups work tell a contributor or an agent what to read for each kind of change.
- `Documentation/Renaming.md` lists every place a product name lives.
- `Brand/` holds the banner artwork; `Scripts/generate-app-icon-palettes.py` turns one banner into the app icon and its palette variants, draws every other banner as an emblem icon, and writes the picker previews and Dock images.
- The version bump check runs statically, the CI whitespace gate works, and stray files no longer change the engine key.

## A browser with boundaries

Most browsers put every login, tab, and distraction into one long-lived container. Arma begins with **Spaces** instead. Give work, home, research, or a private session its own banner; Arma gives each one its own cookies, website data, history, archive, tabs, credentials, settings, and sync identity.

Switching Spaces changes more than the color of the window. It changes the browsing context.

When several Spaces should share one set of sign-ins, make them **Sub-Spaces**: each keeps its own tabs and look while the group shares cookies, history, passwords, and extensions. [Read the Sub-Spaces guide.](HelpCenter/docs/spaces/sub-spaces.md)

## Two engines on Mac

Arma for Mac opens pages in **Chromium** by default. Its engine is built on
[ungoogled-chromium](https://github.com/ungoogled-software/ungoogled-chromium),
with Google integrations removed, and runs Chrome Web Store extensions. Any
website or page can open in **WebKit** instead, which adds Reader, whole-page
translation, built-in content blocking, and FairPlay video. When a page needs
protected video, Arma switches to WebKit automatically, respecting any
unsaved-changes prompt before moving it. Choose the default engine and
per-website rules in **Settings → Engines**. iPhone and iPad use WebKit. The
[engine guide](HelpCenter/docs/browsing/engines.md) lists what each engine
supports.

## Crest Studio and Appearance

**Crest Studio** puts each Space's crest on that Space's own sidebar background. Start from a template, then step through shape, field, band, emblem, border, finish and sidebar, choosing from previews of your own crest. Every part of the crest and the sidebar has its own color, named by what it paints. Use heraldic artwork, emoji, monograms, or a searchable SF Symbols picker, and Shuffle and Undo freely.

**Appearance** lets you dock the sidebar on either edge, go borderless, adjust tab shape and scale, choose a pin layout, and tune tab and address-field colors, or let them follow each Space's accent. Start with a preset, see changes live, and reset individual settings. Choose an app icon palette, folder colors and icons, and a default page zoom from 50% to 300%.

## Browsing features

- **A sidebar with structure.** Pins for everyday sites, saved tabs with a home URL, nested folders for projects, and current tabs for what you are doing now. Select tabs, Split Views, and folders together to organize them in one step.
- **Split View.** Keep two to four live pages in a group. Resize columns on Mac and iPad; move through focused cards on iPhone.
- **Peek.** Preview a link above the current page, then close it or keep it as a tab. On Mac, drag a link into a live Peek. On iPhone and iPad, native link and image menus keep touch actions close by.
- **Quick Window on Mac.** Open a link from another app using the right Space’s signed-in session. Promote it to a regular tab when it deserves to stay. Link Routing sends matching external links to their chosen Space.
- **Shared windows on Mac.** Open another window onto the same Spaces and tabs, with its own selection. Use a disposable Blank Window for temporary tabs with your Space’s signed-in session, or create one by dragging a tab outside the window.
- **Search and commands.** Open a URL, search the web, find tabs and history in your Space, or run a command from one field. Choose custom search engines and optional suggestions. Mac shortcuts can be rebound.
- **Getting Started.** Learn tabs, pins, and folders in an interactive browser tab, with Split View practice on Mac.

## Page tools

| Capability | What it does |
| --- | --- |
| On-device translation | On iPhone, iPad, and WebKit pages, detect a page’s language, translate it, or show the original. On Chromium pages, translate selected text. Optional automatic translation uses downloaded languages. Apple may ask to download additional languages. |
| Reader and page tools | Read supported articles with fewer distractions on WebKit pages, find text, adjust zoom, share links, copy Markdown links, print, and export PDF or web archives where supported. |
| Extensions on Mac | Install Chrome Web Store extensions in each Space. They run on Chromium pages, with popups and tab-specific side panels. [Compatibility varies.](HelpCenter/docs/extensions/compatibility.md) |
| Developer tools on Mac | Preview phone, desktop, and custom viewport sizes; capture pages; open Chromium DevTools or Web Inspector for the page's engine. The toolbar appears on localhost, or on any site with **Shift-Command-I**. |
| Media | Control eligible active media from the sidebar. On Mac, keep supported videos visible with Picture in Picture, including optional automatic PiP. |
| Downloads and uploads | Follow download progress and revisit files in Downloads. Pause and resume Chromium transfers when the server supports recovery. On iPhone and iPad, upload through Photos, camera, or Files. |

## Privacy and sync

**Private Spaces** use temporary website storage and stay out of normal history, restoration, and sync. They can require device authentication and relock when Arma leaves the foreground. **Arma Passwords** keeps origin- and Space-matched credentials in the system Keychain, with authentication for sensitive access.

Site permissions and content blocking are controlled per Space. Built-in ad and tracker blocking covers iPhone, iPad, and WebKit pages; on Chromium pages, install a blocking extension. Closed and cleaned-up tabs go to a recoverable Archive, subject to your retention settings. **Keep Loaded** protects a page from ordinary unloading when its live state matters.

Optional **iCloud sync** carries durable Spaces, tabs, folders, Split View groups, appearance, history, and Archive between devices. Password values stay out of CloudKit; eligible passwords can use iCloud Keychain separately. Start a browser import on Mac, review each destination Space, or export a portable archive.

Read the [Space isolation guide](HelpCenter/docs/spaces/spaces-and-isolation.md) and [sync guide](HelpCenter/docs/spaces/sync-across-devices.md) for the boundaries and controls. _Placeholder: Arma has no published privacy policy yet._

## Get Arma

_Placeholder: no screenshots of Arma yet._

Arma has no signed releases yet. Build it from source as described
below; the Mac app runs Chromium when a prebuilt engine is packaged in, and
WebKit alone otherwise.

## Built as an Apple-platform app

Arma's browser state and rules live in a portable core written in C# and compiled with NativeAOT. The apps are written in Swift and SwiftUI: shared features live in `CrestShared`, and each platform owns its windows, engine hosting, commands, and adaptive presentation. On Mac, pages render in Chromium by default or in WebKit; iPhone and iPad use WebKit.

```text
CrestCore/       Portable core: session, sync, pages, and browser rules
CrestContracts/  C ABI header and ABI checks for the core library
CrestEngines/    Chromium host overlay, patches, and engine binding
CrestShared/     Domain, application, infrastructure, features, design system
CrestMac/        macOS app and platform-specific presentation
CrestMobile/     iPhone and iPad app and platform-specific presentation
```

Read [the architecture overview](Documentation/ARCHITECTURE.md) for Space isolation, persistence, credentials, synchronization, and the engine boundary.

## Build Arma

Requirements:

- Apple silicon Mac
- Xcode with macOS and iOS SDKs supporting the 26.1 deployment targets
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- .NET SDK pinned by `CrestCore/global.json`, installable with `Scripts/control-plane/install-dotnet.sh`

```bash
git clone https://github.com/devops-senpai/BetterCrest.git
cd Arma
Scripts/bootstrap.sh
open Crest.xcodeproj
```

Xcode builds and embeds the self-contained .NET core for Mac, iOS, and Simulator. Its intermediate files stay in Derived Data; the installed app does not require a .NET runtime. The `Crest` scheme builds the Mac app with WebKit only; a Chromium build adds a prebuilt engine, described in the [Chromium engine README](CrestEngines/Chromium/README.md). See the [control-plane build workflow](Documentation/Architecture/ControlPlane.md#build-workflow) for isolated review builds and Chromium packaging.

`project.yml` is the source of truth for targets and build settings. Run `xcodegen generate` after changing source roots, targets, or project configuration.

## Validate a change

```bash
Scripts/validate-identity.sh
Scripts/validate.sh
Scripts/validate-cache-hygiene.sh
```

Run the relevant behavioral tests and repository checks. Review visual, layout, and static-copy changes in the real app, Simulator, or browser.

## Relationship to Crest

Arma tracks Crest's `main` and merges it in regularly; its own
changes stay here. Use
[GitHub Issues](https://github.com/devops-senpai/BetterCrest/issues) for bugs.

## AI usage

AI tools assist with Arma's development, audits, testing and
documentation. Every generated change is reviewed and validated before it is
committed. Any change an AI tool helps produce follows the
[`crest-contribution` skill](.agents/skills/crest-contribution/SKILL.md), which
carries the C# and Swift style, the architecture and UI rules, and the test
policy.

## License and brand

Arma's source code is available under the [Mozilla Public License 2.0](LICENSE),
as Crest's is. The source is open for inspection, modification, and commercial
use under that license. The Crest name, app icon, logos, and official
distribution identity belong to Paul Davis and are reserved as described in
[TRADEMARKS.md](TRADEMARKS.md). Arma is a separate, unofficial project.
Third-party notices are collected in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
