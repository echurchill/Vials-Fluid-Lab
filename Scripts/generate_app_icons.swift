import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct IconSpec {
    let filename: String
    let pixels: Int
}

let outputDirectory = URL(fileURLWithPath: "Vials/Assets.xcassets/AppIcon.appiconset")
let specs: [IconSpec] = [
    IconSpec(filename: "AppIcon-iPhone-20@2x.png", pixels: 40),
    IconSpec(filename: "AppIcon-iPhone-20@3x.png", pixels: 60),
    IconSpec(filename: "AppIcon-iPhone-29@2x.png", pixels: 58),
    IconSpec(filename: "AppIcon-iPhone-29@3x.png", pixels: 87),
    IconSpec(filename: "AppIcon-iPhone-40@2x.png", pixels: 80),
    IconSpec(filename: "AppIcon-iPhone-40@3x.png", pixels: 120),
    IconSpec(filename: "AppIcon-iPhone-60@2x.png", pixels: 120),
    IconSpec(filename: "AppIcon-iPhone-60@3x.png", pixels: 180),
    IconSpec(filename: "AppIcon-iPad-20@1x.png", pixels: 20),
    IconSpec(filename: "AppIcon-iPad-20@2x.png", pixels: 40),
    IconSpec(filename: "AppIcon-iPad-29@1x.png", pixels: 29),
    IconSpec(filename: "AppIcon-iPad-29@2x.png", pixels: 58),
    IconSpec(filename: "AppIcon-iPad-40@1x.png", pixels: 40),
    IconSpec(filename: "AppIcon-iPad-40@2x.png", pixels: 80),
    IconSpec(filename: "AppIcon-iPad-76@1x.png", pixels: 76),
    IconSpec(filename: "AppIcon-iPad-76@2x.png", pixels: 152),
    IconSpec(filename: "AppIcon-iPad-83.5@2x.png", pixels: 167),
    IconSpec(filename: "AppIcon-macOS-16@1x.png", pixels: 16),
    IconSpec(filename: "AppIcon-macOS-16@2x.png", pixels: 32),
    IconSpec(filename: "AppIcon-macOS-32@1x.png", pixels: 32),
    IconSpec(filename: "AppIcon-macOS-32@2x.png", pixels: 64),
    IconSpec(filename: "AppIcon-macOS-128@1x.png", pixels: 128),
    IconSpec(filename: "AppIcon-macOS-128@2x.png", pixels: 256),
    IconSpec(filename: "AppIcon-macOS-256@1x.png", pixels: 256),
    IconSpec(filename: "AppIcon-macOS-256@2x.png", pixels: 512),
    IconSpec(filename: "AppIcon-macOS-512@1x.png", pixels: 512),
    IconSpec(filename: "AppIcon-macOS-512@2x.png", pixels: 1024),
    IconSpec(filename: "AppIcon-marketing-1024@1x.png", pixels: 1024)
]

struct Palette {
    static let backdropTop = CGColor(red: 0.09, green: 0.07, blue: 0.24, alpha: 1)
    static let backdropBottom = CGColor(red: 0.03, green: 0.05, blue: 0.14, alpha: 1)
    static let glass = CGColor(red: 0.58, green: 0.66, blue: 1.00, alpha: 0.88)
    static let glassDark = CGColor(red: 0.19, green: 0.22, blue: 0.45, alpha: 0.70)
    static let rim = CGColor(red: 0.88, green: 0.91, blue: 1.00, alpha: 0.58)
    static let orange = CGColor(red: 1.00, green: 0.37, blue: 0.07, alpha: 1)
    static let cyan = CGColor(red: 0.10, green: 0.70, blue: 0.95, alpha: 1)
    static let green = CGColor(red: 0.00, green: 0.42, blue: 0.22, alpha: 1)
    static let pink = CGColor(red: 0.98, green: 0.33, blue: 0.68, alpha: 1)
    static let yellow = CGColor(red: 1.00, green: 0.76, blue: 0.09, alpha: 1)
}

func drawIcon(size: Int) -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let s = CGFloat(size)
    context.interpolationQuality = .high
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.translateBy(x: 0, y: s)
    context.scaleBy(x: 1, y: -1)

    let background = CGGradient(
        colorsSpace: colorSpace,
        colors: [Palette.backdropTop, Palette.backdropBottom] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(background, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

    context.saveGState()
    context.setFillColor(CGColor(red: 0.22, green: 0.19, blue: 0.48, alpha: 0.30))
    context.fillEllipse(in: CGRect(x: -0.15 * s, y: -0.18 * s, width: 0.78 * s, height: 0.58 * s))
    context.setFillColor(CGColor(red: 0.06, green: 0.42, blue: 0.72, alpha: 0.16))
    context.fillEllipse(in: CGRect(x: 0.50 * s, y: 0.48 * s, width: 0.60 * s, height: 0.48 * s))
    context.restoreGState()

    drawBeaker(in: context, rect: CGRect(x: 0.20 * s, y: 0.25 * s, width: 0.25 * s, height: 0.50 * s), colors: [Palette.orange, Palette.cyan])
    drawBeaker(in: context, rect: CGRect(x: 0.55 * s, y: 0.25 * s, width: 0.25 * s, height: 0.50 * s), colors: [Palette.green, Palette.yellow])
    drawDrop(in: context, rect: CGRect(x: 0.415 * s, y: 0.52 * s, width: 0.17 * s, height: 0.23 * s))

    return context.makeImage()!
}

func drawBeaker(in context: CGContext, rect: CGRect, colors: [CGColor]) {
    let path = beakerPath(rect)
    let interior = rect.insetBy(dx: rect.width * 0.17, dy: rect.width * 0.12)
    let liquidHeight = interior.height * 0.72
    let unitHeight = liquidHeight / CGFloat(colors.count)

    context.saveGState()
    context.addPath(path)
    context.clip()
    for (index, color) in colors.enumerated() {
        context.setFillColor(color)
        context.fill(CGRect(
            x: interior.minX,
            y: interior.maxY - liquidHeight + CGFloat(index) * unitHeight,
            width: interior.width,
            height: unitHeight + 1
        ))
    }
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.11))
    context.fill(CGRect(x: interior.minX, y: interior.maxY - liquidHeight, width: interior.width * 0.38, height: liquidHeight))
    context.restoreGState()

    context.saveGState()
    context.addPath(path)
    context.setStrokeColor(Palette.glassDark)
    context.setLineWidth(rect.width * 0.12)
    context.strokePath()
    context.addPath(path)
    context.setStrokeColor(Palette.glass)
    context.setLineWidth(rect.width * 0.07)
    context.strokePath()
    context.setStrokeColor(Palette.rim)
    context.setLineWidth(rect.width * 0.08)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.08))
    context.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.08))
    context.strokePath()
    context.restoreGState()
}

func beakerPath(_ rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    let topY = rect.minY + rect.height * 0.08
    let bottomCurveY = rect.maxY - rect.height * 0.20
    let bottomY = rect.maxY - rect.height * 0.04
    path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: topY))
    path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: topY))
    path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: bottomCurveY))
    path.addQuadCurve(to: CGPoint(x: rect.midX, y: bottomY), control: CGPoint(x: rect.maxX - rect.width * 0.14, y: bottomY))
    path.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.12, y: bottomCurveY), control: CGPoint(x: rect.minX + rect.width * 0.14, y: bottomY))
    path.closeSubpath()
    return path
}

func drawDrop(in context: CGContext, rect: CGRect) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control1: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.28), control2: CGPoint(x: rect.maxX, y: rect.midY - rect.height * 0.08))
    path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control1: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.20), control2: CGPoint(x: rect.midX + rect.width * 0.22, y: rect.maxY))
    path.addCurve(to: CGPoint(x: rect.minX, y: rect.midY), control1: CGPoint(x: rect.midX - rect.width * 0.22, y: rect.maxY), control2: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.20))
    path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY), control1: CGPoint(x: rect.minX, y: rect.midY - rect.height * 0.08), control2: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.minY + rect.height * 0.16))

    context.saveGState()
    context.addPath(path)
    context.setFillColor(CGColor(red: 0.17, green: 0.77, blue: 1.00, alpha: 1))
    context.fillPath()
    context.addPath(path)
    context.setStrokeColor(CGColor(red: 0.86, green: 0.95, blue: 1.00, alpha: 0.76))
    context.setLineWidth(rect.width * 0.10)
    context.strokePath()
    context.restoreGState()
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create image destination for \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write \(url.path)")
    }
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for spec in specs {
    writePNG(drawIcon(size: spec.pixels), to: outputDirectory.appendingPathComponent(spec.filename))
}
