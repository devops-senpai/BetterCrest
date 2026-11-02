import Foundation

/// Servo's direct path from the platform to its pages. Servo answers the
/// requests its pages can carry out, such as a reload; every other request
/// answers that nothing was done, or that the page holds nothing to report.
@MainActor
final class ServoEnginePages: EnginePages {
    // MARK: - Variables

    /// The pages the binding built, by identity.
    private let page: @MainActor (UUID) -> ServoEnginePage?
    private var attached = AttachedEnginePages()

    // MARK: - Initializers

    init(page: @escaping @MainActor (UUID) -> ServoEnginePage?) {
        self.page = page
    }

    // MARK: - Actions - Requests

    @discardableResult
    func request<Request: PageRequest>(_ request: Request) -> Request.Answer {
        let done = (request as? any ServoPageRequest).map { $0.perform(in: self) } ?? false
        return Self.answer(done, to: Request.self)
    }

    func attach(_ page: EnginePage) {
        attached.attach(page)
    }

    /// The page `pageID` names, while its owner keeps it.
    func servoPage(_ pageID: UUID) -> ServoEnginePage? {
        page(pageID)
    }

    /// `done` for a request answered yes or no; for any other, the answer
    /// that holds nothing, decoded from the wire's empty values.
    private static func answer<Request: PageRequest>(_ done: Bool, to _: Request.Type) -> Request.Answer {
        let isYesOrNo = Request.Answer.self == Bool.self
        var reader = WireReader([isYesOrNo && done ? 1 : 0] + Array(repeating: 0, count: 63))
        do {
            return try Request.decodeAnswer(from: &reader)
        } catch {
            preconditionFailure("\(Request.self) has no empty answer: \(error)")
        }
    }
}

/// A page request Servo carries out.
protocol ServoPageRequest {
    /// Carries the request out on the pages `pages` holds; false when it
    /// could not.
    @MainActor func perform(in pages: ServoEnginePages) -> Bool
}

extension ReloadPage: ServoPageRequest {
    @MainActor func perform(in pages: ServoEnginePages) -> Bool {
        guard let page = pages.servoPage(pageID) else { return false }
        page.view.reload()
        return true
    }
}
