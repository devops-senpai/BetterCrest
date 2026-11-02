import SwiftUI

#if canImport(AppKit)
    import AppKit
#endif

/// A color chosen in a popover: a hue and saturation wheel, a brightness
/// slider, a hex field and, on the Mac, the screen eyedropper. Each change
/// applies as it is made; the popover closes like any other when the person
/// clicks elsewhere.
struct BrowserColorWheelPicker: View {
    @Binding var color: BrandColor
    var title: LocalizedStringKey

    @State private var hue = 0.0
    @State private var saturation = 0.0
    @State private var brightness = 1.0
    @State private var hexDraft = ""

    private static let wheelSize: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: CrestSpacing.medium) {
            Text(title).font(.subheadline.weight(.semibold))
            wheel
            HStack(spacing: CrestSpacing.small) {
                Image(systemName: "sun.min").foregroundStyle(.secondary).accessibilityHidden(true)
                Slider(value: $brightness, in: 0...1) { Text("Brightness") }
                    .onChange(of: brightness) { apply() }
                Image(systemName: "sun.max").foregroundStyle(.secondary).accessibilityHidden(true)
            }
            HStack(spacing: CrestSpacing.small) {
                RoundedRectangle(cornerRadius: 5).fill(color.color)
                    .frame(width: 28, height: 22)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.18)))
                    .accessibilityHidden(true)
                TextField("Hex Color", text: $hexDraft, prompt: Text(verbatim: "#666666"))
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .onSubmit(applyHex)
                #if canImport(AppKit)
                    Button {
                        NSColorSampler().show { picked in
                            guard let picked = picked?.usingColorSpace(.sRGB) else { return }
                            set(BrandColor(color: Color(nsColor: picked)))
                        }
                    } label: {
                        Image(systemName: "eyedropper")
                    }
                    .buttonStyle(CrestChromeButtonStyle())
                    .help("Pick from Screen")
                    .accessibilityLabel("Pick from Screen")
                #endif
            }
        }
        .padding(CrestSpacing.large)
        .frame(width: 236)
        .onAppear { read(color) }
    }

    private var wheel: some View {
        ZStack {
            Circle().fill(
                AngularGradient(
                    colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12).map {
                        Color(hue: $0, saturation: 1, brightness: 1)
                    }, center: .center))
            Circle().fill(
                RadialGradient(
                    colors: [.white, .white.opacity(0)], center: .center, startRadius: 0,
                    endRadius: Self.wheelSize / 2))
            Circle().fill(.black.opacity(1 - brightness))
            Circle()
                .strokeBorder(.white, lineWidth: 2)
                .background(Circle().fill(color.color))
                .frame(width: 16, height: 16)
                .shadow(radius: 1)
                .offset(knobOffset)
        }
        .frame(width: Self.wheelSize, height: Self.wheelSize)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0).onChanged { drag in
                let radius = Self.wheelSize / 2
                let dx = drag.location.x - radius
                let dy = drag.location.y - radius
                saturation = min(1, hypot(dx, dy) / radius)
                var angle = atan2(dy, dx) / (2 * .pi)
                if angle < 0 { angle += 1 }
                hue = angle
                apply()
            }
        )
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Color Wheel")
    }

    private var knobOffset: CGSize {
        let radius = Self.wheelSize / 2 * saturation
        return CGSize(width: cos(hue * 2 * .pi) * radius, height: sin(hue * 2 * .pi) * radius)
    }

    private func apply() {
        set(BrandColor(color: Color(hue: hue, saturation: saturation, brightness: brightness)), readsBack: false)
    }

    private func applyHex() {
        if let typed = BrandColor(hex: hexDraft) { set(typed) } else { hexDraft = color.hexText }
    }

    private func set(_ next: BrandColor, readsBack: Bool = true) {
        color = next
        hexDraft = next.hexText
        if readsBack { read(next) }
    }

    /// Places the wheel's knob and the slider where `color` sits.
    private func read(_ color: BrandColor) {
        let (r, g, b) = (color.red, color.green, color.blue)
        let maximum = max(r, g, b)
        let minimum = min(r, g, b)
        let delta = maximum - minimum
        brightness = maximum
        saturation = maximum == 0 ? 0 : delta / maximum
        if delta > 0 {
            var h: Double
            if maximum == r {
                h = (g - b) / delta
            } else if maximum == g {
                h = 2 + (b - r) / delta
            } else {
                h = 4 + (r - g) / delta
            }
            h /= 6
            hue = h < 0 ? h + 1 : h
        }
        hexDraft = color.hexText
    }
}
