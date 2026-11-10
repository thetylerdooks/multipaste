// Draws the Multipaste app icon with AppKit and writes an .iconset folder.
// Usage: make_icon <output.iconset>
// Compiled and run by Scripts/build_app.sh; iconutil turns the result into AppIcon.icns.

import AppKit
import Foundation

func drawIcon(pixels: Int) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: pixels,
                                     pixelsHigh: pixels,
                                     bitsPerSample: 8,
                                     samplesPerPixel: 4,
                                     hasAlpha: true,
                                     isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0,
                                     bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: rep) else {
        return nil
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    let side = CGFloat(pixels)

    // Rounded-square background with a blue-to-indigo gradient.
    let inset = side * 0.09
    let backgroundRect = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let backgroundRadius = backgroundRect.width * 0.225
    let background = NSBezierPath(roundedRect: backgroundRect, xRadius: backgroundRadius, yRadius: backgroundRadius)
    let top = NSColor(srgbRed: 0.33, green: 0.52, blue: 1.00, alpha: 1)
    let bottom = NSColor(srgbRed: 0.36, green: 0.25, blue: 0.90, alpha: 1)
    if let gradient = NSGradient(starting: top, ending: bottom) {
        gradient.draw(in: background, angle: -90)
    } else {
        top.setFill()
        background.fill()
    }

    // Clipboard board.
    let boardRect = NSRect(x: side * 0.29, y: side * 0.22, width: side * 0.42, height: side * 0.52)
    let boardRadius = side * 0.05
    let board = NSBezierPath(roundedRect: boardRect, xRadius: boardRadius, yRadius: boardRadius)
    NSColor.white.setFill()
    board.fill()

    // Clip at the top of the board.
    let clipWidth = side * 0.20
    let clipHeight = side * 0.085
    let clipRect = NSRect(x: side * 0.5 - clipWidth / 2,
                          y: boardRect.maxY - clipHeight * 0.55,
                          width: clipWidth,
                          height: clipHeight)
    let clip = NSBezierPath(roundedRect: clipRect, xRadius: clipHeight * 0.35, yRadius: clipHeight * 0.35)
    NSColor(srgbRed: 0.16, green: 0.18, blue: 0.42, alpha: 1).setFill()
    clip.fill()

    // Three "copied lines" on the board.
    let lineHeight = side * 0.04
    let lineX = boardRect.minX + side * 0.06
    let fullWidth = boardRect.width - side * 0.12
    let lineWidths: [CGFloat] = [fullWidth, fullWidth, fullWidth * 0.6]
    let lineColor = NSColor(srgbRed: 0.36, green: 0.42, blue: 0.95, alpha: 1)
    for (index, width) in lineWidths.enumerated() {
        let y = boardRect.maxY - side * 0.16 - CGFloat(index) * side * 0.095
        let lineRect = NSRect(x: lineX, y: y, width: width, height: lineHeight)
        let line = NSBezierPath(roundedRect: lineRect, xRadius: lineHeight / 2, yRadius: lineHeight / 2)
        lineColor.withAlphaComponent(index == 2 ? 0.55 : 0.9).setFill()
        line.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let arguments = CommandLine.arguments
if arguments.count < 2 {
    FileHandle.standardError.write(Data("usage: make_icon <output.iconset>\n".utf8))
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
do {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
} catch {
    FileHandle.standardError.write(Data("make_icon: cannot create output folder: \(error)\n".utf8))
    exit(1)
}

// (file name, pixel size) pairs required by iconutil.
let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, pixels) in variants {
    guard let png = drawIcon(pixels: pixels) else {
        FileHandle.standardError.write(Data("make_icon: could not draw \(name)\n".utf8))
        exit(1)
    }
    do {
        try png.write(to: outputDirectory.appendingPathComponent(name))
    } catch {
        FileHandle.standardError.write(Data("make_icon: could not write \(name): \(error)\n".utf8))
        exit(1)
    }
}

print("make_icon: wrote \(variants.count) images to \(outputDirectory.path)")
