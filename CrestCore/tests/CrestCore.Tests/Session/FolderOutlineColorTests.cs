using CrestCore.Application;
using CrestCore.Contracts;

using Xunit;

namespace CrestCore.Tests;

public sealed class FolderOutlineColorTests {
    /// A Space's folder outline color survives the stored session, and a
    /// branding without one reads back without one.
    [Fact]
    public void FolderOutlineColorSurvivesTheStoredSession() {
        var outline = new BrandColor(0.05, 0.44, 0.58);
        var branding = SpaceBranding.Neutral with { FolderOutlineColor = outline };

        var stored = StoredSessionCodec.Encode(branding);
        Assert.Equal(outline, StoredSessionCodec.DecodeBranding(stored).FolderOutlineColor);

        var plain = StoredSessionCodec.Encode(SpaceBranding.Neutral);
        Assert.Null(StoredSessionCodec.DecodeBranding(plain).FolderOutlineColor);
    }
}
