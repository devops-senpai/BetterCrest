import Foundation

/// `arma crest`.
enum TerminalCrestCommandLine: TerminalSection {
    static let name = "crest"
    static let summary = "Shape and color a Space's own crest or icon"
    static let switches: Set<String> = []
    static let usage = """
        usage: arma crest <action> [options]

          show [--space <space>]        a Space's crest or icon, and its colors
          set [--space <space>] [options]
                                        change a Space's crest or icon
          shuffle [--space <space>]     new parts and colors for a Space's crest

        Without --space, the Space the front window shows.

        Options:
          --style crest|icon            a heraldic crest, or a symbol or emoji alone
          --shape <name>                the crest's plate, such as shield, circle or seal
          --field <name>                how the field divides, such as plain or quarterly
          --band <name>                 the band across it, such as none, pale or fess
          --emblem <name>               the crest's figure, such as dragon, lion or rose
          --border <name>               the trim, such as none, line or laurel
          --finish flat|sheen|embossed
          --symbol <sf-symbol>          the icon's SF Symbol, such as leaf.fill
          --emoji <emoji>               the icon's emoji

          --field-color <hex>   --second-field-color <hex>   --band-color <hex>
          --emblem-color <hex>  --border-color <hex>         --edge-color <hex>
          --icon-color <hex>            the icon's color

        arma crest show lists every name each part takes. The crest's colors are the
        Space's own: no theme changes them, and they color nothing else in the window.

        """

    /// The layers a color option names, by the word before `-color`.
    static let layers = ["field", "second-field", "band", "emblem", "border", "edge"]

    static func command(action: String, _ arguments: inout TerminalArguments) throws(TerminalArguments.Problem)
        -> TerminalCommand
    {
        let space = arguments.option("space")
        switch action {
        case "show":
            return .crest(.show(space: space ?? arguments.takeIfPresent()))
        case "shuffle":
            return .crest(.shuffle(space: space ?? arguments.takeIfPresent()))
        case "set", "edit":
            var changes = TerminalCrestChanges()
            changes.style = arguments.option("style")
            if let style = changes.style, !["crest", "icon"].contains(style) {
                throw TerminalArguments.Problem(message: "--style is crest or icon, not '\(style)'.")
            }
            changes.shape = arguments.option("shape")
            changes.field = arguments.option("field")
            changes.band = arguments.option("band")
            changes.emblem = arguments.option("emblem")
            changes.border = arguments.option("border")
            changes.finish = arguments.option("finish")
            changes.symbol = arguments.option("symbol")
            changes.emoji = arguments.option("emoji")
            for layer in layers {
                guard let text = arguments.option(layer + "-color") else { continue }
                guard CrestThemeHex.components(text) != nil else {
                    throw TerminalArguments.Problem(message: "--\(layer)-color takes a color such as #336699.")
                }
                changes.colors[layer] = text
            }
            if let text = arguments.option("icon-color") {
                guard CrestThemeHex.components(text) != nil else {
                    throw TerminalArguments.Problem(message: "--icon-color takes a color such as #336699.")
                }
                changes.iconColor = text
            }
            guard !changes.isEmpty else { throw TerminalArguments.Problem(message: "Name something to change.") }
            return .crest(.set(space: space ?? arguments.takeIfPresent(), changes: changes))
        default:
            throw TerminalArguments.Problem(message: "arma crest has no action '\(action)'.")
        }
    }
}
