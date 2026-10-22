// Draws the app icon (a halved tangerine, echoing the radial menu) and writes the asset catalog.
// Usage: swift scripts/make-icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func draw(size s: Int) -> CGImage? {
    let S = CGFloat(s)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(data: nil, width: s, height: s, bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.interpolationQuality = .high
    let center = CGPoint(x: S / 2, y: S / 2)

    // Tile (macOS icon grid: 824/1024 of the canvas) with a soft shadow.
    let inset = S * 0.0977
    let tile = CGRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: S * 0.185, cornerHeight: S * 0.185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.012), blur: S * 0.03, color: rgb(0, 0, 0, 0.35))
    ctx.addPath(tilePath); ctx.setFillColor(rgb(255, 255, 255)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    let tileGradient = CGGradient(colorsSpace: space, colors: [rgb(255, 255, 255), rgb(255, 230, 208)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(tileGradient, start: CGPoint(x: tile.minX, y: tile.maxY), end: CGPoint(x: tile.maxX, y: tile.minY), options: [])
    ctx.restoreGState()

    // Rind and pith.
    let rindRadius = S * 0.315
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.01), blur: S * 0.025, color: rgb(160, 60, 0, 0.45))
    ctx.setFillColor(rgb(245, 124, 0))
    ctx.fillEllipse(in: CGRect(x: center.x - rindRadius, y: center.y - rindRadius, width: rindRadius * 2, height: rindRadius * 2))
    ctx.restoreGState()
    let rindGradient = CGGradient(colorsSpace: space, colors: [rgb(255, 160, 40), rgb(230, 100, 0)] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: center.x - rindRadius, y: center.y - rindRadius, width: rindRadius * 2, height: rindRadius * 2)); ctx.clip()
    ctx.drawLinearGradient(rindGradient, start: CGPoint(x: center.x - rindRadius, y: center.y + rindRadius), end: CGPoint(x: center.x + rindRadius, y: center.y - rindRadius), options: [])
    ctx.restoreGState()
    let pithRadius = S * 0.285
    ctx.setFillColor(rgb(255, 244, 224))
    ctx.fillEllipse(in: CGRect(x: center.x - pithRadius, y: center.y - pithRadius, width: pithRadius * 2, height: pithRadius * 2))

    // Eight rounded segments.
    let segments = 8
    let innerR = S * 0.05, outerR = S * 0.255, gap = 0.3 // radians between segments
    let juice = CGGradient(colorsSpace: space, colors: [rgb(255, 132, 0), rgb(255, 190, 40)] as CFArray, locations: [0, 1])!
    for index in 0..<segments {
        let a1 = Double(index) * 2 * .pi / Double(segments) + gap / 2 - .pi / 2
        let a2 = Double(index + 1) * 2 * .pi / Double(segments) - gap / 2 - .pi / 2
        let path = CGMutablePath()
        let round = S * 0.009
        path.addArc(center: center, radius: outerR - round, startAngle: a1, endAngle: a2, clockwise: false)
        path.addArc(center: center, radius: innerR + round, startAngle: a2, endAngle: a1, clockwise: true)
        path.closeSubpath()
        // Fill the segment, then its rounded outline: two clips, because one combined clip would cancel out.
        for outlineOnly in [false, true] {
            ctx.saveGState()
            ctx.addPath(path)
            if outlineOnly {
                ctx.setLineJoin(.round)
                ctx.setLineWidth(round * 2)
                ctx.replacePathWithStrokedPath()
            }
            ctx.clip()
            ctx.drawRadialGradient(juice, startCenter: center, startRadius: innerR, endCenter: center, endRadius: outerR, options: [])
            ctx.restoreGState()
        }
    }

    // Leaf on the upper right.
    ctx.saveGState()
    ctx.translateBy(x: center.x + rindRadius * 0.62, y: center.y + rindRadius * 0.78)
    ctx.rotate(by: -.pi / 5)
    let leaf = CGMutablePath()
    let length = S * 0.2, width = S * 0.085
    leaf.move(to: .zero)
    leaf.addQuadCurve(to: CGPoint(x: length, y: 0), control: CGPoint(x: length * 0.5, y: width * 2))
    leaf.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.5, y: -width * 0.4))
    ctx.addPath(leaf); ctx.clip()
    let leafGradient = CGGradient(colorsSpace: space, colors: [rgb(120, 200, 70), rgb(40, 150, 70)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(leafGradient, start: .zero, end: CGPoint(x: length, y: width), options: [])
    ctx.restoreGState()

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let set = root.appendingPathComponent("Tangerine/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    if let image = draw(size: size) { writePNG(image, to: set.appendingPathComponent("icon_\(size).png")) }
}
let entries: [(file: Int, size: String, scale: String)] = [
    (16, "16x16", "1x"), (32, "16x16", "2x"), (32, "32x32", "1x"), (64, "32x32", "2x"),
    (128, "128x128", "1x"), (256, "128x128", "2x"), (256, "256x256", "1x"), (512, "256x256", "2x"),
    (512, "512x512", "1x"), (1024, "512x512", "2x"),
]
let images = entries.map { #"{"filename":"icon_\#($0.file).png","idiom":"mac","scale":"\#($0.scale)","size":"\#($0.size)"}"# }
try ("{\"images\":[" + images.joined(separator: ",") + "],\"info\":{\"author\":\"xcode\",\"version\":1}}\n")
    .write(to: set.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
try "{\"info\":{\"author\":\"xcode\",\"version\":1}}\n"
    .write(to: root.appendingPathComponent("Tangerine/Assets.xcassets/Contents.json"), atomically: true, encoding: .utf8)
print("icon written to \(set.path)")
