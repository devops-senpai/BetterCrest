import SwiftUI

/// Arma's banner on a tile: the start page's mark, the start page tab's icon
/// and the onboarding and Getting Started emblem.
struct CrestStartPageMark: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let palette = CrestStartPageMarkPalette(colorScheme: colorScheme)
            let tile = RoundedRectangle(
                cornerRadius: side * CrestStartPageMarkMetrics.cornerRadiusRatio, style: .continuous)

            tile.fill(palette.background)
                .overlay {
                    Image("ArmaMark")
                        .resizable()
                        .scaledToFit()
                        .padding(side * CrestStartPageMarkMetrics.bannerInsetRatio)
                }
                .overlay {
                    tile.strokeBorder(
                        .primary.opacity(CrestStartPageMarkMetrics.borderOpacity),
                        lineWidth: CrestStartPageMarkMetrics.borderWidth)
                }
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}

#if DEBUG
    #Preview("Component") {
        CrestStartPageMark().frame(width: 80, height: 80).padding()
    }
#endif
