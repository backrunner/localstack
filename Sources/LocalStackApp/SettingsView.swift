import SwiftUI
import LocalStackCore

struct SettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                section("软件更新", icon: "arrow.triangle.2.circlepath", detail: model.updater.currentVersion) {
                    updateSettings
                }
                section("启动", icon: "power") {
                    startupSettings
                }
                section("快捷键", icon: "keyboard") {
                    VStack(spacing: 0) {
                        shortcut("搜索服务", keys: ["⌘", "F"])
                        shortcut("刷新列表", keys: ["⌘", "R"])
                        shortcut("打开选中服务或首个结果", keys: ["↩"])
                        shortcut("停止选中服务", keys: ["⌫"])
                    }
                    .padding(.vertical, 5)
                }
            }
            .padding(.horizontal, LSPanelLayout.horizontalInset)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .font(.system(size: 12))
        .tint(.lsAccent)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var updateSettings: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("更新通道").font(.system(size: 12, weight: .medium))
                    Spacer(minLength: 12)
                    channelPicker
                }
                Text(model.updater.channel == .stable ? "只接收正式版，切换通道不会降级。" : "提前体验新功能，也接收后续正式版。")
                    .font(.lsCaption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            insetDivider

            HStack {
                rowLabel("自动下载更新", detail: "每天检查，由你决定何时重启安装")
                Spacer(minLength: 12)
                Toggle("自动下载更新", isOn: Binding(get: { model.updater.automaticallyDownloads }, set: { model.updater.setAutomaticallyDownloads($0) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            insetDivider

            HStack(spacing: 10) {
                Image(systemName: updateSymbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(updateColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(updateStatus)
                        .font(.lsCaption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = model.updater.releaseURL {
                        Link("查看更新说明", destination: url).font(.lsCaption)
                    }
                }
                Spacer(minLength: 0)
                updateAction
                    .fixedSize()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder private var channelPicker: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 6) { channelButtons }
        } else {
            channelButtons
        }
    }

    private var channelButtons: some View {
        HStack(spacing: 6) {
            channelButton("正式版", channel: .stable)
            channelButton("Beta", channel: .beta)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("更新通道")
        .disabled(model.updater.state == .installing)
    }

    private func channelButton(_ title: String, channel: AppUpdateChannel) -> some View {
        let selected = model.updater.channel == channel
        return Button { model.updater.setChannel(channel) } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? (scheme == .dark ? Color(white: 0.12) : .white) : (scheme == .dark ? Color(white: 0.94) : Color(white: 0.18)))
                .frame(minWidth: 42)
                .padding(.vertical, 2)
        }
        .buttonBorderShape(.capsule)
        .lsGlassAction(prominent: selected)
        .accessibilityLabel("\(title)通道")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var updateAction: some View {
        switch model.updater.state {
        case .available:
            Button("下载更新") { model.updater.download() }
                .lsGlassAction(prominent: true)
        case .ready:
            Button("重启并更新") { Task { await model.updater.install() } }
                .lsGlassAction(prominent: true)
        case .checking, .downloading, .installing:
            ProgressView().controlSize(.small).padding(.horizontal, 8)
        default:
            Button("检查更新") { model.updater.check() }
                .lsGlassAction()
                .disabled(!model.updater.canCheck)
        }
    }

    private var startupSettings: some View {
        VStack(spacing: 0) {
            HStack {
                rowLabel("登录时启动", detail: model.loginRequiresApproval ? "需要在系统设置中批准" : "登录 Mac 后自动运行 LocalStack")
                Spacer(minLength: 12)
                Toggle("登录时启动", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            insetDivider

            Button { model.openLoginSettings() } label: {
                HStack {
                    Text("系统登录项设置")
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                }
                .font(.lsCaption).foregroundStyle(Color.lsAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func section<Content: View>(_ title: String, icon: String, detail: String? = nil,
                                       @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.lsAccent)
                    .frame(width: 14)
                    .accessibilityHidden(true)
                Text(title).font(.system(size: 12, weight: .semibold))
                Spacer()
                if let detail {
                    Text(detail).font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
            content().modifier(SettingsCard())
        }
    }

    private func rowLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 12, weight: .medium))
            Text(detail).font(.lsCaption).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var insetDivider: some View {
        Divider().opacity(0.5).padding(.horizontal, 14)
    }

    private func shortcut(_ title: String, keys: [String]) -> some View {
        HStack {
            Text(title).font(.lsCaption).foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    Text(key).font(.system(size: 10, weight: .medium, design: .monospaced))
                        .frame(minWidth: 19, minHeight: 18)
                        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.primary.opacity(0.06), lineWidth: 0.5))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(keys.joined())
        }
        .frame(height: 24)
        .padding(.horizontal, 14)
    }

    private var updateStatus: String {
        switch model.updater.state {
        case .idle: model.updater.canCheck ? "每天自动检查更新" : "安装到应用程序后可检查更新"
        case .checking: "正在检查更新…"
        case .current: "当前已是最新版本"
        case .available(let version): "发现 \(version)"
        case .downloading: "正在下载并验证…"
        case .ready(let version): "\(version) 已准备好"
        case .installing: "正在安装更新…"
        case .failed(let reason): reason
        }
    }

    private var updateSymbol: String {
        switch model.updater.state {
        case .current: "checkmark.circle"
        case .available, .ready: "arrow.down.circle"
        case .failed: "exclamationmark.circle"
        default: "arrow.triangle.2.circlepath"
        }
    }

    private var updateColor: Color {
        switch model.updater.state {
        case .current, .available, .ready: .lsAccent
        case .failed: .orange
        default: .secondary
        }
    }
}

/// Content groups keep a visible edge even on a plain desktop or with reduced
/// transparency. Liquid Glass is reserved for the interactive controls above.
private struct SettingsCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(reduceTransparency ? Color(nsColor: .controlBackgroundColor) : Color.white.opacity(scheme == .dark ? 0.055 : 0.88), in: shape)
            .overlay(shape.strokeBorder(.primary.opacity(scheme == .dark ? 0.09 : 0.055), lineWidth: 0.5))
            .shadow(color: .black.opacity(scheme == .dark ? 0.08 : 0.025), radius: 4, y: 2)
    }
}
