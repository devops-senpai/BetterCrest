import Foundation

/// The command palette's look read for one appearance, and edited one surface
/// at a time.
extension SpacePaletteLook {
    // MARK: - Variables

    /// Whether either appearance tints the card.
    var isTinted: Bool { light.isTinted || dark.isTinted }

    // MARK: - Actions - Surfaces

    /// The surface the card wears in the dark appearance when `dark`, else the
    /// light one.
    func surface(dark: Bool) -> SpacePaletteSurface {
        dark ? self.dark : light
    }

    // MARK: - Mutators

    /// Replaces the surface of the appearance `dark` names.
    mutating func setSurface(_ surface: SpacePaletteSurface, dark: Bool) {
        if dark { self.dark = surface } else { light = surface }
    }
}

extension SpaceBranding {
    // MARK: - Mutators

    /// Gives the command palette `surface` for the appearance `dark` names,
    /// starting a look from the system material when the Space had none.
    mutating func setPaletteSurface(_ surface: SpacePaletteSurface, dark: Bool) {
        var look = commandPalette ?? .neutral
        look.setSurface(surface, dark: dark)
        commandPalette = look
    }

    /// Changes the command palette's surface for the appearance `dark` names
    /// in place, starting from the system material when the Space had none.
    mutating func editPaletteSurface<Failure: Error>(
        dark: Bool, _ edit: (inout SpacePaletteSurface) throws(Failure) -> Void
    ) throws(Failure) {
        var surface = (commandPalette ?? .neutral).surface(dark: dark)
        try edit(&surface)
        setPaletteSurface(surface, dark: dark)
    }
}

extension SpacePaletteSurface {
    // MARK: - Variables

    /// Whether this surface changes the card at all: a tint over the
    /// material, or a text color of its own.
    var isTinted: Bool { (tint != nil && opacity > 0) || textColor != nil }

    /// The tone the card's text reads in over this surface: the chosen text
    /// color's brightness, else the tint's when it mostly covers the
    /// material, else nil to follow the window.
    var foregroundTone: BrowserSpaceForegroundTone? {
        if let textColor { return textColor.luminance > 0.5 ? .light : .dark }
        guard let tint, opacity >= 0.5 else { return nil }
        return tint.luminance > 0.5 ? .dark : .light
    }

    // MARK: - Actions - Tinting

    /// This surface wearing `tint`. A tint picked over a surface that covered
    /// nothing covers the material the default way, so the pick shows.
    func tinted(_ tint: BrandColor?) -> SpacePaletteSurface {
        SpacePaletteSurface(
            tint: tint, opacity: tint != nil && opacity == 0 ? Self.defaultOpacity : opacity, textColor: textColor)
    }
}
