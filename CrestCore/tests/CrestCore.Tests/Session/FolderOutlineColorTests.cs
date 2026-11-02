using CrestCore.Application;
using CrestCore.Contracts;

using Xunit;

namespace CrestCore.Tests;

public sealed class FolderOutlineColorTests {
    /// A Space's folder outline color and its folder overrides by path survive
    /// the stored session, and a branding without them reads back without them.
    [Fact]
    public void FolderOutlineColorSurvivesTheStoredSession() {
        var outline = new BrandColor(0.05, 0.44, 0.58);
        var branding = SpaceBranding.Neutral with { FolderOutlineColor = outline };

        var stored = StoredSessionCodec.Encode(branding);
        Assert.Equal(outline, StoredSessionCodec.DecodeBranding(stored).FolderOutlineColor);

        var overrides = new FolderColorOverrides([
            new(".HomeLab.proxmox", new BrandColor(0.9, 0.95, 0.98), BackColor: null, OutlineColor: outline),
            new(".library", Color: null, new BrandColor(0.5, 0.8, 0.9), OutlineColor: null),
        ]);
        var overridden = SpaceBranding.Normalized(SpaceBranding.Neutral with { FolderOverrides = overrides });
        Assert.Equal(overrides, StoredSessionCodec.DecodeBranding(StoredSessionCodec.Encode(overridden)).FolderOverrides);

        var plain = StoredSessionCodec.Encode(SpaceBranding.Neutral);
        Assert.Null(StoredSessionCodec.DecodeBranding(plain).FolderOutlineColor);
        Assert.Null(StoredSessionCodec.DecodeBranding(plain).FolderOverrides);
    }
}
