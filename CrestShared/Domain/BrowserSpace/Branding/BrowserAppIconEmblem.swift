import Foundation

/// An app icon that draws one of the other banners in `Brand/AppIcons` as
/// designed, beside the default icon and its palette variants. `id` is the
/// icon's name in the asset catalog, which the pickers select by.
struct BrowserAppIconEmblem: Identifiable, Sendable {
    // MARK: - Static Variables

    /// Every emblem, in the order the pickers show them.
    static let all: [BrowserAppIconEmblem] = [
        BrowserAppIconEmblem(id: "ArmaFlight", title: "Flight"),
        BrowserAppIconEmblem(id: "ArmaFlame", title: "Flame"),
        BrowserAppIconEmblem(id: "ArmaScarlet", title: "Scarlet"),
        BrowserAppIconEmblem(id: "ArmaRaven", title: "Raven"),
        BrowserAppIconEmblem(id: "ArmaPorcelain", title: "Porcelain"),
        BrowserAppIconEmblem(id: "ArmaSlate", title: "Slate"),
        BrowserAppIconEmblem(id: "ArmaSignal", title: "Signal"),
        BrowserAppIconEmblem(id: "ArmaSash", title: "Sash"),
        BrowserAppIconEmblem(id: "ArmaHorizon", title: "Horizon"),
        BrowserAppIconEmblem(id: "ArmaCrimson", title: "Crimson"),
        BrowserAppIconEmblem(id: "ArmaBlush", title: "Blush"),
        BrowserAppIconEmblem(id: "ArmaFrost", title: "Frost"),
        BrowserAppIconEmblem(id: "ArmaRuby", title: "Ruby"),
        BrowserAppIconEmblem(id: "ArmaRose", title: "Rose"),
        BrowserAppIconEmblem(id: "ArmaSilver", title: "Silver"),
        BrowserAppIconEmblem(id: "ArmaAmethyst", title: "Amethyst"),
        BrowserAppIconEmblem(id: "ArmaOrchid", title: "Orchid"),
        BrowserAppIconEmblem(id: "ArmaIris", title: "Iris"),
        BrowserAppIconEmblem(id: "ArmaLilac", title: "Lilac"),
        BrowserAppIconEmblem(id: "ArmaViolet", title: "Violet"),
        BrowserAppIconEmblem(id: "ArmaPlum", title: "Plum"),
        BrowserAppIconEmblem(id: "ArmaCrane", title: "Crane"),
        BrowserAppIconEmblem(id: "ArmaDrift", title: "Drift"),
        BrowserAppIconEmblem(id: "ArmaOrigami", title: "Origami"),
        BrowserAppIconEmblem(id: "ArmaSteel", title: "Steel"),
        BrowserAppIconEmblem(id: "ArmaGarnet", title: "Garnet"),
        BrowserAppIconEmblem(id: "ArmaWisteria", title: "Wisteria"),
        BrowserAppIconEmblem(id: "ArmaImperial", title: "Imperial"),
        BrowserAppIconEmblem(id: "ArmaAureate", title: "Aureate"),
        BrowserAppIconEmblem(id: "ArmaLaurel", title: "Laurel"),
        BrowserAppIconEmblem(id: "ArmaMarble", title: "Marble"),
        BrowserAppIconEmblem(id: "ArmaTriumph", title: "Triumph"),
        BrowserAppIconEmblem(id: "ArmaMosaic", title: "Mosaic"),
        BrowserAppIconEmblem(id: "ArmaVerdigris", title: "Verdigris"),
        BrowserAppIconEmblem(id: "ArmaCopper", title: "Copper"),
        BrowserAppIconEmblem(id: "ArmaPorphyry", title: "Porphyry"),
        BrowserAppIconEmblem(id: "ArmaLapis", title: "Lapis"),
        BrowserAppIconEmblem(id: "ArmaPatina", title: "Patina"),
        BrowserAppIconEmblem(id: "ArmaArgent", title: "Argent"),
        BrowserAppIconEmblem(id: "ArmaSenate", title: "Senate"),
        BrowserAppIconEmblem(id: "ArmaVexillum", title: "Vexillum"),
        BrowserAppIconEmblem(id: "ArmaBronze", title: "Bronze"),
        BrowserAppIconEmblem(id: "ArmaTessera", title: "Tessera"),
        BrowserAppIconEmblem(id: "ArmaVictory", title: "Victory"),
    ]

    // MARK: - Variables

    let id: String
    let title: LocalizedStringResource
}
