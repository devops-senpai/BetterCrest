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

extension SpaceHouse {
    // MARK: - Static Variables

    /// The houses the galleries offer, Arma's own first.
    static let offered: [SpaceHouse] = [.arma] + all.filter { $0 != .arma }

    /// The houses that bring an app icon of their own; Arma's is the app's
    /// own icon, which the picker offers first already.
    static let withAppIcons: [SpaceHouse] = all.filter { $0 != .arma }
}

extension SpaceBranding {
    /// This look under Arma's own arms: the guidon, pale and bird of its logo,
    /// in this look's colors, as the core dresses a new Space.
    var wearingArmaArms: SpaceBranding {
        var look = self
        look.crest.backplate = .flag
        look.crest.ordinary = .pale
        look.crest.symbol = .sparrow
        look.crest.charge = nil
        return look
    }
}

extension CrestBackplate {
    // MARK: - Static Variables

    /// The shapes the gallery offers: None, then the guidon of Arma's
    /// logo, then the rest.
    static let offered: [CrestBackplate] = [.none, .flag] + all.filter { $0 != .none && $0 != .flag }
}
