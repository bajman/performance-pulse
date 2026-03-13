import AppKit
import Foundation

let fileManager = FileManager.default
let repositoryRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let assetsDirectory = repositoryRoot.appendingPathComponent("assets", isDirectory: true)
let masterIconURL = assetsDirectory.appendingPathComponent("app-icon-master.png")
let iconsetURL = assetsDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = assetsDirectory.appendingPathComponent("AppIcon.icns")

try fileManager.createDirectory(at: assetsDirectory, withIntermediateDirectories: true, attributes: nil)
if fileManager.fileExists(atPath: iconsetURL.path) {
    try fileManager.removeItem(at: iconsetURL)
}
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true, attributes: nil)

let iconSizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, fileName) in iconSizes {
    let image = AppIconRenderer.render(size: CGFloat(size))
    try image.pngData()?.write(to: iconsetURL.appendingPathComponent(fileName))
}

let masterImage = AppIconRenderer.render(size: 1024)
try masterImage.pngData()?.write(to: masterIconURL)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    throw NSError(domain: "AppIconGenerator", code: Int(iconutil.terminationStatus))
}

try fileManager.removeItem(at: iconsetURL)

print("Generated \(icnsURL.path)")

enum AppIconRenderer {
    static func render(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        context.interpolationQuality = .high
        let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        drawBackground(in: rect, context: context)
        drawPanel(in: rect, context: context)
        drawPulse(in: rect, context: context)
        drawHighlights(in: rect, context: context)

        image.unlockFocus()
        return image
    }

    private static func drawBackground(in rect: CGRect, context: CGContext) {
        let cornerRadius = rect.width * 0.23
        let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        backgroundPath.addClip()

        let baseGradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.13, alpha: 1),
            NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.18, alpha: 1),
            NSColor(calibratedRed: 0.03, green: 0.05, blue: 0.10, alpha: 1),
        ])!
        baseGradient.draw(in: backgroundPath, angle: -35)

        drawGlow(
            color: NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.18, alpha: 0.42),
            center: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.18),
            radius: rect.width * 0.55,
            context: context)

        drawGlow(
            color: NSColor(calibratedRed: 0.08, green: 0.87, blue: 0.93, alpha: 0.34),
            center: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.maxY - rect.height * 0.18),
            radius: rect.width * 0.48,
            context: context)

        context.saveGState()
        context.setBlendMode(.screen)
        let grainColor = NSColor.white.withAlphaComponent(0.035).cgColor
        context.setFillColor(grainColor)
        let step = rect.width / 14
        for row in stride(from: rect.minY, through: rect.maxY, by: step) {
            for column in stride(from: rect.minX, through: rect.maxX, by: step) {
                let noiseRect = CGRect(x: column, y: row, width: 1.2, height: 1.2)
                context.fillEllipse(in: noiseRect)
            }
        }
        context.restoreGState()
    }

    private static func drawPanel(in rect: CGRect, context: CGContext) {
        let inset = rect.width * 0.11
        let panelRect = rect.insetBy(dx: inset, dy: inset)
        let cornerRadius = rect.width * 0.18
        let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: cornerRadius, yRadius: cornerRadius)

        context.saveGState()
        context.setShadow(offset: .zero, blur: rect.width * 0.08, color: NSColor.black.withAlphaComponent(0.28).cgColor)
        NSColor.white.withAlphaComponent(0.075).setFill()
        panelPath.fill()
        context.restoreGState()

        NSColor.white.withAlphaComponent(0.14).setStroke()
        panelPath.lineWidth = rect.width * 0.012
        panelPath.stroke()

        let sheenRect = CGRect(
            x: panelRect.minX,
            y: panelRect.midY,
            width: panelRect.width,
            height: panelRect.height * 0.55)
        let sheenPath = NSBezierPath(roundedRect: sheenRect, xRadius: cornerRadius * 0.85, yRadius: cornerRadius * 0.85)
        sheenPath.addClip()
        let sheenGradient = NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.16),
            NSColor.white.withAlphaComponent(0.03),
            .clear,
        ])!
        sheenGradient.draw(in: sheenPath, angle: 90)
    }

    private static func drawPulse(in rect: CGRect, context: CGContext) {
        let linePath = NSBezierPath()
        let left = rect.width * 0.23
        let right = rect.width * 0.77
        let width = right - left
        let baseline = rect.height * 0.50

        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: left + width * x, y: baseline + rect.height * y)
        }

        linePath.move(to: point(0.00, -0.02))
        linePath.curve(to: point(0.18, -0.02), controlPoint1: point(0.05, -0.02), controlPoint2: point(0.13, -0.02))
        linePath.curve(to: point(0.31, 0.04), controlPoint1: point(0.22, -0.02), controlPoint2: point(0.27, 0.02))
        linePath.curve(to: point(0.41, -0.15), controlPoint1: point(0.35, 0.10), controlPoint2: point(0.38, -0.10))
        linePath.curve(to: point(0.48, 0.24), controlPoint1: point(0.43, -0.18), controlPoint2: point(0.46, 0.16))
        linePath.curve(to: point(0.58, -0.02), controlPoint1: point(0.50, 0.30), controlPoint2: point(0.54, 0.02))
        linePath.curve(to: point(0.70, -0.02), controlPoint1: point(0.61, -0.05), controlPoint2: point(0.66, -0.02))
        linePath.curve(to: point(1.00, -0.02), controlPoint1: point(0.79, -0.02), controlPoint2: point(0.91, -0.02))

        context.saveGState()
        context.setShadow(
            offset: .zero,
            blur: rect.width * 0.06,
            color: NSColor(calibratedRed: 0.10, green: 0.89, blue: 0.97, alpha: 0.65).cgColor)
        NSColor(calibratedRed: 0.11, green: 0.90, blue: 0.96, alpha: 0.94).setStroke()
        linePath.lineCapStyle = .round
        linePath.lineJoinStyle = .round
        linePath.lineWidth = rect.width * 0.072
        linePath.stroke()
        context.restoreGState()

        NSColor.white.withAlphaComponent(0.97).setStroke()
        linePath.lineWidth = rect.width * 0.026
        linePath.stroke()

        let orbRect = CGRect(
            x: rect.width * 0.64,
            y: rect.height * 0.58,
            width: rect.width * 0.12,
            height: rect.width * 0.12)
        let orbPath = NSBezierPath(ovalIn: orbRect)
        context.saveGState()
        context.setShadow(
            offset: .zero,
            blur: rect.width * 0.05,
            color: NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.18, alpha: 0.9).cgColor)
        NSColor(calibratedRed: 1.0, green: 0.66, blue: 0.24, alpha: 1).setFill()
        orbPath.fill()
        context.restoreGState()
    }

    private static func drawHighlights(in rect: CGRect, context: CGContext) {
        let ringRect = CGRect(
            x: rect.width * 0.66,
            y: rect.height * 0.66,
            width: rect.width * 0.16,
            height: rect.width * 0.16)
        let ringPath = NSBezierPath(ovalIn: ringRect)
        NSColor.white.withAlphaComponent(0.22).setStroke()
        ringPath.lineWidth = rect.width * 0.016
        ringPath.stroke()

        let sparkRect = CGRect(
            x: rect.width * 0.71,
            y: rect.height * 0.71,
            width: rect.width * 0.06,
            height: rect.width * 0.06)
        NSColor.white.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: sparkRect).fill()

        let bottomAccent = NSBezierPath(roundedRect: CGRect(
            x: rect.width * 0.20,
            y: rect.height * 0.19,
            width: rect.width * 0.60,
            height: rect.height * 0.045),
            xRadius: rect.width * 0.03,
            yRadius: rect.width * 0.03)
        NSColor.white.withAlphaComponent(0.08).setFill()
        bottomAccent.fill()
    }

    private static func drawGlow(color: NSColor, center: CGPoint, radius: CGFloat, context: CGContext) {
        let glowColorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [color.withAlphaComponent(1).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: glowColorSpace, colors: colors, locations: [0, 1]) else {
            return
        }

        context.saveGState()
        context.setBlendMode(.screen)
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: [.drawsAfterEndLocation])
        context.restoreGState()
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmap.representation(using: .png, properties: [.compressionFactor: 1])
    }
}
