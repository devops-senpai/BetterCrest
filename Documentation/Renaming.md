# Renaming the product

Arma was renamed from Crest on 2026-10-30 in four commits on `main`:
bundle identifier (80548031), app name and icon (0f8ed98e), every string and
guide (6dd7f821), plus the repository identity before them. This page lists
each place a name lives, so the next rename is a checklist. Run the steps in
order; each has a check.

## What is a name here

| Thing | Current value | Changes when |
| --- | --- | --- |
| Product name (copy, bundle, files) | `Arma` | the product is renamed |
| Bundle identifier prefix | `com.senpaimedia.arma` | the product or its owner changes |
| iCloud container | `iCloud.com.senpaimedia.arma` | with the bundle identifier |
| Terminal helper | `arma` | the product is renamed |
| Data folder | `~/Library/Application Support/Arma` | follows `ProductIdentity.name` |
| Apple team | `U5WBZPZ4X7` | the signing owner changes |
| Sparkle feed and key | `raw.githubusercontent.com/devops-senpai/BetterCrest/updates/…`, key in `Crest-Info.plist` | the repository or the key owner changes |
| Repository | `devops-senpai/BetterCrest` (kept on purpose; not the product name) | the repository moves |

Names that stay, whatever the product is called: module and target names
(`Crest`, `CrestMobile`, `CrestShared`, `CrestMac`, `CrestCore`…), the
`Crest` scheme, `Crest.xcodeproj`, `Crest-Info.plist`, `Crest.entitlements`,
content-world and
notification names such as `Crest.Agent`, UserDefaults keys such as
`crest.appearance.appIcon`, and the folder layout. They are identifiers, not
copy, and renaming them makes every upstream merge conflict on every file.

Names that stay because they are heraldic, not the product: **Crest Studio**,
**Crest Studio step**, **Crest colors**, **Crest preview**, **Edit Crest…**,
**Make Crest your own**, **Choose Crest under Emblem to color the crest**, and
the bare **Crest** that names the layered-crest icon style. A Space wears a
crest; the Studio draws it.

References to the upstream project also stay: "upstream Crest", "fork of
Crest", "Crest by Paul Davis", "not affiliated with Crest". The last rename
caught three of these by accident; protect them like the heraldic phrases.

Persisted format identifiers that stay so old data still opens:
`com.pauldavis.crest.browser-data` (archive format, `BrowserDataFile.cs`),
`com.pauldavis.crest.content-blocking.balanced.v2` (rule list,
`ContentBlockingPolicy.cs`) and `com.pauldavis.crest.sync-journal`
(`BrowserLegacySessionDefaults.swift`).

## 1. Product name

| Where | What |
| --- | --- |
| `project.yml` | `PRODUCT_NAME` of the Mac and mobile app targets; the two `TEST_HOST` paths |
| `CrestMac/Configuration/Crest-Info.plist`, `CrestMobile/Configuration/CrestMobile-Info.plist` | `CFBundleDisplayName`, `CFBundleName` |
| `CrestShared/Application/ProductIdentity.swift` | `name`; `storageDirectoryName` follows it, so the data folder moves |
| `CrestMac/Features/Settings/BrowserPlatformAppIconSettingsSection.swift`, `CrestMobile/Features/Settings/BrowserPlatformAppIconSettingsSection.swift` | the default icon choice's title |
| `Scripts/control-plane/package-chromium-host.py` | the product name the Chromium host bundle takes |
| `Scripts/install-local-macos-release.sh`, `.github/workflows/release.yml`, `.github/workflows/experimental-release.yml` | `<Name>.app` paths, `asset_base="<Name>-${marketing_version}…"`, the `<Name>-LocalRelease` derived-data folder |
| Every `.swift` and `.cs` under `CrestShared`, `CrestMac`, `CrestMobile`, `CrestCore/src`, `CrestCore/tests`, `CrestAgents`, `CrestAgentHelper`, `CrestDockTilePlugin`, `CrestShareExtension`, `CrestTests`, `CrestMobileTests`, `CrestNative` | the product name inside string literals only; never identifiers. Skip `Fixtures/` and `Generated/`. Keep `CrestCore/tests/CrestCore.Tests/Palette/PaletteTests.cs` as is: its "Crest Browser" tab title is what the query-matching test matches |
| `CrestShared/Resources/Localizable.xcstrings` | every key line `    "…" : {` and every `"value" : "…"`; rename with the same rule so translations stay attached |
| `CrestShared/Infrastructure/Core/Generated/*` | not edited; run `Scripts/control-plane/generate-contracts.sh` after the C# strings change |
| `HelpCenter/docs/**/*.md` | prose and front matter titles; file names and `slug:` values stay so URLs hold |
| `HelpCenter/docusaurus.config.js` | `title`, `tagline`, navbar and footer titles, copyright |
| `Documentation/**/*.md`, `ROUTING.md`, every `CONTEXT.md`, `CrestEngines/Chromium/README.md` | prose; paths such as `/Applications/<Name>.app`, `/Volumes/<Name>/<Name>.app`, `Application Support/<Name>`, `Checksum-<Name>-*.dmg` |
| `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `SUPPORT.md`, `GOVERNANCE.md`, `SPONSORS.md`, `Documentation/ROADMAP.md`, `.github/ISSUE_TEMPLATE/*.yml`, `.github/FUNDING.yml` | written by hand for the fork; they also say "fork of Crest", which stays |
| `CrestShared/Features/Utilities/…/BrowserUtilityListPreviewFixture.swift`, `BrowserUtilityListRowLabel.swift`, `CrestTests/BrowserUtilityListTests.swift`, `CrestTests/BrowserSidebarUtilityCoordinatorTests.swift` | the `<Name>.dmg` download fixtures |
| `Documentation/ReleaseNotes/<id>.json` | a new entry for the rename |

The word rule that did the last rename, for a literal or a prose line: replace
`Crest` when it is not preceded by a word character, `/`, `` ` ``, `-` or `.`,
and not followed by a word character, `/`, `` ` ``, or by `-` or `.` and then a
word character. That leaves `CrestShared`, `Crest.xcodeproj`, `Crest-Info`,
`` `Crest` `` and `Crest.Agent` alone while catching `Crest.`, `Crest,` and
`Crest’s`. Protect the heraldic phrases above before applying it.

## 2. Bundle identifier

| Where | What |
| --- | --- |
| `project.yml` | `bundleIdPrefix`; `PRODUCT_BUNDLE_IDENTIFIER`, `CREST_MAC_BUNDLE_IDENTIFIER`, `CREST_MOBILE_BUNDLE_IDENTIFIER`, `CREST_NATIVE_CORE_BUNDLE_IDENTIFIER` on every target |
| `CrestMac/Configuration/Crest.entitlements`, `CrestMobile/Configuration/CrestMobile.entitlements`, `CrestNative/Apple/Composition/MacCloudReview.entitlements`, `MobileCloudReview.entitlements` | iCloud container, keychain access group, app group |
| both Info.plists | `CrestCloudKitContainerIdentifier` |
| `CrestShared/Application/ProductIdentity.swift` | `bundleIdentifier`; `serviceNamespace` follows it |
| about 35 Swift and C# files | the identifier as a log subsystem, signposter, Keychain service, defaults suite, content-world name, dispatch-queue label or notification name; find them with `grep -rn "<old id>" --include='*.swift' --include='*.cs'` and skip the three persisted format identifiers above |
| `Scripts/validate-identity.sh` | the two `rg -q 'CREST_…_BUNDLE_IDENTIFIER: …'` assertions and `prototype_bundle` |
| `Scripts/control-plane/package-chromium-host.py`, `Scripts/control-plane/package-apple-core.py` | the identifiers written into packaged bundles |
| `Config/DeveloperIDExportOptions.plist` | the provisioning map key |
| `.github/workflows/release.yml`, `experimental-release.yml` | the identifier, team-prefixed group and container the workflows assert after export |
| `CrestEngines/Chromium/Patches/native-host.patch`, `CrestEngines/Chromium/Overlay/…` | **Leave alone.** The engine looks at the host's bundle identifier only to name the Keychain item that protects the Chromium profile, and falls back to Chromium's default name for any other identifier. Keeping every engine input byte-identical to upstream's keeps the engine key equal to upstream's, so `Scripts/sync-upstream-engine.sh` can mirror upstream's prebuilt engine instead of anyone building Chromium |
| `CrestTests/*`, `CrestMobileTests/*`, `CrestCore/tests/*` | test labels and container identifiers that embed the prefix |

Also register the new App ID, iCloud container and app group under the Apple
team (Xcode automatic signing does this on first build, or
developer.apple.com → Identifiers). Keychain items and the iCloud container
are bound to the identifier, so a renamed build starts with an empty profile;
Spaces and tabs move with the archive export and import.

## 3. Icon

`Scripts/generate-app-icon-palettes.py` writes every icon: the default and
its palette variants from one banner SVG (`BANNER`, currently
`Brand/AppIcons/ArmaHonor.svg`) and one color per palette (`BASE`,
`VARIANTS`), and one emblem icon per other banner in `Brand/AppIcons/`
(`EMBLEMS`, drawn as designed on a neutral field). They become the `.icon`
documents under `CrestShared/Resources/ArmaIcon/`, the picker previews and the
Dock images under `CrestShared/Resources/AppIconPreviews.xcassets/`. Each
banner is placed from its own `viewBox` to stand `BANNER_HEIGHT` points tall on
the 1024-point canvas (799, about 78 percent); the default banner's field color
`BANNER_FILL` is what the palette variants recolor. Edit a banner, the colors
or those constants and run the script; it needs Icon Composer's `ictool` from
the installed Xcode. An emblem also needs its name in `EMBLEMS`, in
`BrowserAppIconEmblem.all` and in `project.yml`'s
`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`.
`HelpCenter/static/img/arma-logo.svg` is the earlier mark on its base color,
written by hand, and the start page mark (`CrestStartPageMark`) shows
`AppIconPreviews.xcassets/ArmaMark.imageset/mark.svg`, a tight crop of
`Brand/Arma.svg`.

## 4. Terminal helper

| Where | What |
| --- | --- |
| `project.yml` | `PRODUCT_NAME` of the helper target |
| `CrestAgentHelper/AgentHelperEndpoint.swift` | `serverInfo` name and title |
| `CrestAgents/AgentSocketLocation.swift` | the socket directory under `Application Support/<Name>/` |
| `CrestAgentHelper/main.swift`, `HelpCenter/docs/browsing/coding-agents.md`, `HelpCenter/docs/spaces/customize-spaces.md`, `Documentation/**`, `README.md` | the command as people type it |

## 5. Updates, signing, repository

| Where | What |
| --- | --- |
| `CrestMac/Configuration/Crest-Info.plist` | `SUFeedURL`, `SUPublicEDKey` |
| `CrestMac/Features/SoftwareUpdates/Models/BrowserSoftwareUpdateChannel.swift`, `CrestTests/BrowserSoftwareUpdateTests.swift` | the appcast host and path |
| the `updates` branch | the appcasts and `release-note-publication.json` the workflow writes |
| `project.yml` `DEVELOPMENT_TEAM`, `Config/DeveloperIDExportOptions.plist`, both release workflows, `Scripts/install-local-macos-release.sh` | the Apple team |
| `Scripts/install-local-macos-release.sh`, `Scripts/sync-upstream.sh`, `.github/CODEOWNERS`, `.github/FUNDING.yml`, `.github/ISSUE_TEMPLATE/config.yml`, `HelpCenter/docusaurus.config.js` (`url`, `organizationName`, `projectName`, links), `CrestShared/Features/Settings/Models/BrowserAboutInformation.swift` (About links), `README.md`, `SUPPORT.md`, `GOVERNANCE.md` | the repository and its channels |

## Procedure

1. Branch from `main`. Apply sections 1, 2 and 4 with a script that edits
   string literals and prose only, using the word rule and the keep-lists.
2. `xcodegen generate`, then `Scripts/control-plane/generate-contracts.sh`.
3. `Scripts/check-swift-format.sh --base main`: renamed lines that pass the
   column limit must be wrapped or their copy tightened; a localized string
   cannot be split with `+`.
4. `Scripts/validate-identity.sh`, `python3 -m unittest discover -s Scripts/Tests -p 'test_*.py'`,
   `dotnet test CrestCore/tests/CrestCore.Tests/CrestCore.Tests.csproj`,
   `xcodebuild build -scheme Crest -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`,
   then `defaults read <built app>/Contents/Info CFBundleIdentifier`.
5. Check what still carries the old name: `grep -rn "<old>" --exclude-dir=.git --exclude-dir=Source .`
   and compare against the keep-lists.
6. Add a `Documentation/ReleaseNotes/<id>.json` entry and run
   `Scripts/check-version.sh --fix-commit`.
7. Run `Scripts/sync-upstream-engine.sh` so the fork's releases hold the engine
   for the current key; the key must still equal upstream's.
