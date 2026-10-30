namespace CrestCore.Contracts;

/// <summary>
/// How the command palette's card looks over a Space: one surface for the light
/// appearance and one for the dark, each a tint laid over the system material at
/// an opacity of its own. A Space without a palette look leaves the card to the
/// system material alone.
/// </summary>
public sealed record SpacePaletteLook(SpacePaletteSurface Light, SpacePaletteSurface Dark) {
    #region Static Variables

    /// The look that leaves both appearances to the system material.
    public static SpacePaletteLook Neutral { get; } = new(SpacePaletteSurface.Neutral, SpacePaletteSurface.Neutral);

    #endregion

    #region Variables

    /// Whether either appearance tints the card.
    public bool IsTinted => Light.IsTinted || Dark.IsTinted;

    #endregion

    #region Actions - Surfaces

    /// The surface the card wears in the dark appearance when `dark`, else the light one.
    public SpacePaletteSurface Surface(bool dark) => dark ? Dark : Light;

    #endregion
}

/// <summary>
/// One appearance's palette card surface: <see cref="Tint"/> laid over the system
/// material, covering it <see cref="Opacity"/> of the way, from 0 for the material
/// alone to 1 for the solid tint. Without a tint the card is the material alone.
/// <see cref="TextColor"/> is the one color the card's text reads in, or null for the system's.
/// </summary>
public sealed record SpacePaletteSurface(BrandColor? Tint, double Opacity, BrandColor? TextColor) {
    #region Static Variables

    /// The system material alone.
    public static SpacePaletteSurface Neutral { get; } = new(Tint: null, Opacity: 0, TextColor: null);

    /// How far a tint covers the material when someone first picks one.
    public const double DefaultOpacity = 0.6;

    #endregion

    #region Variables

    /// Whether this surface tints the card at all.
    public bool IsTinted => (Tint is not null && Opacity > 0) || TextColor is not null;

    #endregion
}
