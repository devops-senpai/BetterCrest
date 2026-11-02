// Draws the installer disk image's window background: light Catppuccin
// Latte colors, Arma's logo, and an arrow from the app to Applications.
// Usage: swift Brand/Installer/make-background.swift <logo.png> <out-dir>
import AppKit

let logoPath = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]
let size = NSSize(width: 660, height: 420)

func color(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    let bounds = NSRect(origin: .zero, size: size)

    // Latte's base, warmed with lavender and sky glows.
    NSGradient(colors: [color(0xEFF1F5), color(0xE6E9EF)])!.draw(in: bounds, angle: -90)
    for (x, y, r, hex) in [(110.0, 360.0, 300.0, 0xCBA6F7), (560.0, 80.0, 320.0, 0x89DCEB), (560.0, 380.0, 220.0, 0xF5C2E7)] {
        NSGradient(colors: [color(hex, 0.32), color(hex, 0)])!.draw(
            fromCenter: NSPoint(x: x, y: y), radius: 0, toCenter: NSPoint(x: x, y: y), radius: r, options: [])
    }
    // Fine diagonal lines.
    cg.setStrokeColor(color(0x7287FD, 0.07).cgColor)
    cg.setLineWidth(1)
    var x = -size.height
    while x < size.width {
        cg.move(to: CGPoint(x: x, y: 0))
        cg.addLine(to: CGPoint(x: x + size.height, y: size.height))
        x += 14
    }
    cg.strokePath()

    // The logo and the name, above the two icons.
    if let logo = NSImage(contentsOfFile: logoPath) {
        logo.draw(in: NSRect(x: (size.width - 92) / 2, y: size.height - 120, width: 92, height: 92))
    }
    let title = NSAttributedString(
        string: "Arma",
        attributes: [.font: NSFont.systemFont(ofSize: 22, weight: .semibold), .foregroundColor: color(0x4C4F69)])
    title.draw(at: NSPoint(x: (size.width - title.size().width) / 2, y: size.height - 152))

    // The arrow from the app (left) to Applications (right).
    let arrowY: CGFloat = 175
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 262, y: arrowY))
    path.curve(to: NSPoint(x: 392, y: arrowY), controlPoint1: NSPoint(x: 300, y: arrowY + 26),
               controlPoint2: NSPoint(x: 354, y: arrowY + 26))
    path.lineWidth = 4
    path.lineCapStyle = .round
    color(0x8839EF, 0.85).setStroke()
    path.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 380, y: arrowY + 13))
    head.line(to: NSPoint(x: 394, y: arrowY))
    head.line(to: NSPoint(x: 377, y: arrowY - 6))
    head.lineWidth = 4
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    let hint = NSAttributedString(
        string: "Drag Arma to Applications",
        attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: color(0x6C6F85)])
    // Under the arrow, between the two icons, where every Finder shows it.
    hint.draw(at: NSPoint(x: (size.width - hint.size().width) / 2, y: arrowY - 34))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for (scale, name) in [(1.0, "background.png"), (2.0, "background@2x.png")] {
    let data = render(scale: scale).representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("Wrote background.png and background@2x.png to \(outDir)")
