import AppKit

func generateAppIcon() {
    let size = NSSize(width: 1024, height: 1024)
    let image = NSImage(size: size)
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        exit(1)
    }

    // Outer Squircle / Rounded Rect background
    let bgRect = NSRect(x: 64, y: 64, width: 896, height: 896)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 200, yRadius: 200)

    // Gradient fill: Deep Navy to Electric Dark Blue
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let startColor = CGColor(red: 10/255, green: 18/255, blue: 36/255, alpha: 1.0)
    let endColor = CGColor(red: 20/255, green: 35/255, blue: 70/255, alpha: 1.0)
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: [startColor, endColor] as CFArray, locations: [0.0, 1.0]) {
        ctx.saveGState()
        bgPath.addClip()
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 960), end: CGPoint(x: 512, y: 64), options: [])
        ctx.restoreGState()
    }

    // Subtle Inner Glow / Border
    ctx.saveGState()
    bgPath.lineWidth = 8
    NSColor(red: 14/255, green: 122/255, blue: 254/255, alpha: 0.4).setStroke()
    bgPath.stroke()
    ctx.restoreGState()

    // Android Phone Body (Left side)
    let phoneRect = NSRect(x: 200, y: 240, width: 280, height: 540)
    let phonePath = NSBezierPath(roundedRect: phoneRect, xRadius: 44, yRadius: 44)
    NSColor(red: 15/255, green: 22/255, blue: 40/255, alpha: 1.0).setFill()
    phonePath.fill()
    phonePath.lineWidth = 10
    NSColor(red: 14/255, green: 122/255, blue: 254/255, alpha: 0.9).setStroke()
    phonePath.stroke()

    // Phone Screen Glass
    let screenRect = NSRect(x: 216, y: 280, width: 248, height: 450)
    let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 24, yRadius: 24)
    let screenStart = CGColor(red: 14/255, green: 122/255, blue: 254/255, alpha: 0.85)
    let screenEnd = CGColor(red: 0/255, green: 200/255, blue: 255/255, alpha: 0.85)
    if let screenGrad = CGGradient(colorsSpace: colorSpace, colors: [screenStart, screenEnd] as CFArray, locations: [0.0, 1.0]) {
        ctx.saveGState()
        screenPath.addClip()
        ctx.drawLinearGradient(screenGrad, start: CGPoint(x: 340, y: 730), end: CGPoint(x: 340, y: 280), options: [])
        ctx.restoreGState()
    }

    // Mac Display / Mirror Monitor Frame (Right side, overlapping)
    let macRect = NSRect(x: 440, y: 340, width: 380, height: 280)
    let macPath = NSBezierPath(roundedRect: macRect, xRadius: 24, yRadius: 24)
    NSColor(red: 24/255, green: 32/255, blue: 50/255, alpha: 0.95).setFill()
    macPath.fill()
    macPath.lineWidth = 10
    NSColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.8).setStroke()
    macPath.stroke()

    // Mac Screen with Mirror Reflection
    let macScreenRect = NSRect(x: 456, y: 370, width: 348, height: 234)
    let macScreenPath = NSBezierPath(roundedRect: macScreenRect, xRadius: 14, yRadius: 14)
    if let macGrad = CGGradient(colorsSpace: colorSpace, colors: [screenStart, screenEnd] as CFArray, locations: [0.0, 1.0]) {
        ctx.saveGState()
        macScreenPath.addClip()
        ctx.drawLinearGradient(macGrad, start: CGPoint(x: 630, y: 604), end: CGPoint(x: 630, y: 370), options: [])
        ctx.restoreGState()
    }

    // Mac Monitor Stand
    let standPath = NSBezierPath()
    standPath.move(to: NSPoint(x: 600, y: 340))
    standPath.line(to: NSPoint(x: 660, y: 340))
    standPath.line(to: NSPoint(x: 670, y: 270))
    standPath.line(to: NSPoint(x: 590, y: 270))
    standPath.close()
    NSColor(red: 180/255, green: 190/255, blue: 210/255, alpha: 0.85).setFill()
    standPath.fill()

    let baseRect = NSRect(x: 550, y: 256, width: 160, height: 16)
    let basePath = NSBezierPath(roundedRect: baseRect, xRadius: 8, yRadius: 8)
    basePath.fill()

    // Sync Waves / Electric Bolt Arrow between phone and mac
    let arrowPath = NSBezierPath()
    arrowPath.move(to: NSPoint(x: 370, y: 510))
    arrowPath.line(to: NSPoint(x: 430, y: 550))
    arrowPath.line(to: NSPoint(x: 410, y: 510))
    arrowPath.line(to: NSPoint(x: 460, y: 510))
    arrowPath.lineWidth = 14
    arrowPath.lineCapStyle = .round
    NSColor.white.setStroke()
    arrowPath.stroke()

    image.unlockFocus()

    guard let tiffData = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiffData),
          let pngData = rep.representation(using: .png, properties: [:]) else {
        exit(1)
    }

    let outURL = URL(fileURLWithPath: "Resources/app_icon_1024.png")
    try! pngData.write(to: outURL)
    print("Created 1024x1024 icon at \(outURL.path)")
}

generateAppIcon()
