import AppKit

/// One setting `arma settings` exposes: its key, where Settings shows it, the
/// values it takes as the terminal spells them, its default, and how it reads
/// and changes through the same stores and core intents Settings binds.
///
/// The members are the static instances, and `all` lists them in the order
/// `arma settings list` prints them. Each is built from typed values: a word
/// from the terminal becomes the setting's own value once, by its choices,
/// and only that value reaches the store. Keys that start with `space.` are
/// one Space's. Nothing secret is a member.
@MainActor
struct BrowserTerminalSetting {
    // MARK: - Types

    typealias Refusal = BrowserMacTerminal.Refusal

    /// What a setting acts on: the running app, and the Space a per-Space
    /// setting belongs to, or the one `--space` named for an app-wide setting
    /// that can use one.
    @MainActor
    struct Target {
        let terminal: BrowserMacTerminal
        let space: SpaceModel?

        var browser: BrowserStore { terminal.browser }
        var core: CrestCore { terminal.browser.core }

        /// The Space, as the core reads it now.
        func currentSpace() throws(Refusal) -> SpaceModel {
            guard let space, let current = browser.spaceModel(space.id) else {
                throw Refusal("Name a Space with --space.")
            }
            return current
        }
    }

    /// One value a setting takes: the word that names it and the other words
    /// that also do.
    struct Choice<Value> {
        let name: String
        let value: Value
        var aliases: [String] = []

        /// Whether `word`, in any case and with or without its hyphens, names
        /// this choice.
        func isNamed(_ word: String) -> Bool {
            let wanted = BrowserTerminalSetting.spelling(word)
            return ([name] + aliases).contains { BrowserTerminalSetting.spelling($0) == wanted }
        }
    }

    // MARK: - Static Variables

    static let appearanceMode = BrowserTerminalSetting(
        "appearance.mode", "Appearance", in: "Look and Feel › Window",
        choices: { _ in named(BrowserAppearanceMode.all, \.name) },
        default: BrowserLookAndFeelDefaults.appearanceMode,
        read: { _ in BrowserDeviceAppearanceStore.shared.mode },
        write: { _, mode in BrowserDeviceAppearanceStore.shared.mode = mode })

    static let sidebarSide = BrowserTerminalSetting(
        "appearance.sidebar-side", "Sidebar side", in: "Look and Feel › Window",
        choices: { _ in [Choice(name: "left", value: false), Choice(name: "right", value: true)] },
        default: BrowserLookAndFeelDefaults.sidebarOnRight,
        read: { _ in BrowserDeviceAppearanceStore.shared.sidebarOnRight },
        write: { _, onRight in BrowserDeviceAppearanceStore.shared.sidebarOnRight = onRight })

    static let startup = BrowserTerminalSetting(
        "general.startup.when-opens", "When Arma opens", in: "General › Startup",
        choices: { _ in named(StartupBehavior.settingsOrder, \.name) },
        default: AppPreferences.default.startup,
        read: { _ in BrowserAppPreferenceStore.shared.startupBehavior },
        write: { _, behavior in BrowserAppPreferenceStore.shared.startupBehavior = behavior })

    static let defaultSpace = BrowserTerminalSetting(
        "general.startup.default-space", "Default Space", in: "General › Startup",
        choices: { target in
            target.browser.spaceModels.map { Choice(name: $0.settings.name, value: $0.id, aliases: [$0.id.uuidString]) }
        },
        default: nil,
        read: { target in target.browser.workspaceModel?.defaultSpaceID ?? target.browser.selectedSpaceID },
        write: { target, id in target.browser.setDefaultSpace(id) })

    static let offersTranslation = preference(
        "general.translation.offer", "Offer to translate pages", in: "General › Translation", \.offersTranslation,
        default: AppPreferences.default.offersTranslation)

    static let translatesAutomatically = preference(
        "general.translation.automatic", "Translate automatically", in: "General › Translation",
        \.automaticallyTranslates, default: AppPreferences.default.automaticallyTranslates)

    /// WebKit reads the choice once per launch, so it applies after Arma
    /// restarts, as Settings says.
    static let checksSpelling = BrowserTerminalSetting(
        "general.webpages.spell-check", "Check spelling (after a restart)", in: "General › Webpages",
        choices: { _ in toggle }, default: AppPreferences.default.checksSpelling,
        read: { _ in BrowserAppPreferenceStore.shared.checksSpelling },
        write: { _, isOn in BrowserAppPreferenceStore.shared.setChecksSpellingForWebKit(isOn) })

    static let pictureInPicture = preference(
        "general.webpages.picture-in-picture", "Enter Picture in Picture automatically", in: "General › Webpages",
        \.automaticallyEntersPictureInPicture, default: AppPreferences.default.automaticallyEntersPictureInPicture)

    static let developerToolbar = preference(
        "general.developer-toolbar", "Developer toolbar on local pages", in: "General › Developer",
        \.automaticallyShowsDeveloperToolbar, default: AppPreferences.default.automaticallyShowsDeveloperToolbar)

    static let focusesNewTabs = linkBehavior(
        "tabs.new-tabs.switch-to-link-tabs", "Switch to tabs opened from links", in: "Tabs › New tabs",
        .focusesNewTabs, reading: \.focusesNewTabs, default: false)

    static let followsMovedTabs = linkBehavior(
        "tabs.new-tabs.follow-moved-tabs", "Follow tabs moved to another Space", in: "Tabs › New tabs",
        .followsMovedTabs, reading: \.followsMovedTabs, default: true)

    static let savedTabClose = BrowserTerminalSetting(
        "tabs.saved.after-closing", "After closing a pinned or saved tab", in: "Tabs › Pinned and saved tabs",
        choices: { _ in named(SavedTabClosePolicy.all, \.name) },
        default: AppPreferences.default.savedTabClose,
        read: { _ in BrowserAppPreferenceStore.shared.savedTabClosePolicy },
        write: { _, policy in BrowserAppPreferenceStore.shared.savedTabClosePolicy = policy })

    static let faviconReturns = preference(
        "tabs.saved.favicon-returns", "Click the favicon to return to the saved URL",
        in: "Tabs › Pinned and saved tabs", \.returnsToSavedURLOnFaviconClick,
        default: AppPreferences.default.savedTabFaviconReturnsToSavedURL)

    static let splitFocus = preference(
        "tabs.split.focus-follows-mouse", "Split View focus follows the pointer", in: "Tabs › Split View",
        \.splitFocusFollowsMouse, default: AppPreferences.default.splitFocusFollowsMouse)

    static let recentTabs = preference(
        "tabs.recent-tabs.show", "Show recent tabs while switching", in: "Tabs › Recent tabs", \.showsRecentTabs,
        default: AppPreferences.default.showsRecentTabs)

    /// Where a link from another app opens. `chosen-space` opens in the Space
    /// `--space` names, or the one chosen before.
    static let externalLinks = BrowserTerminalSetting(
        "links.external.open-in", "Open links from other apps in", in: "Links › Links from other apps",
        choices: { _ in named(ExternalLinkDestination.all, \.name) },
        default: .quickWindow,
        read: { target in target.browser.linkPreferences.preferences.destination },
        write: { target, destination in
            target.browser.linkPreferences.chooseExternalDestination(destination, spaceID: target.space?.id)
        })

    static let opensPeek = linkBehavior(
        "links.peek.open-automatically", "Open links from pinned tabs in Peek", in: "Links › Peek",
        .opensPeekAutomatically, reading: \.opensPeekAutomatically, default: true)

    static let peekModifier = BrowserTerminalSetting(
        "links.peek.modifier", "Open Peek with", in: "Links › Peek",
        choices: { _ in named(LinkPeekModifier.all, \.name) },
        default: .option,
        read: { target in target.browser.linkPreferences.preferences.peekModifier },
        write: { target, modifier in target.browser.linkPreferences.choosePeekModifier(modifier) })

    static let dragsToPeek = linkBehavior(
        "links.peek.drag-links", "Drag links to Peek", in: "Links › Peek", .dragsLinksToPeek,
        reading: \.dragsLinksToPeek, default: true)

    static let quickWindowArchive = BrowserTerminalSetting(
        "links.quick-window.auto-archive", "Auto-archive Quick Windows", in: "Links › Quick Windows",
        choices: { _ in named(QuickWindowArchivePolicy.all, \.name) },
        default: .after6Hours,
        read: { target in target.browser.linkPreferences.preferences.archivePolicy },
        write: { target, policy in target.browser.linkPreferences.chooseArchivePolicy(policy) })

    static let remembersSpace = linkBehavior(
        "links.remember-space-by-site", "Remember the Space each site opens in", in: "Links › Links from other apps",
        .remembersSpaceBySite, reading: \.remembersSpaceBySite, default: true)

    static let defaultSearch = BrowserTerminalSetting(
        "search.default-engine", "Default search", in: "Search › Default search",
        choices: { target in providers(BrowserSearchCatalog(core: target.core).defaultChoices) },
        default: nil,
        read: { target in BrowserSearchCatalog(core: target.core).defaultProvider },
        write: { target, provider throws(Refusal) in
            do { try BrowserSearchCatalog(core: target.core).setDefault(provider) } catch {
                throw Refusal(error.personFacingDescription)
            }
        })

    static let privateSearch = BrowserTerminalSetting(
        "search.private-engine", "Private window search", in: "Search › Default search",
        choices: { target in providers(BrowserSearchCatalog(core: target.core).defaultChoices) },
        default: nil,
        read: { target in BrowserSearchCatalog(core: target.core).privateDefaultProvider },
        write: { target, provider throws(Refusal) in
            do { try BrowserSearchCatalog(core: target.core).setPrivateDefault(provider) } catch {
                throw Refusal(error.personFacingDescription)
            }
        })

    static let searchSuggestions = BrowserTerminalSetting(
        "search.suggestions", "Search suggestions", in: "Search › Default search",
        choices: { _ in toggle }, default: nil,
        read: { target in BrowserSearchCatalog(core: target.core).suggestionsEnabled },
        write: { target, isOn in BrowserSearchCatalog(core: target.core).setSuggestionsEnabled(isOn) })

    /// The engine a page a person opens uses, or the one this build
    /// recommends. Open pages keep theirs.
    static let defaultEngine = BrowserTerminalSetting(
        "engines.default", "Default engine", in: "Engines › Default engine",
        choices: { target in
            let available = target.core.state.engines?.engines.map(\.kind) ?? []
            return [Choice(name: "recommended", value: EngineKind?.none)]
                + TerminalEngine.allCases.filter { available.contains(TerminalTabCommand.kind(of: $0)) }.map {
                    Choice(name: $0.rawValue, value: Optional(TerminalTabCommand.kind(of: $0)))
                }
        },
        default: .some(nil),
        read: { target in .some(target.core.state.enginePreferences.defaultEngine) },
        write: { target, engine throws(Refusal) in
            do throws(Rejection) { try target.core.send(SelectDefaultEngine(engine: engine)) } catch {
                throw Refusal(error.explanation)
            }
        })

    /// Whether agents may use Arma at all. Each new agent still asks before
    /// it connects, and the Spaces it reaches stay as Settings chose them.
    static let agents = BrowserTerminalSetting(
        "agents.enabled", "Allow agents to use Arma", in: "Agents",
        choices: { _ in toggle }, default: false,
        read: { target in target.core.state.agentPreferences.isOn },
        write: { target, isOn throws(Refusal) in
            do throws(Rejection) { try target.core.send(SetAgents(isOn: isOn)) } catch {
                throw Refusal(error.explanation)
            }
        })

    /// What the Space searches with: the device's default search, or its own.
    static let spaceSearch = BrowserTerminalSetting(
        "space.browsing.search-engine", "Search with", in: "Spaces › Browsing", perSpace: true,
        choices: { target in
            let catalog = BrowserSearchCatalog(core: target.core)
            var choices = providers(catalog.defaultChoices)
            if let preferences = try? target.currentSpace().settings.browsingPreferences,
                !preferences.followsDefaultSearch,
                let own = catalog.provider(for: preferences, isPrivate: false),
                !choices.contains(where: { $0.value == own })
            {
                choices += providers([own])
            }
            return [Choice(name: "default", value: SearchProvider?.none)]
                + choices.map {
                    Choice(name: $0.name, value: Optional($0.value), aliases: $0.aliases)
                }
        },
        default: .some(nil),
        read: { target in
            guard let preferences = try? target.currentSpace().settings.browsingPreferences else { return nil }
            guard !preferences.followsDefaultSearch else { return .some(nil) }
            return .some(BrowserSearchCatalog(core: target.core).provider(for: preferences, isPrivate: false))
        },
        write: { target, provider throws(Refusal) in
            let space = try target.currentSpace()
            let preferences = space.settings.browsingPreferences
            target.browser.setSearch(
                provider,
                suggestions: preferences.followsDefaultSuggestions ? nil : preferences.searchSuggestionsEnabled,
                in: space.id)
        })

    /// Whether the Space suggests searches: as the default search does, or
    /// its own way.
    static let spaceSuggestions = BrowserTerminalSetting(
        "space.browsing.search-suggestions", "Search suggestions", in: "Spaces › Browsing", perSpace: true,
        choices: { _ in
            [Choice(name: "default", value: Bool?.none)]
                + toggle.map {
                    Choice(name: $0.name, value: Optional($0.value), aliases: $0.aliases)
                }
        },
        default: .some(nil),
        read: { target in
            guard let preferences = try? target.currentSpace().settings.browsingPreferences else { return nil }
            return preferences.followsDefaultSuggestions ? .some(nil) : preferences.searchSuggestionsEnabled
        },
        write: { target, suggestions throws(Refusal) in
            let space = try target.currentSpace()
            let preferences = space.settings.browsingPreferences
            let catalog = BrowserSearchCatalog(core: target.core)
            let provider = preferences.followsDefaultSearch ? nil : catalog.provider(for: preferences, isPrivate: false)
            target.browser.setSearch(provider, suggestions: suggestions, in: space.id)
        })

    static let spaceTabCleanup = browsing(
        "space.browsing.archive-tabs", "Archive current tabs", in: "Spaces › Browsing", \.currentTabCleanup,
        choices: CurrentTabCleanup.all, name: \.name, default: .after12Hours)

    static let spaceContentBlocking = browsing(
        "space.privacy.content-blocking", "Content blocking", in: "Privacy › Content blocking", \.contentBlocking,
        choices: ContentBlockingPolicy.all, name: \.name, default: .balanced)

    static let spaceHistoryRetention = browsing(
        "space.privacy.keep-history", "Keep history", in: "Privacy › Keep", \.dataRetention.history,
        choices: DataRetention.all, name: \.name, default: .forever)

    static let spaceArchiveRetention = browsing(
        "space.privacy.keep-archived-tabs", "Keep archived tabs", in: "Privacy › Keep", \.dataRetention.archive,
        choices: DataRetention.all, name: \.name, default: .forever)

    static let spaceDownloadRetention = browsing(
        "space.privacy.keep-download-records", "Keep download records", in: "Privacy › Keep",
        \.dataRetention.downloads, choices: DataRetention.all, name: \.name, default: .forever)

    /// Every setting, in the order `arma settings list` prints them.
    static let all: [BrowserTerminalSetting] = [
        startup, defaultSpace, offersTranslation, translatesAutomatically, checksSpelling, pictureInPicture,
        developerToolbar, focusesNewTabs, followsMovedTabs, savedTabClose, faviconReturns, splitFocus, recentTabs,
        externalLinks, opensPeek, peekModifier, dragsToPeek, quickWindowArchive, remembersSpace, defaultSearch,
        privateSearch, searchSuggestions, defaultEngine, appearanceMode, sidebarSide, agents, spaceSearch,
        spaceSuggestions, spaceTabCleanup, spaceContentBlocking, spaceHistoryRetention, spaceArchiveRetention,
        spaceDownloadRetention,
    ]

    /// On and off, with the other words a person types for them.
    private static let toggle = [
        Choice(name: "on", value: true, aliases: ["true", "yes", "1", "enabled"]),
        Choice(name: "off", value: false, aliases: ["false", "no", "0", "disabled"]),
    ]

    // MARK: - Variables

    let key: String
    let title: String
    /// Where Settings shows it, under Settings.
    let location: String
    /// Whether it belongs to one Space rather than the whole app.
    let isPerSpace: Bool
    /// The words it takes now; some, such as Spaces and search providers,
    /// change as the person adds them.
    let allowed: @MainActor (Target) -> [String]
    /// The word for its value now.
    let read: @MainActor (Target) -> String
    /// The word for its default, or nil when it has none to go back to.
    let defaultName: @MainActor (Target) -> String?
    /// Sets the value `word` names, and answers that value's word.
    let write: @MainActor (Target, String) throws(Refusal) -> String

    /// The part of Settings it is in, the first part of its key.
    var section: String { String(key.prefix { $0 != "." }) }

    // MARK: - Initializers

    /// A setting whose values are `choices`, read and written as typed
    /// values; a word becomes a value only through its choice.
    private init<Value: Equatable>(
        _ key: String, _ title: String, in location: String, perSpace: Bool = false,
        choices: @escaping @MainActor (Target) -> [Choice<Value>],
        default defaultValue: Value?,
        read: @escaping @MainActor (Target) -> Value?,
        write: @escaping @MainActor (Target, Value) throws(Refusal) -> Void
    ) {
        self.key = key
        self.title = title
        self.location = location
        isPerSpace = perSpace
        allowed = { target in choices(target).map(\.name) }
        self.read = { target in
            guard let value = read(target) else { return "-" }
            return choices(target).first { $0.value == value }?.name ?? "other"
        }
        defaultName = { target in
            guard let defaultValue else { return nil }
            return choices(target).first { $0.value == defaultValue }?.name
        }
        self.write = { target, word throws(Refusal) in
            let options = choices(target)
            guard let choice = options.first(where: { $0.isNamed(word) }) else {
                throw Refusal(
                    "\(key) is one of \(options.map(\.name).joined(separator: ", ")), not '\(word)'.")
            }
            try write(target, choice.value)
            return choice.name
        }
    }

    // MARK: - Actions - Lookup

    /// The setting `key` names, in any case.
    static func named(_ key: String) -> BrowserTerminalSetting? {
        all.first { $0.key == key.lowercased() }
    }

    // MARK: - Actions - Building

    /// An on-off app preference the core keeps.
    private static func preference(
        _ key: String, _ title: String, in location: String,
        _ keyPath: ReferenceWritableKeyPath<BrowserAppPreferenceStore, Bool>, default defaultValue: Bool
    ) -> BrowserTerminalSetting {
        BrowserTerminalSetting(
            key, title, in: location, choices: { _ in toggle }, default: defaultValue,
            read: { _ in BrowserAppPreferenceStore.shared[keyPath: keyPath] },
            write: { _, isOn in BrowserAppPreferenceStore.shared[keyPath: keyPath] = isOn })
    }

    /// An on-off link behavior the core keeps.
    private static func linkBehavior(
        _ key: String, _ title: String, in location: String, _ behavior: LinkBehavior,
        reading keyPath: KeyPath<LinkPreferences, Bool>, default defaultValue: Bool
    ) -> BrowserTerminalSetting {
        BrowserTerminalSetting(
            key, title, in: location, choices: { _ in toggle }, default: defaultValue,
            read: { target in target.browser.linkPreferences.preferences[keyPath: keyPath] },
            write: { target, isOn in target.browser.linkPreferences.setBehavior(behavior, isOn: isOn) })
    }

    /// One of a Space's browsing preferences, written back whole through the
    /// Space's intent, as Settings' bindings write it.
    private static func browsing<Member: Equatable>(
        _ key: String, _ title: String, in location: String,
        _ keyPath: WritableKeyPath<BrowsingPreferences, Member>, choices members: [Member],
        name: KeyPath<Member, String>, default defaultValue: Member
    ) -> BrowserTerminalSetting {
        BrowserTerminalSetting(
            key, title, in: location, perSpace: true, choices: { _ in named(members, name) }, default: defaultValue,
            read: { target in (try? target.currentSpace())?.settings.browsingPreferences[keyPath: keyPath] },
            write: { target, value throws(Refusal) in
                let space = try target.currentSpace()
                var preferences = space.settings.browsingPreferences
                preferences[keyPath: keyPath] = value
                target.browser.updateBrowsingPreferences(preferences, in: space.id)
            })
    }

    /// `members` as choices, each named by its core name in kebab case and
    /// also answering to the core name itself.
    private static func named<Member>(_ members: [Member], _ name: KeyPath<Member, String>) -> [Choice<Member>] {
        members.map { Choice(name: kebab($0[keyPath: name]), value: $0, aliases: [$0[keyPath: name]]) }
    }

    /// Search providers as choices, by their name, also answering to their
    /// title.
    private static func providers(_ providers: [SearchProvider]) -> [Choice<SearchProvider>] {
        providers.map { provider in
            let name =
                provider.builtIn.map { kebab($0.name) }
                ?? provider.title.lowercased().replacingOccurrences(of: " ", with: "-")
            return Choice(name: name, value: provider, aliases: [provider.title, provider.name])
        }
    }

    // MARK: - Actions - Spelling

    /// `name` in kebab case: `after12Hours` as `after-12-hours`, and
    /// `googleAIMode` as `google-ai-mode`.
    nonisolated static func kebab(_ name: String) -> String {
        let characters = Array(name)
        var result = ""
        for (index, character) in characters.enumerated() {
            if index > 0 {
                let previous = characters[index - 1]
                let next = index + 1 < characters.count ? characters[index + 1] : nil
                let startsWord =
                    (character.isUppercase && (!previous.isUppercase || next?.isLowercase == true))
                    || (character.isNumber && previous.isLetter) || (character.isLetter && previous.isNumber)
                if startsWord, previous != "-" { result.append("-") }
            }
            result.append(contentsOf: character.lowercased())
        }
        return result
    }

    /// `word` as two spellings of one value compare: lowercased, without
    /// hyphens, underscores or spaces.
    nonisolated static func spelling(_ word: String) -> String {
        word.lowercased().filter { !["-", "_", " "].contains($0) }
    }
}
