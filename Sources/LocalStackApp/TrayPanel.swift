import SwiftUI
import AppKit
import LocalStackShared
import LocalStackCore

struct TrayPanel: View {
    @Bindable var model: AppModel
    @State private var searchText = ""
    @State private var selection: ServiceRecord.ID?
    @State private var selectedIDs = Set<ServiceRecord.ID>()
    @State private var isSelecting = false
    @State private var isPreparingStop = false
    @State private var scrollEdges = ScrollEdges()
    @State private var pendingPreviews: [TerminationPreview] = []
    @State private var showConfirmation = false
    @State private var pendingForcePreviews: [TerminationPreview] = []
    @State private var showForceConfirmation = false
    @State private var detailService: ServiceRecord?
    @State private var showSettings = false
    @State private var copiedURL: String?
    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let initialScrollAnchor: UnitPoint

    private struct ScrollEdges: Equatable {
        var top = false
        var bottom = false
    }

    init(model: AppModel, showSettings: Bool = false, selectedIDs: Set<UUID>? = nil, initialScrollAnchor: UnitPoint = .top) {
        self.model = model
        _showSettings = State(initialValue: showSettings)
        _selectedIDs = State(initialValue: selectedIDs ?? [])
        _isSelecting = State(initialValue: selectedIDs != nil)
        self.initialScrollAnchor = initialScrollAnchor
    }

    private var activeServices: [ServiceRecord] {
        model.services.filter { $0.health == .active }
    }

    private var filteredServices: [ServiceRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return activeServices.filter { service in
            (query.isEmpty || [service.displayName, service.url.absoluteString, service.projectRoot ?? ""]
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
        .onChange(of: filteredServices.map(\.id)) { _, ids in
            selectedIDs.formIntersection(ids)
            if let selection, !ids.contains(selection) { self.selection = nil }
        }
        .alert(item: $model.message) { message in
            Alert(title: Text("LocalStack"), message: Text(message.text), dismissButton: .default(Text("好")))
        }
        .sheet(item: $detailService) { service in ServiceDetailView(service: service) }
        .confirmationDialog("停止服务？", isPresented: $showConfirmation, titleVisibility: .visible) {
            if !pendingPreviews.isEmpty {
                Button(pendingPreviews.count == 1 ? "停止服务" : "停止所选服务", role: .destructive) { stop(pendingPreviews) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(terminationDescription(pendingPreviews))
        }
        .confirmationDialog("强制停止服务？", isPresented: $showForceConfirmation, titleVisibility: .visible) {
            if !pendingForcePreviews.isEmpty {
                Button("强制停止", role: .destructive) { forceStop(pendingForcePreviews) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text((["\(pendingForcePreviews.map(\.displayName).joined(separator: "、")) 没有响应停止请求。强制停止会立即终止这些进程。"]
                + model.terminationFailures).joined(separator: "\n"))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrandIcon(size: 38)
            Text(showSettings ? "设置" : "LocalStack").font(.system(size: 19, weight: .semibold, design: .rounded))
            Spacer()
            if !showSettings {
                Text(String(activeServices.count))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color(white: 0.94) : Color(white: 0.18))
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
        .padding(.top, 16)
        .padding(.bottom, 12)
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
        .padding(.bottom, 14)
        .background {
            Button("") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command).hidden()
        }
    }

    private var listHeader: some View {
        HStack {
            Text("服务列表").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            Spacer()
            if isSelecting {
                Button(allVisibleSelected ? "取消全选" : "全选") {
                    selectedIDs = allVisibleSelected ? [] : Set(filteredServices.map(\.id))
                }
                .buttonStyle(.plain).foregroundStyle(Color.lsAccent)
                Button("完成") { isSelecting = false; selectedIDs.removeAll() }
                    .buttonStyle(.plain).foregroundStyle(.primary)
            } else if !filteredServices.isEmpty {
                Button { isSelecting = true } label: {
                    Label("多选", systemImage: "checkmark.circle")
                }
                .buttonStyle(.plain).foregroundStyle(Color.lsAccent)
            }
        }
        .font(.system(size: 11, weight: .medium))
        .frame(height: 24)
        .disabled(isPreparingStop || model.isStopping)
        .padding(.horizontal, LSPanelLayout.horizontalInset)
        .padding(.bottom, 8)
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
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: LSPanelLayout.serviceRowSpacing) {
                        ForEach(filteredServices) { service in
                            ServiceRow(service: service, isSelecting: isSelecting, isSelected: selectedIDs.contains(service.id),
                                isFocused: selection == service.id, canOpen: !model.isStopping(service), canStop: !isPreparingStop && !model.isStopping,
                                onOpen: { selection = $0.id; isSelecting ? toggleSelection($0) : open($0) },
                                onOpenPage: open, onSelect: toggleSelection, onStop: prepareStop, onCopy: copyURL, onDetails: { detailService = $0 })
                                .id(service.id)
                        }
                    }
                }
                .defaultScrollAnchor(initialScrollAnchor)
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: ScrollEdges.self) { geometry in
                    let offset = geometry.contentOffset.y + geometry.contentInsets.top
                    let remaining = geometry.contentSize.height + geometry.contentInsets.bottom
                        - geometry.containerSize.height - geometry.contentOffset.y
                    return ScrollEdges(top: offset > 1, bottom: remaining > 1)
                } action: { _, edges in scrollEdges = edges }
                .mask {
                    VStack(spacing: 0) {
                        if scrollEdges.top {
                            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 14)
                        }
                        Rectangle().fill(.black)
                        if scrollEdges.bottom {
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 14)
                        }
                    }
                }
                .focusable().focusEffectDisabled()
                .onKeyPress(.return) {
                    guard let service = selectedService ?? filteredServices.first else { return .ignored }
                    if isSelecting { toggleSelection(service) } else { open(service) }
                    return .handled
                }
                .onKeyPress(.delete) {
                    if isSelecting { prepareStops(selectedServices) }
                    else if let selectedService { prepareStop(selectedService) }
                    else { return .ignored }
                    return .handled
                }
                .onKeyPress(.downArrow) { moveSelection(by: 1, proxy: proxy); return .handled }
                .onKeyPress(.upArrow) { moveSelection(by: -1, proxy: proxy); return .handled }
            }
            .frame(height: LSPanelLayout.serviceViewportHeight)
            .padding(.horizontal, LSPanelLayout.horizontalInset)
            .frame(maxHeight: .infinity, alignment: .top)
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
            Text(showSettings ? "设置自动保存" : model.isStopping ? "正在停止…" : isSelecting ? "已选 \(selectedIDs.count) 项" : copiedURL != nil ? "地址已复制" : statusText)
                .font(.lsCaption).foregroundStyle(.secondary)
            Spacer()
            if !showSettings && isSelecting {
                Button("停止所选", role: .destructive) { prepareStops(selectedServices) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.lsDestructive)
                    .padding(.horizontal, 12).frame(height: 28)
                    .background(Color.lsDestructive.opacity(0.10), in: Capsule())
                    .disabled(selectedIDs.isEmpty || isPreparingStop || model.isStopping)
            } else if !showSettings {
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
        .frame(height: showSettings ? 40 : 44)
    }

    private var selectedService: ServiceRecord? { filteredServices.first { $0.id == selection } }
    private var selectedServices: [ServiceRecord] { filteredServices.filter { selectedIDs.contains($0.id) } }
    private var allVisibleSelected: Bool { !filteredServices.isEmpty && selectedIDs.count == filteredServices.count }

    private func toggleSelection(_ service: ServiceRecord) {
        if !selectedIDs.insert(service.id).inserted { selectedIDs.remove(service.id) }
    }
    private func moveSelection(by offset: Int, proxy: ScrollViewProxy) {
        guard !filteredServices.isEmpty else { return }
        let index = filteredServices.firstIndex { $0.id == selection } ?? (offset > 0 ? -1 : filteredServices.count)
        let next = min(max(index + offset, 0), filteredServices.count - 1)
        selection = filteredServices[next].id
        proxy.scrollTo(filteredServices[next].id)
    }
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
    private func prepareStop(_ service: ServiceRecord) { prepareStops([service]) }
    private func prepareStops(_ services: [ServiceRecord]) {
        guard !services.isEmpty, !isPreparingStop, !model.isStopping else { return }
        isPreparingStop = true
        Task {
            defer { isPreparingStop = false }
            let previews = await model.prepareStops(services)
            guard !previews.isEmpty else { return }
            pendingPreviews = previews; showConfirmation = true
        }
    }
    private func stop(_ previews: [TerminationPreview]) {
        Task {
            let forcePreviews = await model.stop(previews)
            guard !forcePreviews.isEmpty else { return }
            pendingForcePreviews = forcePreviews; showForceConfirmation = true
        }
    }
    private func forceStop(_ previews: [TerminationPreview]) { Task { _ = await model.stop(previews, force: true) } }
    private func terminationDescription(_ previews: [TerminationPreview]) -> String {
        let names = previews.map { "\($0.displayName)（:\($0.url.port ?? 80)）" }.joined(separator: "、")
        return "将停止 \(names)。同一进程的其他端口也会关闭。"
    }
}

private struct ServiceRow: View {
    let service: ServiceRecord
    let isSelecting: Bool
    let isSelected: Bool
    let isFocused: Bool
    let canOpen: Bool
    let canStop: Bool
    let onOpen: (ServiceRecord) -> Void
    let onOpenPage: (ServiceRecord) -> Void
    let onSelect: (ServiceRecord) -> Void
    let onStop: (ServiceRecord) -> Void
    let onCopy: (ServiceRecord) -> Void
    let onDetails: (ServiceRecord) -> Void
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            if isSelecting {
                Button { onSelect(service) } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? Color.lsAccent : Color(white: colorScheme == .dark ? 0.62 : 0.48))
                        .frame(width: 20, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(isSelected ? "取消选择" : "选择") \(service.displayName)，端口 \(service.port)")
            }
            Button { onOpen(service) } label: {
                HStack(spacing: 8) {
                    ServiceIcon(service: service)
                    Text(service.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color(white: 0.94) : Color(white: 0.18))
                        .lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("localhost:\(String(service.port))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.lsAccent).fixedSize()
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, minHeight: LSPanelLayout.serviceRowHeight)
            }
            .buttonStyle(.plain)
            .help(service.url.absoluteString)
            .accessibilityLabel("\(isSelecting ? "选择" : "打开") \(service.displayName)，端口 \(String(service.port))")
            Button { onOpenPage(service) } label: { Image(systemName: "arrow.up.right").foregroundStyle(Color.lsAccent) }
                .buttonStyle(ServiceActionStyle(color: .lsAccent))
                .disabled(!canOpen)
                .accessibilityLabel("打开 \(service.displayName)").help("打开页面")
            Button { onStop(service) } label: {
                RoundedRectangle(cornerRadius: 2).fill(Color.lsDestructive).frame(width: 9, height: 9)
            }
                .buttonStyle(ServiceActionStyle(color: .lsDestructive))
                .disabled(!canStop)
                .accessibilityLabel("停止 \(service.displayName)").help("停止服务")
            Menu {
                Button("打开页面", systemImage: "safari") { onOpen(service) }
                Button("复制地址", systemImage: "doc.on.doc") { onCopy(service) }
                Button("查看详情", systemImage: "info.circle") { onDetails(service) }
            } label: { Image(systemName: "ellipsis") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 18, height: 28)
                .accessibilityLabel("\(service.displayName) 的更多操作").help("更多操作")
        }
        .padding(.horizontal, 10)
        .frame(height: LSPanelLayout.serviceRowHeight)
        .liquidSurface(radius: 12, tint: isSelected ? Color.lsAccent.opacity(0.13) : Color.primary.opacity(isHovering || isFocused ? 0.075 : 0.028))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isSelected || isFocused ? Color.lsAccent.opacity(0.5) : .clear, lineWidth: 1))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { isHovering = $0 }
    }

}

private struct ServiceActionStyle: ButtonStyle {
    let color: Color
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 26, height: 26)
            .background(color.opacity(configuration.isPressed ? 0.22 : 0.10), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.4)
    }
}

private struct ServiceIcon: View {
    let service: ServiceRecord
    var body: some View {
        ZStack {
            Circle().fill(Color.lsAccent.opacity(0.13))
            Text(String(service.displayName.prefix(1)).uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.lsAccent)
        }
        .frame(width: 24, height: 24)
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
