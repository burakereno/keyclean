#!/usr/bin/env swift
import AppKit
import Foundation

// Keep docs/icon.png as the full-bleed source; legacy macOS ICNS files need
// their own rounded silhouette and transparent margins.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let sourceURL = root.appendingPathComponent("docs/icon.png")
let outputURL = root.appendingPathComponent("Sources/KeyClean/Resources/AppIcon.icns")
guard let artwork = NSImage(contentsOf: sourceURL) else {
    fatalError("Cannot read \(sourceURL.path)")
}

func render(size: Int, draw: () -> Void) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: size * 4, bitsPerPixel: 32
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill(using: .copy)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

let master = render(size: 1024) {
    let bounds = NSRect(x: 100, y: 100, width: 824, height: 824)
    let silhouette = NSBezierPath(roundedRect: bounds, xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 18
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor.black.setFill()
    silhouette.fill()
    NSGraphicsContext.restoreGraphicsState()
    silhouette.addClip()
    artwork.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
}
let masterImage = NSImage(size: NSSize(width: 1024, height: 1024))
masterImage.addRepresentation(master)

let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("KeyCleanIcon-\(UUID().uuidString)")
let iconset = temporary.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let bitmap = render(size: pixels) {
            masterImage.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        }
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(points)x\(points)\(suffix).png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Generated \(outputURL.path)")
