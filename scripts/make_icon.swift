// Renders the LinkChoice app icon at all required sizes and assembles a
// .icns. Run once (or whenever the design changes) via:
//   swift scripts/make_icon.swift
// Not part of the app itself — a one-off asset generator.

import AppKit

let outDir = FileManager.default.currentDirectoryPath + "/LinkChoice.iconset"
try? FileManager.default.removeItem(atPath: outDir)
try! FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func renderIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.2237 // macOS "squircle" continuous-corner ratio

    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    path.addClip()

    // Dark slate gradient, matching the picker panel's own material.
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.27, alpha: 1.0),
        NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.13, alpha: 1.0),
    ])
    gradient?.draw(in: rect, angle: -90)

    // Subtle top highlight for depth.
    let highlight = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor.white.withAlphaComponent(0.06).setFill()
    highlight.fill()

    // Two overlapping rounded "choice" chips (abstract — deliberately not
    // mimicking any real browser's logo/colors) with a cursor arrow between
    // them, echoing cursorarrow.click.2 — "pick one of these".
    let chipSize = size * 0.30
    let chipRadius = chipSize * 0.28
    let leftChip = NSRect(x: size * 0.20, y: size * 0.36, width: chipSize, height: chipSize)
    let rightChip = NSRect(x: size * 0.50, y: size * 0.36, width: chipSize, height: chipSize)

    NSColor(calibratedRed: 0.98, green: 0.36, blue: 0.36, alpha: 0.92).setFill()
    NSBezierPath(roundedRect: leftChip, xRadius: chipRadius, yRadius: chipRadius).fill()

    NSColor(calibratedRed: 0.30, green: 0.62, blue: 0.98, alpha: 0.92).setFill()
    NSBezierPath(roundedRect: rightChip, xRadius: chipRadius, yRadius: chipRadius).fill()

    // Classic macOS pointer-cursor silhouette (7-point arrow), tip planted
    // right in the gap between the two chips — "about to click one".
    let gapX = (leftChip.maxX + rightChip.minX) / 2
    let tipX = gapX + size * 0.01
    let tipY = size * 0.615
    let s = size * 0.30 // cursor height
    func pt(_ nx: CGFloat, _ ny: CGFloat) -> NSPoint {
        // Normalized cursor space: (0,1)=tip, scaled by s, anchored at tip.
        NSPoint(x: tipX + nx * s, y: tipY - (1 - ny) * s)
    }
    let cursor = NSBezierPath()
    cursor.move(to: pt(0.00, 1.00))
    cursor.line(to: pt(0.00, 0.18))
    cursor.line(to: pt(0.22, 0.38))
    cursor.line(to: pt(0.35, 0.09))
    cursor.line(to: pt(0.46, 0.13))
    cursor.line(to: pt(0.33, 0.42))
    cursor.line(to: pt(0.60, 0.42))
    cursor.close()
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
    shadow.shadowBlurRadius = size * 0.018
    shadow.shadowOffset = NSSize(width: size * 0.006, height: -size * 0.012)
    shadow.set()
    NSColor.white.setFill()
    cursor.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor.black.withAlphaComponent(0.18).setStroke()
    cursor.lineWidth = size * 0.006
    cursor.stroke()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String, size: CGFloat) {
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:])
    else { fatalError("failed to encode \(path)") }
    try! data.write(to: URL(fileURLWithPath: path))
}

// Standard macOS iconset sizes.
let specs: [(name: String, px: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for spec in specs {
    let img = renderIcon(size: spec.px)
    savePNG(img, to: "\(outDir)/\(spec.name).png", size: spec.px)
}

print("Rendered iconset to \(outDir)")
print("Run: iconutil -c icns \(outDir) -o AppIcon.icns")
