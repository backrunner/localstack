import AppKit

// All brand assets are reproducible vector drawings, rendered at native icon/Retina sizes.
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/Brand", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
func render(name: String, width: Int, height: Int, scale: Int = 1, drawing: (CGFloat) -> Void) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * scale, pixelsHigh: height * scale, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawing(CGFloat(height))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
func mark(in rect: CGRect, stroke: NSColor, lineWidth: CGFloat) {
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: rect.minX + x * rect.width, y: rect.maxY - y * rect.height) }
    let path = NSBezierPath()
    path.move(to: p(0.12, 0.30)); path.line(to: p(0.50, 0.10)); path.line(to: p(0.88, 0.30)); path.line(to: p(0.50, 0.50)); path.close()
    for y: CGFloat in [0.50, 0.70] {
        path.move(to: p(0.12, y)); path.line(to: p(0.50, y + 0.20)); path.line(to: p(0.88, y))
    }
    stroke.setStroke(); path.lineWidth = lineWidth; path.lineCapStyle = .round; path.lineJoinStyle = .round; path.stroke()
}
try render(name: "AppIcon-1024.png", width: 1024, height: 1024) { _ in
    let tile = NSBezierPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowOffset = NSSize(width: 0, height: -12); shadow.shadowBlurRadius = 28; shadow.shadowColor = color(0x091D20, 0.25); shadow.set()
    color(0x102C30).setFill(); tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [color(0x23484A), color(0x0B2026)])!.draw(in: tile, angle: -75)
    color(0xFFFFFF, 0.18).setStroke(); tile.lineWidth = 3; tile.stroke()
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    let glow = NSBezierPath(ovalIn: CGRect(x: 480, y: 600, width: 600, height: 600))
    NSGradient(starting: color(0x8FFBD2, 0.10), ending: color(0x8FFBD2, 0))!.draw(in: glow, relativeCenterPosition: .zero)
    NSGraphicsContext.restoreGraphicsState()
    mark(in: CGRect(x: 252, y: 232, width: 520, height: 560), stroke: color(0x91F4CC), lineWidth: 43)
}
try render(name: "TrayTemplate.png", width: 20, height: 20, scale: 2) { _ in
    mark(in: CGRect(x: 1, y: 1, width: 18, height: 18), stroke: .black, lineWidth: 1.6)
}
try render(name: "DMGBackground.png", width: 720, height: 480, scale: 2) { height in
    func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, radius: CGFloat, fill: NSColor) {
        fill.setFill(); NSBezierPath(roundedRect: CGRect(x: x, y: height-y-h, width: w, height: h), xRadius: radius, yRadius: radius).fill()
    }
    func text(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat, weight: NSFont.Weight, ink: NSColor, align: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = align
        (value as NSString).draw(in: CGRect(x: x, y: height-y-size*1.6, width: width, height: size*1.6), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: ink, .paragraphStyle: paragraph])
    }
    color(0xF3F5F3).setFill()
    NSBezierPath(rect: CGRect(x: 0, y: 0, width: 720, height: 480)).fill()
    box(42, 38, 48, 48, radius: 13, fill: color(0x142F32))
    mark(in: CGRect(x: 51, y: height-77, width: 30, height: 30), stroke: color(0x91F4CC), lineWidth: 2)
    text("LocalStack", x: 104, y: 36, width: 380, size: 27, weight: .bold, ink: color(0x153A36))
    text("本地开发服务管理", x: 105, y: 72, width: 420, size: 12, weight: .regular, ink: color(0x648077))
    text("安装 LocalStack", x: 42, y: 121, width: 640, size: 25, weight: .semibold, ink: color(0x153A36))
    text("双击下方应用，或拖入 Applications。", x: 43, y: 162, width: 620, size: 13, weight: .regular, ink: color(0x648077))
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 332, y: height-267)); arrow.line(to: NSPoint(x: 388, y: height-267))
    arrow.move(to: NSPoint(x: 380, y: height-260)); arrow.line(to: NSPoint(x: 388, y: height-267)); arrow.line(to: NSPoint(x: 380, y: height-274))
    color(0x75978A).setStroke(); arrow.lineWidth = 2; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round; arrow.stroke()
    text("双击 LocalStack 自动安装并打开", x: 40, y: 375, width: 640, size: 14, weight: .medium, ink: color(0x234B40), align: .center)
    text("macOS 15+", x: 570, y: 449, width: 108, size: 10, weight: .medium, ink: color(0x78968A), align: .right)
}
print("Generated AppIcon, TrayTemplate and Retina DMG background in \(output.path)")
