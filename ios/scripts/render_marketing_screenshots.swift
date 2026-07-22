#!/usr/bin/env swift
import AppKit
import Foundation

struct StoryFrame {
    let source: String
    let output: String
    let eyebrow: String
    let headline: String
}

struct DevicePlan {
    let sourceFolder: String
    let outputFolder: String
}

let story: [StoryFrame] = [
    .init(source: "01-search", output: "01-search", eyebrow: "BULK CONTENT SEARCH", headline: "Search and manage content in bulk"),
    .init(source: "02-filters", output: "02-delete", eyebrow: "PRECISION FILTERS", headline: "Filter by keyword, date, or engagement"),
    .init(source: "03-media-results", output: "03-results", eyebrow: "YOUR COMPLETE ARCHIVE", headline: "Review posts, replies, likes, and media"),
    .init(source: "04-followers", output: "04-followers", eyebrow: "FOLLOW HYGIENE", headline: "Review the accounts you follow"),
    .init(source: "06-scope", output: "05-stats", eyebrow: "PRIVATE ACCOUNT STATS", headline: "Explore graphs, activity, and stats"),
]

let devices = [
    DevicePlan(sourceFolder: "iphone-6.9", outputFolder: "iphone-6.9"),
    DevicePlan(sourceFolder: "ipad-13", outputFolder: "ipad-13"),
]

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let iosDir = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let sourceRoot = iosDir.appendingPathComponent("screenshots-appstore")
let outputRoot = iosDir.appendingPathComponent("screenshots-marketing")

for device in devices {
    let sourceDir = sourceRoot.appendingPathComponent(device.sourceFolder)
    let outputDir = outputRoot.appendingPathComponent(device.outputFolder)
    try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    for file in (try? FileManager.default.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)) ?? [] where file.pathExtension == "png" {
        try FileManager.default.removeItem(at: file)
    }

    for frame in story {
        let output = outputDir.appendingPathComponent(frame.output + ".png")
        let source = sourceDir.appendingPathComponent(frame.source + ".png")
        try render(source: source, frame: frame, output: output)
        print("rendered \(device.outputFolder)/\(output.lastPathComponent)")
    }
}

private func render(source: URL, frame: StoryFrame, output: URL) throws {
    guard let sourceRep = NSBitmapImageRep(data: try Data(contentsOf: source)), let sourceCG = sourceRep.cgImage else {
        throw RenderError("Could not read \(source.path)")
    }

    let width = output.path.contains("ipad") ? 2064 : 1320
    let height = output.path.contains("ipad") ? 2752 : 2868
    let shortSide = CGFloat(min(width, height))
    let canvas = CGRect(x: 0, y: 0, width: width, height: height)
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
    guard let cg = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo
    ) else { throw RenderError("Could not create canvas") }

    let context = NSGraphicsContext(cgContext: cg, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.012, green: 0.027, blue: 0.067, alpha: 1),
        NSColor(calibratedRed: 0.035, green: 0.075, blue: 0.165, alpha: 1),
        NSColor(calibratedRed: 0.008, green: 0.016, blue: 0.040, alpha: 1),
    ])!
    gradient.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -76)

    drawGlow(in: canvas, shortSide: shortSide)

    let margin = shortSide * 0.072
    let top = CGFloat(height) - margin
    let eyebrowSize = min(max(shortSide * 0.020, 22), 36)
    let eyebrowAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: eyebrowSize, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.56, green: 0.83, blue: 1.0, alpha: 1),
        .kern: eyebrowSize * 0.13,
    ]
    frame.eyebrow.draw(at: NSPoint(x: margin, y: top - eyebrowSize), withAttributes: eyebrowAttrs)

    let headlineSize = min(max(shortSide * 0.058, 64), 112)
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.alignment = .left
    paragraph.lineSpacing = headlineSize * 0.02
    let headlineAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: headlineSize, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
        .kern: -headlineSize * 0.025,
    ]
    let headlineY = top - eyebrowSize - headlineSize * 2.45
    frame.headline.draw(
        in: NSRect(x: margin, y: headlineY, width: CGFloat(width) - margin * 2, height: headlineSize * 2.35),
        withAttributes: headlineAttrs
    )

    let cardTop = headlineY - shortSide * 0.070
    let cardBottom = -shortSide * 0.055
    let cardBounds = CGRect(
        x: margin,
        y: cardBottom,
        width: CGFloat(width) - margin * 2,
        height: cardTop - cardBottom
    )
    let radius = shortSide * 0.040
    let cardPath = NSBezierPath(roundedRect: cardBounds, xRadius: radius, yRadius: radius)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.58)
    shadow.shadowOffset = NSSize(width: 0, height: -shortSide * 0.018)
    shadow.shadowBlurRadius = shortSide * 0.055
    shadow.set()
    NSColor.black.setFill()
    cardPath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.current?.saveGraphicsState()
    cardPath.addClip()
    let imageRect = aspectFillRect(source: CGSize(width: sourceCG.width, height: sourceCG.height), inside: cardBounds)
    cg.interpolationQuality = .high
    cg.draw(sourceCG, in: imageRect)
    NSGraphicsContext.current?.restoreGraphicsState()

    NSColor(calibratedWhite: 1, alpha: 0.17).setStroke()
    cardPath.lineWidth = max(2, shortSide * 0.0022)
    cardPath.stroke()

    NSGraphicsContext.restoreGraphicsState()
    guard let image = cg.makeImage() else { throw RenderError("Could not finalize canvas") }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw RenderError("Could not encode PNG")
    }
    try png.write(to: output)
}

private func drawGlow(in canvas: CGRect, shortSide: CGFloat) {
    let glow = NSBezierPath(ovalIn: NSRect(
        x: canvas.maxX - shortSide * 0.62,
        y: canvas.maxY - shortSide * 0.68,
        width: shortSide * 0.78,
        height: shortSide * 0.78
    ))
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedRed: 0.23, green: 0.51, blue: 0.96, alpha: 0.34)
    shadow.shadowBlurRadius = shortSide * 0.22
    shadow.shadowOffset = .zero
    NSGraphicsContext.current?.saveGraphicsState()
    shadow.set()
    NSColor(calibratedRed: 0.23, green: 0.51, blue: 0.96, alpha: 0.13).setFill()
    glow.fill()
    NSGraphicsContext.current?.restoreGraphicsState()
}

private func aspectFillRect(source: CGSize, inside target: CGRect) -> CGRect {
    let scale = max(target.width / source.width, target.height / source.height)
    let size = CGSize(width: source.width * scale, height: source.height * scale)
    return CGRect(x: target.midX - size.width / 2, y: target.midY - size.height / 2,
                  width: size.width, height: size.height)
}

private struct RenderError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
