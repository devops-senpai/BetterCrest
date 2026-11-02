import Foundation

/// `arma crest`, run in the app on a Space's own crest or icon, as its
/// Appearance page shapes it.
extension TerminalCrestCommand {
    // MARK: - Types

    private struct Shown: Encodable {
        let space: String
        let style: String
        let shape: String
        let field: String
        let band: String
        let emblem: String
        let border: String
        let finish: String
        let symbol: String
        let colors: [String: String]
        let iconColor: String
    }

    // MARK: - Actions - Running

    @MainActor
    func run(in terminal: BrowserMacTerminal) throws(BrowserMacTerminal.Refusal) -> TerminalOutput {
        let browser = terminal.browser
        switch self {
        case .show(let name):
            return Self.show(try terminal.space(name))
        case .set(let name, let changes):
            let space = try terminal.unlocked(try terminal.space(name))
            var look = space.settings.look
            if let style = changes.style { look.iconStyle = style == "icon" ? .simpleSymbol : .layeredCrest }
            if let shape = changes.shape {
                look.crest.backplate = try Self.pick(shape, CrestBackplate.all, \.name, "--shape")
            }
            if let field = changes.field {
                look.crest.fieldDivision = try Self.pick(field, CrestFieldDivision.all, \.name, "--field")
            }
            if let band = changes.band {
                look.crest.ordinary = try Self.pick(band, CrestOrdinary.all, \.name, "--band")
            }
            if let emblem = changes.emblem {
                look.crest.symbol = try Self.pick(emblem, CrestSymbol.selectable, \.name, "--emblem")
                look.crest.charge = nil
            }
            if let border = changes.border {
                look.crest.trim = try Self.pick(border, CrestTrim.all, \.name, "--border")
            }
            if let finish = changes.finish {
                look.crest.finish = try Self.pick(finish, CrestFinish.all, \.name, "--finish")
            }
            for (word, text) in changes.colors {
                guard let index = Self.layerWords.firstIndex(of: word),
                    let color = try Self.color(text)
                else { continue }
                look.setForgeColor(color, of: BrowserCrestForgeLayer.all[index])
            }
            if let text = changes.iconColor { look.symbolColor = try Self.color(text) }
            look.hasCustomAppearance = true
            Self.save(look, of: space, in: browser)
            if let symbol = changes.symbol ?? changes.emoji.map(BrowserIconSymbol.symbol(forEmoji:)) {
                browser.updateSpaceIdentity(
                    space.id, name: space.settings.name, symbol: symbol, accent: space.settings.accent)
            }
            return Self.show(try terminal.space(space.id.uuidString))
        case .shuffle(let name):
            let space = try terminal.unlocked(try terminal.space(name))
            let current = space.settings.look
            var look = BrowserCrestForge.shuffled(current)
            // The sidebar is the theme's: only the crest changes.
            look.themeMode = current.themeMode
            look.bannerPattern = current.bannerPattern
            look.gradientAngle = current.gradientAngle
            look.colors = current.colors
            Self.save(look, of: space, in: browser)
            return Self.show(try terminal.space(space.id.uuidString))
        }
    }

    /// The layers a color option names, in `BrowserCrestForgeLayer.all`'s order.
    static let layerWords = ["field", "second-field", "band", "emblem", "border", "edge"]

    // MARK: - Actions - Showing

    @MainActor
    private static func show(_ space: SpaceModel) -> TerminalOutput {
        let look = space.settings.look
        let crest = look.crest
        let colors = Dictionary(
            uniqueKeysWithValues: zip(layerWords, BrowserCrestForgeLayer.all).map {
                ($0, CrestTheme.text(look.forgeColor(of: $1)))
            })
        let shown = Shown(
            space: space.settings.name, style: look.iconStyle == .simpleSymbol ? "icon" : "crest",
            shape: crest.backplate.name, field: crest.fieldDivision.name, band: crest.ordinary.name,
            emblem: crest.symbol.name, border: crest.trim.name, finish: crest.finish.name,
            symbol: BrowserIconSymbol.emoji(from: space.settings.symbol) ?? space.settings.symbol, colors: colors,
            iconColor: CrestTheme.text(look.resolvedSymbolColor))
        let lines = [
            "Space    \(shown.space)",
            "Style    \(shown.style)",
            "Shape    \(shown.shape)",
            "Field    \(shown.field)",
            "Band     \(shown.band)",
            "Emblem   \(shown.emblem)",
            "Border   \(shown.border)",
            "Finish   \(shown.finish)",
            "Icon     \(shown.symbol)  \(shown.iconColor)",
            "Colors   " + layerWords.map { "\($0) \(colors[$0] ?? "")" }.joined(separator: "  "),
            "",
            "Shapes   " + CrestBackplate.all.map(\.name).joined(separator: ", "),
            "Fields   " + CrestFieldDivision.all.map(\.name).joined(separator: ", "),
            "Bands    " + CrestOrdinary.all.map(\.name).joined(separator: ", "),
            "Emblems  " + CrestSymbol.selectable.map(\.name).joined(separator: ", "),
            "Borders  " + CrestTrim.all.map(\.name).joined(separator: ", "),
            "Finishes " + CrestFinish.all.map(\.name).joined(separator: ", "),
        ]
        return TerminalOutput(text: lines.joined(separator: "\n"), value: shown)
    }

    // MARK: - Actions - Reading

    /// The one of `all` whose name is `text`, in any case.
    private static func pick<Value>(
        _ text: String, _ all: [Value], _ name: KeyPath<Value, String>, _ option: String
    ) throws(BrowserMacTerminal.Refusal) -> Value {
        if let value = all.first(where: { $0[keyPath: name].lowercased() == text.lowercased() }) { return value }
        throw .init("\(option) is one of \(all.map { $0[keyPath: name] }.joined(separator: ", ")), not '\(text)'.")
    }

    private static func color(_ text: String) throws(BrowserMacTerminal.Refusal) -> BrandColor? {
        do {
            return try CrestTheme.color(text)
        } catch {
            throw .init(error.message)
        }
    }

    // MARK: - Mutators

    /// Gives Space `space` the look `look`, whose crest, icon style and icon
    /// color its dark look wears too.
    @MainActor
    private static func save(_ look: SpaceBranding, of space: SpaceModel, in browser: BrowserStore) {
        browser.updateSpaceBranding(look.normalized(), in: space.id)
        guard var dark = space.settings.darkBranding else { return }
        dark.crest = look.crest
        dark.iconStyle = look.iconStyle
        dark.symbolColor = look.symbolColor
        browser.updateSpaceDarkBranding(dark.normalized(), in: space.id)
    }
}
