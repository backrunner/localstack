import SwiftUI

enum LSPanelLayout {
    static let width: CGFloat = 432
    static let height: CGFloat = 600
    static let horizontalInset: CGFloat = 20
    static let cardRadius: CGFloat = 18
    static let serviceRowHeight: CGFloat = 44
    static let serviceRowSpacing: CGFloat = 6
    static let visibleServiceCount = 8
    static let serviceViewportHeight = serviceRowHeight * CGFloat(visibleServiceCount)
        + serviceRowSpacing * CGFloat(visibleServiceCount - 1)
}

extension Font {
    static let lsCaption = Font.system(size: 11)
    static let lsMono = Font.system(size: 11, design: .monospaced)
}

extension Color {
    static let lsHealth = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.38, green: 0.88, blue: 0.72, alpha: 1)
            : NSColor(red: 0.04, green: 0.43, blue: 0.32, alpha: 1)
    })
    static let lsHealthPending = Color.orange
    static let lsAccent = Color.lsHealth
    static let lsDestructive = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 1, green: 0.43, blue: 0.43, alpha: 1)
            : NSColor(red: 0.78, green: 0.16, blue: 0.20, alpha: 1)
    })
    static let lsSurface = Color(nsColor: .controlBackgroundColor)
}

/// Three connected layers: the same silhouette is used by the app icon and menu bar.
struct StackMark: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        return Path { path in
            path.move(to: p(0.12, 0.30))
            path.addLine(to: p(0.5, 0.10))
            path.addLine(to: p(0.88, 0.30))
            path.addLine(to: p(0.5, 0.50))
            path.closeSubpath()
            for y: CGFloat in [0.50, 0.70] {
                path.move(to: p(0.12, y))
                path.addLine(to: p(0.50, y + 0.20))
                path.addLine(to: p(0.88, y))
            }
        }
    }
}

struct BrandIcon: View {
    var size: CGFloat = 32
    var body: some View {
        StackMark()
            .stroke(Color(red: 0.55, green: 0.98, blue: 0.81), style: StrokeStyle(lineWidth: size * 0.055, lineCap: .round, lineJoin: .round))
            .padding(size * 0.18)
            .frame(width: size, height: size)
            .background(Color(red: 0.055, green: 0.13, blue: 0.14), in: RoundedRectangle(cornerRadius: size * 0.24))
            .accessibilityHidden(true)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .frame(width: 32, height: 32)
            .background(.primary.opacity(configuration.isPressed ? 0.11 : 0.045), in: Circle())
            .contentShape(Circle())
    }
}
