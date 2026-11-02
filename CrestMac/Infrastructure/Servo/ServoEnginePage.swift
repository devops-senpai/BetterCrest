import AppKit

/// One page Servo hosts, and its desktop adapter. Servo's binding builds it
/// when the core asks Servo to create a page; the page's owner hosts its view.
/// It turns what Servo reports, its load status, address, title and history,
/// into the navigations the core records, and keeps an identity for each
/// history entry so the core can ask for one by name.
@MainActor
final class ServoEnginePage: BrowserPageEngineAdapter, BrowserPageEngine {
    // MARK: - Variables

    let id: UUID
    let view: ServoPageView
    let enginePage: EnginePage
    private weak var page: BrowserPage?
    private(set) var reporter: EnginePageReporter?
    private(set) var url: URL?
    private var title = ""
    private var isLoading = false
    /// Whether the load in progress committed its document yet.
    private var hasCommitted = false
    /// Whether any document committed in the page yet.
    private var hasDocument = false
    /// An address change waiting to learn whether a new document loads at
    /// it: Servo reports the address before the load starts.
    private var addressChange: URL?
    /// Servo said a load completed while none had begun, as a page's first
    /// document can before its address settles.
    private var completedEarly = false
    /// The page's history, oldest first, and the entry it shows.
    private(set) var history: [PageHistoryEntry] = []
    private(set) var currentEntry = 0
    /// The identity the core gave the entry the next load commits.
    private var expectedEntryID: UUID?

    var engine: any BrowserPageEngine { self }
    var registration: BrowserAdapterRegistration { BrowserEngineRegistration.servo }
    var nativeView: BrowserEngineView { view }
    var currentURL: URL? { url }
    var reportsNavigationState: Bool { true }

    // Servo draws its own links and pages; the services WebKit and Chromium
    // build on their engines are unavailable here.
    var linkHover: BrowserLinkHoverController? { nil }
    var linkDrag: BrowserLinkDragController? { nil }
    var pictureInPicture: (any BrowserPagePictureInPictureController)? { nil }
    var readerModeSession: BrowserReaderModeSession? { nil }
    var faviconSession: BrowserFaviconSession? { nil }
    var isContentBlockingActive: Bool { false }
    var credentialEvaluator: BrowserCredentialSession.Evaluate? { nil }
    var translationDocument: BrowserTranslationDocument? { nil }

    // MARK: - Initializers

    init(id: UUID, view: ServoPageView, pages: ServoEnginePages) {
        self.id = id
        self.view = view
        enginePage = EnginePage(
            id: id, pages: pages, historyFamily: .servo, historyVersion: { nil }, inspectorPanels: [])
        view.onEvent = { [weak self] event in self?.receive(event) }
    }

    // MARK: - Actions - Lifecycle

    func makeMediaSessionCoordinator(
        for page: BrowserPage,
        store: BrowserMediaSessionStore
    ) -> BrowserMediaSessionPageCoordinator? { nil }

    func attach(to page: BrowserPage, allowsCredentialAccess: Bool) {
        self.page = page
        reporter = EnginePageReporter(
            page: page.corePage,
            snapshot: { [weak self] pendingURL in
                self?.snapshot(pendingURL: pendingURL) ?? PageSnapshot.blank
            },
            history: { [weak self] in
                guard let self, !self.history.isEmpty else { return nil }
                return (self.history, self.currentEntry)
            })
    }

    func detach(from page: BrowserPage) {
        enginePage.close()
        view.close()
        view.removeFromSuperview()
        reporter = nil
    }

    func setPrivateBrowsing(_ isPrivate: Bool) {}
    func install(_ focusRestoration: BrowserWebFocusRestorationController) {}
    func monitorUserActivity(for page: BrowserPage) {}
    func styleVisitedLinks(history: [HistoryEntryState]) async {}
    func sitePermissionDidChange(_ permission: SitePermission, on page: BrowserPage) {}

    // MARK: - Actions - Navigation

    func load(_ request: URLRequest) {
        guard let url = request.url else { return }
        load(url, entryID: nil)
    }

    /// Loads `url`, whose entry takes `entryID` when the core names one.
    func load(_ url: URL, entryID: UUID?) {
        expectedEntryID = entryID
        reporter?.heading(to: url)
        view.load(url.absoluteString)
        DiagnosticLog.servo.notice("Page \(id) loads")
    }

    /// Shows the history entry the core named `entryID`; false when the page
    /// keeps no such entry.
    func goToEntry(_ entryID: UUID) -> Bool {
        guard let index = history.firstIndex(where: { $0.id == entryID }) else { return false }
        view.traverse(index - currentEntry)
        return true
    }

    /// What the page keeps when it closes keeping its state: the address it
    /// shows, which its next page loads.
    var restoreState: PageRestoreState? {
        url.map { PageRestoreState(url: $0.absoluteString, state: Data()) }
    }

    // MARK: - Actions - Events

    /// Servo reports a navigation's new address, then its history, then
    /// that a load started, in one turn; a move within the document reports
    /// the address alone. A page's first document may report no start.
    private func receive(_ event: ServoPageView.Event) {
        switch event {
        case .url(let text):
            guard let next = URL(string: text) else { return }
            let previous = url
            url = next
            page?.receive(BrowserPageURLChanged(previous: previous, current: next))
            addressChange = next
            DispatchQueue.main.async { [weak self] in self?.settleAddressChange(next) }
        case .loadStarted:
            begin()
        case .headParsed:
            if isLoading, !hasCommitted { commit() }
        case .loadComplete:
            guard isLoading else {
                completedEarly = !hasDocument
                return
            }
            finish()
        case .title(let text):
            title = text
            reporter?.titleChanged()
            page?.receive(BrowserPageTitleChanged())
        case .history(let urls, let current):
            adoptHistory(urls, current: current)
            reporter?.stateChanged()
            page?.receive(BrowserPageHistoryChanged())
        }
    }

    /// A load began, toward the address Servo just reported when it did.
    private func begin() {
        isLoading = true
        hasCommitted = false
        page?.receive(BrowserPageNavigationStarted())
        reporter?.started(addressChange ?? reporter?.pendingURL)
        if addressChange != nil {
            addressChange = nil
            commit()
        }
    }

    /// The address changed to `address` and no load started in that turn:
    /// the page's first document, or a move within the one it shows.
    private func settleAddressChange(_ address: URL) {
        guard addressChange == address else { return }
        addressChange = nil
        if hasDocument {
            reporter?.movedWithinDocument(to: address)
            return
        }
        addressChange = address
        begin()
        if completedEarly { finish() }
    }

    private func finish() {
        if !hasCommitted { commit() }
        isLoading = false
        completedEarly = false
        if let url { reporter?.finished(url, title: title) }
        page?.receive(BrowserPageLoadingChanged(isLoading: false))
    }

    private func commit() {
        guard let url else { return }
        hasCommitted = true
        hasDocument = true
        reporter?.committed(url)
        page?.receive(BrowserPageNavigationCommitted(url: url, isLoading: true))
    }

    /// Keeps each entry's identity while its address at its place holds; a
    /// new entry the core expected takes the identity it named.
    private func adoptHistory(_ urls: [String], current: Int) {
        let previous = history
        history = urls.enumerated().map { index, url in
            if index < previous.count, previous[index].url == url {
                return PageHistoryEntry(id: previous[index].id, url: url, title: previous[index].title)
            }
            let id = index == current ? (expectedEntryID ?? UUID()) : UUID()
            return PageHistoryEntry(id: id, url: url, title: "")
        }
        if history.indices.contains(current) { history[current].title = title }
        currentEntry = min(max(current, 0), max(history.count - 1, 0))
        expectedEntryID = nil
    }

    /// What the page shows now. Servo refuses a certificate it does not
    /// trust, so an `https` page it shows is secure.
    private func snapshot(pendingURL: String?) -> PageSnapshot {
        let security: PageSecurity =
            switch url?.scheme?.lowercased() {
            case "https": .secure
            case "http": .insecure
            default: .none
            }
        return PageSnapshot(
            url: url?.absoluteString, pendingURL: pendingURL, title: title, isLoading: isLoading, security: security,
            media: [])
    }
}
