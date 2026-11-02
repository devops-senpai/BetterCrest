import CryptoKit
import Foundation

/// Arma's Servo binding. It builds each page the core asks Servo to create,
/// a view Servo draws into, which the page's owner hosts, and runs the loads
/// and history moves the core asks for. Servo starts with the first page.
/// Its options are global to the process, so every profile's pages share one
/// Servo and one store of site data, kept on disk unless the launch keeps
/// nothing. Erasing a profile's data clears Servo's cookies, the only site
/// data it can clear; it cannot clear one site's alone. Servo asks nothing
/// of the person, opens no popups and downloads nothing, so the commands for
/// those do nothing here.
@MainActor
final class ServoEngineBinding: EngineBinding {
    // MARK: - Types

    private struct WeakPage {
        weak var value: ServoEnginePage?
    }

    // MARK: - Variables

    let integration = BrowserEngineRegistration.servo
    private(set) weak var engines: Engines?
    private let library: ServoLibrary
    /// Where Servo keeps site data, or nil to keep it in memory.
    private let profileDirectory: URL?
    /// Servo, once a page started it.
    private var engine: ServoEngine?
    private var pages: [UUID: WeakPage] = [:]
    /// The pages' direct path to the views this binding built.
    private(set) lazy var enginePages = ServoEnginePages { [weak self] in self?.page($0) }

    // MARK: - Initializers

    /// A binding over `library`, whose pages keep site data in
    /// `profileDirectory`, or in memory when it is nil.
    init(library: ServoLibrary, profileDirectory: URL?) {
        self.library = library
        self.profileDirectory = profileDirectory
    }

    /// The binding for this launch, or nil when the app carries no Servo.
    static func forLaunch(_ environment: BrowserLaunchEnvironment) -> ServoEngineBinding? {
        guard let library = ServoLibrary.shared else { return nil }
        return ServoEngineBinding(library: library, profileDirectory: profileDirectory(for: environment))
    }

    /// The installed app's Servo folder, or for a review launch one kept
    /// apart from it; a launch that keeps nothing keeps Servo's data in
    /// memory.
    private static func profileDirectory(for environment: BrowserLaunchEnvironment) -> URL? {
        guard !environment.usesEphemeralProfileStorage,
            var directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent(ProductIdentity.storageDirectoryName, isDirectory: true)
                .appendingPathComponent("Servo", isDirectory: true)
        else { return nil }
        if environment.requiresIsolation {
            guard let isolationID = environment.persistentIsolationID else { return nil }
            let namespace = SHA256.hash(data: Data(isolationID.utf8)).map { String(format: "%02x", $0) }.joined()
            directory = directory.appendingPathComponent("Isolated", isDirectory: true)
                .appendingPathComponent(namespace, isDirectory: true)
        }
        return directory
    }

    // MARK: - Actions - Binding

    func attach(to engines: Engines) {
        self.engines = engines
    }

    func run(_ command: EngineCommand) {
        guard engines != nil else { return }
        switch command {
        case .createPage(let command): create(command)
        case .closePage(let command): close(command)
        case .loadPage(let command):
            guard let url = URL(string: command.url) else { return }
            page(command.pageID)?.load(url, entryID: command.entryID)
        case .goToHistoryEntry(let command):
            guard let page = page(command.pageID) else { return }
            if !page.goToEntry(command.entryID) { page.reporter?.reportHistoryAgain() }
        case .recoverPage(let command): page(command.pageID)?.view.reload()
        case .checkBeforeUnload(let command):
            report(BeforeUnloadAnswered(pageID: command.pageID, proceeds: true))
        case .eraseBrowsingData(let command):
            engine?.clearCookies()
            report(DataErased(erasureID: command.erasureID, erased: true))
        case .eraseProfileData(let command):
            engine?.clearCookies()
            report(DataErased(erasureID: command.erasureID, erased: true))
        case .eraseSiteData(let command):
            report(DataErased(erasureID: command.erasureID, erased: false))
        case .readSiteData(let command):
            report(SiteDataRead(readingID: command.readingID, sites: [], read: true))
        case .stageNavigation(let command):
            report(StagedLinkUnavailable(pageID: command.pageID))
        case .adoptOfferedPage, .rejectOfferedPage, .dropStagedLink, .groupPages, .exitPictureInPicture,
            .approveEngineDownload, .cancelEngineDownload, .pauseEngineDownload, .resumeEngineDownload,
            .removeEngineDownload, .settleAuthentication, .settleDownloadDestination, .settleExtensionInstall,
            .settlePermission, .settleScriptDialog:
            break
        }
    }

    // MARK: - Actions - Pages

    /// The page this binding built as `pageID`, while its owner keeps it.
    func page(_ pageID: UUID) -> ServoEnginePage? {
        pages[pageID]?.value
    }

    /// Builds the page a platform asked for, or one the core moved to Servo
    /// from another engine, whose owner takes it before the core loads it.
    private func create(_ command: CreatePage) {
        guard let engines else { return }
        guard let built = build(command.pageID) else {
            report(PageCreationFailed(pageID: command.pageID))
            return
        }
        if let request = engines.request(command.pageID) {
            request.built = built
        } else if let moving = engines.page(command.pageID) {
            engines.handOver(built, movedPage: moving)
        } else {
            report(PageCreationFailed(pageID: command.pageID))
            return
        }
        if let restoring = command.restoreState, let url = URL(string: restoring.url) {
            built.load(url, entryID: nil)
        }
        DiagnosticLog.servo.notice("Built page \(command.pageID)")
        report(PageCreated(pageID: command.pageID))
    }

    private func build(_ pageID: UUID) -> ServoEnginePage? {
        if engine == nil, let started = ServoEngine(library: library, profileDirectory: profileDirectory) {
            engine = started
            let extensions = ServoExtensionStore.shared
            started.apply(extensions.extensions)
            extensions.installed = { [weak started] in started?.apply([$0]) }
        }
        guard let engine else { return nil }
        let page = ServoEnginePage(
            id: pageID, view: ServoPageView(library: library, engine: engine), pages: enginePages)
        pages = pages.filter { $0.value.value != nil }
        pages[pageID] = WeakPage(value: page)
        return page
    }

    /// A page that keeps its state hands the core the address it shows.
    private func close(_ command: ClosePage) {
        let page = pages.removeValue(forKey: command.pageID)?.value
        DiagnosticLog.servo.notice("Closed page \(command.pageID)")
        report(PageClosed(pageID: command.pageID, restoreState: command.keepsState ? page?.restoreState : nil))
    }

    private func report(_ event: some EngineEvent) {
        engines?.report(event, from: self)
    }
}

extension Engines {
    /// Servo's binding, when the composition registered it.
    var servo: ServoEngineBinding? { bindings[.servo] as? ServoEngineBinding }
}
