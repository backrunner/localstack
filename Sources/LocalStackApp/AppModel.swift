import AppKit
import Foundation
import Observation
import ServiceManagement
import LocalStackCore
import LocalStackShared

@MainActor
@Observable
final class AppModel {
    let updater: AppUpdater
    private enum Backend {
        case embedded(LocalStackCoordinator)
        case remote(UnixJSONRPCClient)
    }

    private let coordinator = LocalStackCoordinator()
    private let server = UnixJSONRPCServer()
    private let client = UnixJSONRPCClient()
    private var hasStarted = false
    private var backend: Backend?

    var services: [ServiceRecord] = []
    var isRefreshing = false
    var isConnected = false
    var message: UserMessage?
    var lastUpdated: Date?
    /// 是否注册为登录项（开机启动）。
    var launchAtLogin = false
    var loginRequiresApproval = false
    private var observationTask: Task<Void, Never>?

    init(previewServices: [ServiceRecord]? = nil) {
        updater = AppUpdater(preview: previewServices != nil)
        if let previewServices {
            services = previewServices
            isConnected = true
            hasStarted = true
            lastUpdated = .now
            return
        }
        DeepLinkRouter.shared.register { [weak self] url in
            Task { await self?.openDeepLink(url) }
        }
        Task { [weak self] in
            await self?.start()
        }
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        startObservation()
        do {
            let rpc = CoordinatorRPCService(coordinator: coordinator, socketPath: UnixJSONRPCServer.defaultSocketPath())
            try server.start { request in await rpc.handle(request) }
            await coordinator.boot()
            await coordinator.start()
            backend = .embedded(coordinator)
        } catch {
            do {
                _ = try await client.status()
                backend = .remote(client)
            } catch {
                hasStarted = false
                message = UserMessage(text: "LocalStack Coordinator 启动失败：\(error.localizedDescription)")
                return
            }
        }
        await synchronizeServices()
        refreshLaunchAtLoginStatus()
        startObservation()
    }

    /// 同步系统登录项状态到 UI。
    func refreshLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled || status == .requiresApproval
        loginRequiresApproval = status == .requiresApproval
    }

    /// 注册/注销登录项。需要用户在系统设置中批准时给出引导提示。
    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    func configureFirstLaunch() {
        refreshLaunchAtLoginStatus()
        let defaults = UserDefaults.standard
        let explicitlyEnabled = CommandLine.arguments.contains("--enable-login")
        let installed = AppInstaller.isInstalled(Bundle.main.bundleURL)
        if explicitlyEnabled || (installed && !defaults.bool(forKey: "didConfigureLoginItem")) {
            setLaunchAtLogin(true)
            if launchAtLogin { defaults.set(true, forKey: "didConfigureLoginItem") }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard AppInstaller.isInstalled(Bundle.main.bundleURL) else {
            message = UserMessage(text: "请先将 LocalStack 安装到应用程序文件夹，再开启登录时启动。")
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            UserDefaults.standard.set(true, forKey: "didConfigureLoginItem")
        } catch {
            message = UserMessage(text: "无法\(enabled ? "开启" : "关闭")开机启动：\(error.localizedDescription)")
        }
        refreshLaunchAtLoginStatus()
        if enabled && SMAppService.mainApp.status == .requiresApproval {
            message = UserMessage(text: "请在“系统设置 › 通用 › 登录项与扩展”中允许 LocalStack 开机启动。")
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        if backend == nil { await start(); return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            switch backend {
            case .embedded(let coordinator): await coordinator.refresh()
            case .remote(let client): try await client.refresh()
            case nil: return
            }
            await synchronizeServices()
        } catch {
            message = UserMessage(text: error.localizedDescription)
        }
    }

    func open(_ service: ServiceRecord) async {
        do {
            let url: URL
            switch backend {
            case .embedded(let coordinator): url = try await coordinator.openTarget(serviceID: service.id)
            case .remote(let client): url = try await client.openTarget(serviceID: service.id)
            case nil: throw CoordinatorError(.internalError, "Coordinator 尚未启动")
            }
            NSWorkspace.shared.open(url)
            await synchronizeServices()
        } catch let error as CoordinatorError {
            message = UserMessage(text: error.message)
            await refresh()
        } catch {
            message = UserMessage(text: error.localizedDescription)
        }
    }

    func openDeepLink(_ url: URL) async {
        await synchronizeServices()
        guard url.scheme == "localstack", url.host == "service",
              let id = UUID(uuidString: url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
              let service = services.first(where: { $0.id == id }) else {
            message = UserMessage(text: "找不到这个本地服务，列表可能已经更新。")
            await refresh()
            return
        }
        await open(service)
    }

    func prepareStop(_ service: ServiceRecord) async -> TerminationPreview? {
        do {
            switch backend {
            case .embedded(let coordinator): return try await coordinator.prepareTermination(serviceID: service.id)
            case .remote(let client): return try await client.prepareTermination(serviceID: service.id)
            case nil: throw CoordinatorError(.internalError, "Coordinator 尚未启动")
            }
        } catch let error as CoordinatorError {
            message = UserMessage(text: error.message)
            await refresh()
            return nil
        } catch {
            message = UserMessage(text: error.localizedDescription)
            return nil
        }
    }

    func stop(_ preview: TerminationPreview, force: Bool = false) async -> TerminationPreview? {
        do {
            let result: TerminationResult
            switch backend {
            case .embedded(let coordinator):
                result = try await coordinator.terminate(serviceID: preview.serviceID, token: preview.token, force: force)
            case .remote(let client):
                result = try await client.terminate(serviceID: preview.serviceID, token: preview.token, force: force)
            case nil:
                throw CoordinatorError(.internalError, "Coordinator 尚未启动")
            }
            if !result.exited && !force {
                await synchronizeServices()
                return try await prepareTermination(serviceID: preview.serviceID)
            } else if !result.exited {
                message = UserMessage(text: "已发送强制停止信号，但进程仍在运行。")
            }
            await synchronizeServices()
            return nil
        } catch let error as CoordinatorError {
            message = UserMessage(text: error.message)
            await synchronizeServices()
            return nil
        } catch {
            message = UserMessage(text: error.localizedDescription)
            return nil
        }
    }

    private func prepareTermination(serviceID: UUID) async throws -> TerminationPreview {
        switch backend {
        case .embedded(let coordinator): return try await coordinator.prepareTermination(serviceID: serviceID)
        case .remote(let client): return try await client.prepareTermination(serviceID: serviceID)
        case nil: throw CoordinatorError(.internalError, "Coordinator 尚未启动")
        }
    }

    private func synchronizeServices() async {
        do {
            switch backend {
            case .embedded(let coordinator): services = await coordinator.list()
            case .remote(let client): services = try await client.list()
            case nil: return
            }
            lastUpdated = .now
            isConnected = true
        } catch {
            isConnected = false
            backend = nil
            hasStarted = false
        }
    }

    /// Stops polling and releases the embedded coordinator/socket when the app exits.
    func shutdown() {
        updater.shutdown()
        observationTask?.cancel()
        observationTask = nil
        server.stop()
        Task { await coordinator.stop() }
    }

    private func startObservation() {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(10)) } catch { return }
                guard let self else { return }
                if self.backend == nil { await self.start() }
                else { await self.synchronizeServices() }
            }
        }
    }

}

struct UserMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}
