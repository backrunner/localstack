import SwiftUI

/// 面板顶部/底部控制条：胶囊形，距面板边缘留白；macOS 26 使用原生 Liquid Glass，macOS 15 回退到 .bar 材质胶囊。
struct GlassBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content.background(.bar, in: Capsule())
        }
    }
}

/// 小型状态/计数胶囊：macOS 26 使用胶囊形 Liquid Glass，macOS 15 回退到浅色填充胶囊。
struct GlassPill: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content.background(.quaternary, in: Capsule())
        }
    }
}

/// 按钮：macOS 26 使用 .glass 按钮样式；macOS 15 回退到无边框或 bordered 样式。
struct LSGlassButton: ViewModifier {
    /// macOS 15 回退样式：图标按钮用 borderless，空态 CTA 用 bordered。
    var fallbackBorderless = true

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glass)
        } else if fallbackBorderless {
            content.buttonStyle(.borderless)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

/// A quiet, borderless glass surface used for content groups and list rows.
struct LiquidSurface: ViewModifier {
    var radius: CGFloat = 18
    var tint: Color = .clear

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background(tint, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .background(tint, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}

extension View {
    func glassBar() -> some View { modifier(GlassBar()) }
    func glassPill() -> some View { modifier(GlassPill()) }
    func lsGlassButton(fallbackBorderless: Bool = true) -> some View {
        modifier(LSGlassButton(fallbackBorderless: fallbackBorderless))
    }
    func liquidSurface(radius: CGFloat = 18, tint: Color = .clear) -> some View {
        modifier(LiquidSurface(radius: radius, tint: tint))
    }
}
