import Foundation

extension CrestSymbol {
    // MARK: - Static Variables

    /// The figure a crest draws when it names none it can read, as the core
    /// reads it.
    static let fallback = CrestSymbol.mountain

    /// The figures the gallery offers, Arma's own birds first: the bird of
    /// its logo, then the crane.
    static let selectable: [CrestSymbol] = {
        let first: [CrestSymbol] = [.sparrow, .crane]
        return first + all.filter { $0.isOffered && !first.contains($0) }
    }()
}

extension CrestBackplate {
    // MARK: - Static Variables

    /// The shapes the gallery offers: None, then the guidon of Arma's
    /// logo, then the rest.
    static let offered: [CrestBackplate] = [.none, .flag] + all.filter { $0 != .none && $0 != .flag }
}
