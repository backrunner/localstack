import SwiftUI
import AppKit
import LocalStackShared
import LocalStackCore

struct TrayPanel: View {
    @Bindable var model: AppModel
    @State private var searchText = ""
    @State private var selection: ServiceRecord.ID?
    @State private var pendingPreview: TerminationPreview?
    @State private var showConfirmation = false
    @State private var pendingForcePreview: TerminationPreview?
    @State private var showForceConfirmation = false
    @State private var detailService: ServiceRecord?
    @State private var showSettings = false
    @State private var copiedURL: String?
    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(model: AppModel, showSettings: Bool = false) {
        self.model = model
        _showSettings = State(initialValue: showSettings)
    }

    private var activeServices: [ServiceRecord] {
        model.services.filter { $0.health == .active }
    }

    private var filteredServices: [ServiceRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return activeServices.filter { service in
            (query.isEmpty || [service.displayName, service.url.absoluteString, service.projectRoot ?? "", service.sourceLabel]
                .contains { $0.localizedStandardContains(query) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if showSettings {
                SettingsView(model: model)
            } else {
                searchBar
                listHeader
                serviceContent
            }
            footer
        }
        .frame(width: LSPanelLayout.width, height: LSPanelLayout.height)
        .background(.ultraThinMaterial)
        .controlSize(.small)
        .task { await model.start() }
        .onAppear { model.refreshLaunchAtLoginStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshLaunchAtLoginStatus()
        }
        .task(id: copiedURL) {
            guard copiedURL != nil else { return }
            do { try await Task.sleep(for: .seconds(2)); copiedURL = nil } catch {}
        }
        .alert(item: $model.message) { message in
            Alert(title: Text("LocalStack"), message: Text(message.text), dismissButton: .default(Text("好")))
        }
        .sheet(item: $detailService) { service in ServiceDetailView(service: service) }
        .confirmationDialog("停止服务？", isPresented: $showConfirmation, titleVisibility: .visible) {
            if let pendingPreview {
                Button("停止服务", role: .destructive) { stop(pendingPreview) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let pendingPreview {
                Text("将停止 \(pendingPreview.displayName)（\(pendingPreview.url.absoluteString)，PID \(String(pendingPreview.pid))）。")
            }
        }
        .confirmationDialog("强制停止服务？", isPresented: $showForceConfirmation, titleVisibility: .visible) {
            if let pendingForcePreview {
                Button("强制停止", role: .destructive) { forceStop(pendingForcePreview) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let pendingForcePreview {
                Text("\(pendingForcePreview.displayName) 没有响应停止请求。强制停止会立即终止 PID \(String(pendingForcePreview.pid))。")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrandIcon(size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(showSettings ? "设置" : "LocalStack").font(.system(size: 19, weight: .semibold, design: .rounded))
                Text(showSettings ? "LocalStack" : "你的本地开发，一目了然")
                    .font(.lsCaption).foregroundStyle(.secondary)
            }
            Spacer()
            if !showSettings {
                Text(String(activeServices.count))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(width: 30, height: 30)
                    .liquidSurface(radius: 15, tint: Color.primary.opacity(0.035))
                    .accessibilityLabel("\(String(activeServices.count)) 个本地服务")
            }
            if showSettings {
                Button { showSettings = false } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(colorScheme == .dark ? Color(white: 0.94) : Color(white: 0.18))
                        .frame(width: 16, height: 20)
                }
                    .buttonBorderShape(.circle)
                    .lsGlassAction()
                    .accessibilityLabel("返回服务列表")
                    .help("返回服务列表")
            } else {
                Button(action: refresh) { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(IconButtonStyle())
                    .keyboardShortcut("r", modifiers: .command)
                    .accessibilityLabel("刷新服务列表")
                    .help("刷新（⌘R）")
                    .disabled(model.isRefreshing)
            }
        }
        .padding(.horizontal, LSPanelLayout.horizontalInset)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(searchFocused ? Color.lsAccent : .secondary)
            ZStack(alignment: .leading) {
                TextField("", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
                .focused($searchFocused)
                .accessibilityLabel("搜索本地服务")
                .onSubmit {
                    if let service = filteredServices.first { open(service) }
                }
                if searchText.isEmpty {
                    Text("搜索名称、端口或项目")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.52) : Color.secondary.opacity(0.72))
                        .allowsHitTesting(false)
                }
            }
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 42)
        .background(
            colorScheme == .dark ? Color.white.opacity(searchFocused ? 0.14 : 0.09) : Color.white.opacity(searchFocused ? 0.92 : 0.78),
            in: RoundedRectangle(cornerRadius: LSPanelLayout.cardRadius, style: .continuous)
        )
        .shadow(color: searchFocused ? Color.lsAccent.opacity(0.18) : .black.opacity(0.045), radius: searchFocused ? 9 : 4, y: 2)
        .padding(.horizontal, LSPanelLayout.horizontalInset)
        .padding(.bottom, 18)
        .background {
            Button("") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command).hidden()
        }
    }

    private var listHeader: some View {
        HStack {
            Text("服务列表").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, LSPanelLayout.horizontalInset)
        .padding(.bottom, 10)
    }

    @ViewBuilder private var serviceContent: some View {
        if !model.isConnected && activeServices.isEmpty {
            emptyState("正在连接…", detail: nil)
        } else if activeServices.isEmpty {
            emptyState("暂无本地服务", detail: "启动本地网页服务后会自动显示。")
        } else if filteredServices.isEmpty {
            VStack(spacing: 8) {
                Text("没有匹配的服务").font(.system(size: 12)).foregroundStyle(.secondary)
                Button("清除搜索") { searchText = "" }
                    .buttonStyle(.link).font(.system(size: 12))
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(filteredServices, selection: $selection) { service in
                ServiceRow(service: service, onOpen: open, onStop: prepareStop, onCopy: copyURL, onDetails: { detailService = $0 })
                    // Keep the gap outside the glass surface; macOS List can ignore vertical row insets.
                    .padding(.vertical, 6)
                    // AppKit's plain List contributes an 8pt content margin; compensate so
                    // the glass surface lands on the same 20pt grid as the section title.
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 34)
            .scrollContentBackground(.hidden)
            .padding(.top, 0)
            .onKeyPress(.return) {
                guard let service = selectedService else { return .ignored }
                open(service); return .handled
            }
            .onKeyPress(.delete) {
                guard let service = selectedService else { return .ignored }
                prepareStop(service); return .handled
            }
        }
    }

    private func emptyState(_ title: String, detail: String?) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 12, weight: .medium))
            if let detail { Text(detail).font(.lsCaption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 9) {
            Text(showSettings ? "设置自动保存" : copiedURL != nil ? "地址已复制" : statusText)
                .font(.lsCaption).foregroundStyle(.secondary)
            Spacer()
            if !showSettings {
                Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("设置").help("设置")
            }
            Menu {
                Button("关于 LocalStack") { NSApp.orderFrontStandardAboutPanel() }
                Divider()
                Button("退出 LocalStack") { NSApp.terminate(nil) }.keyboardShortcut("q")
            } label: { Image(systemName: "ellipsis") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden)
                .frame(width: 32).help("更多").accessibilityLabel("更多")
        }
        .padding(.horizontal, LSPanelLayout.horizontalInset)
        .frame(height: showSettings ? 40 : 52)
    }

    private var selectedService: ServiceRecord? { filteredServices.first { $0.id == selection } }
    private var statusText: String {
        if case .ready = model.updater.state { return "新版本已就绪，可在设置中安装" }
        if case .available = model.updater.state { return "有新版本，可在设置中更新" }
        if model.isRefreshing { return "正在刷新…" }
        guard model.isConnected, let updated = model.lastUpdated else { return "正在连接…" }
        return "更新于 \(updated.formatted(date: .omitted, time: .shortened))"
    }
    private func refresh() { Task { await model.refresh() } }
    private func open(_ service: ServiceRecord) { Task { await model.open(service) } }
    private func copyURL(_ service: ServiceRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(service.url.absoluteString, forType: .string)
        copiedURL = service.url.absoluteString
    }
    private func prepareStop(_ service: ServiceRecord) {
        Task {
            guard let preview = await model.prepareStop(service) else { return }
            pendingPreview = preview; showConfirmation = true
        }
    }
    private func stop(_ preview: TerminationPreview) {
        Task {
            guard let forcePreview = await model.stop(preview) else { return }
            pendingForcePreview = forcePreview; showForceConfirmation = true
        }
    }
    private func forceStop(_ preview: TerminationPreview) { Task { _ = await model.stop(preview, force: true) } }
}

private struct ServiceRow: View {
    let service: ServiceRecord
    let onOpen: (ServiceRecord) -> Void
    let onStop: (ServiceRecord) -> Void
    let onCopy: (ServiceRecord) -> Void
    let onDetails: (ServiceRecord) -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button { onOpen(service) } label: {
                HStack(spacing: 12) {
                    ServiceIcon(service: service)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(service.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack(spacing: 5) {
                            Text("localhost:\(String(service.port))")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.lsAccent)
                            Text("·").foregroundStyle(.tertiary)
                            Text(service.sourceLabel).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.65))
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.plain)
            .help("\(service.url.absoluteString)\n\(service.sourceLabel)")
            .accessibilityLabel("打开 \(service.displayName)，端口 \(String(service.port))")
            Menu {
                Button("打开页面", systemImage: "safari") { onOpen(service) }
                Button("复制地址", systemImage: "doc.on.doc") { onCopy(service) }
                Button("查看详情", systemImage: "info.circle") { onDetails(service) }
                Divider()
                Button("停止服务…", systemImage: "stop.circle", role: .destructive) { onStop(service) }
            } label: { Image(systemName: "ellipsis") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 28, height: 28)
                .accessibilityLabel("\(service.displayName) 的更多操作").help("更多操作")
        }
        .padding(.horizontal, 14)
        .frame(height: 66)
        .liquidSurface(radius: LSPanelLayout.cardRadius, tint: Color.primary.opacity(isHovering ? 0.075 : 0.028))
        .onHover { isHovering = $0 }
    }
}

private struct ServiceIcon: View {
    let service: ServiceRecord
    var body: some View {
        ZStack {
            Circle().fill(Color.lsAccent.opacity(0.13))
            Text(String(service.displayName.prefix(1)).uppercased())
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.lsAccent)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }
}

private struct ServiceDetailView: View {
    let service: ServiceRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(service.displayName).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(IconButtonStyle()).accessibilityLabel("关闭详情")
                    .keyboardShortcut(.cancelAction)
            }
            Divider()
            ScrollView {
                Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 10) {
                    detailRow("地址", service.url.absoluteString)
                    detailRow("来源", service.sources.map(\.rawValue).sorted().joined(separator: ", "))
                    detailRow("PID", String(service.process.pid))
                    detailRow("最近验证", service.lastHealthyAt.formatted(date: .abbreviated, time: .standard))
                    if let root = service.projectRoot { detailRow("项目目录", root) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.system(size: 12))
        .padding(16)
        .frame(width: 366, height: 286)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).frame(width: 50, alignment: .leading)
            Text(value).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }
}
