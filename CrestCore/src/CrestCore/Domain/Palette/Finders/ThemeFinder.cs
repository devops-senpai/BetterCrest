using CrestCore.Contracts;

namespace CrestCore.Domain;

/// The saved themes the platform keeps whose names or initials match once two
/// letters are typed, or every one when the person narrowed the palette to
/// them and typed nothing.
internal sealed class ThemeFinder : PaletteFinder {
    #region Actions - Finding

    internal override IEnumerable<PaletteCandidate> Find(PaletteContext context, PaletteSource source, PaletteQuery query,
        PaletteSuggestions question, bool narrowed) {
        if (!narrowed && query.Text.Length < 2) yield break;
        foreach (var theme in question.Themes) {
            int? score = query.IsEmpty ? 0 : query.Score(theme.Name, "theme") ?? query.Abbreviates(theme.Name);
            if (score is not { } matched) continue;
            var row = PaletteRow.Of(PaletteRowKind.Theme, theme.Name, theme.Detail, subject: theme.Id);
            yield return Scored(context, source, row, context.Matched(query, row, matched), place: null, fallback: null);
        }
    }

    #endregion
}
