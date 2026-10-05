import Darwin
import Foundation
import LocalStackShared

public actor LocalStackCoordinator {
    public static let version = "0.1.0"

    private struct Lease: Sendable {
        let serviceID: UUID
        let source: ServiceSourceKind
        let token: String
        let expiresAt: Date
    }

    private let store: RegistryStore
    private let discovery: any PortDiscovering
    private let inspector: any ProcessInspecting
    private let probe: any PageProbing
    private var records: [ServiceRecord] = []
    private var leases: [UUID: Lease] = [:]
    private var terminationTokens: [String: (serviceID: UUID, expiresAt: Date)] = [:]
    private var pollTask: Task<Void, Never>?
    private var lastScanAt: Date?
    private var refreshInProgress = false
    private var isReady = false
    private var discoveryBackoff = DiscoveryProbeBackoff()

    private struct ScanProbeResult: Sendable {
        let candidate: PortCandidate
        let process: ProcessFingerprint
        let result: Result<PageProbeResult, CoordinatorError>
    }

    public init(
        store: RegistryStore = RegistryStore(),
        discovery: any PortDiscovering = PortDiscovery(),
        inspector: any ProcessInspecting = ProcessInspector(),
        probe: any PageProbing = PageProbe()
    ) {
        self.store = store
        self.discovery = discovery
        self.inspector = inspector
        self.probe = probe
    }

    public func boot() async {
        isReady = false
        let loaded = await store.load()
        records = loaded.compactMap { record in
            var restored = record
            restored.sources = restored.sources.intersection([.discovered])
            return restored.sources.isEmpty ? nil : restored
        }
        await refresh()
        isReady = true
        try? await persist()
    }

    public func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    public func refresh() async {
        guard !refreshInProgress else { return }
        refreshInProgress = true
        defer { refreshInProgress = false }
        expireLeases()
        pruneTerminationTokens()
        let newlyValidated = await scan()
        await healthCheck(excluding: newlyValidated)
        try? await persist()
    }

    public func list() -> [ServiceRecord] {
        guard isReady else { return [] }
        return records.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    public func widgetSnapshot() -> ServiceWidgetSnapshot {
        guard isReady else { return ServiceWidgetSnapshot(services: []) }
        return ServiceWidgetSnapshot(services: list().prefix(5).map(WidgetService.init(from:)))
    }

    public func register(_ request: RegistrationRequest) async throws -> RegistrationResponse {
        try requireReady()
        expireLeases()
        guard (1...65535).contains(request.port), request.pid > 0 else {
            throw CoordinatorError(.invalidRequest, "PID 和端口无效")
        }
        let process = try validateProcess(pid: request.pid)
        guard inspector.ownsPort(request.port, pid: request.pid) else {
            throw CoordinatorError(.portUnavailable, "PID \(request.pid) 当前没有监听端口 \(request.port)")
        }
        let targetURL = try normalizedURL(request.url, port: request.port)
        let result = try await probe.probe(targetURL)
        guard let currentProcess = inspector.fingerprint(for: request.pid), currentProcess == process,
              inspector.ownsPort(request.port, pid: request.pid) else {
            throw CoordinatorError(.staleProcess, "服务在页面验证期间已退出或端口已变化")
        }
        let service = upsert(
            port: request.port,
            url: result.evidence.finalURL,
            process: process,
            evidence: result.evidence,
            source: request.source,
            displayName: request.displayName,
            projectRoot: request.projectRoot
        )
        let registrationID = UUID()
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let expiresAt = Date().addingTimeInterval(45)
        leases[registrationID] = Lease(serviceID: service.id, source: request.source, token: token, expiresAt: expiresAt)
        try await persist()
        return RegistrationResponse(service: service, registrationID: registrationID, leaseToken: token, leaseExpiresAt: expiresAt)
    }

    public func heartbeat(registrationID: UUID, token: String) async throws -> Date {
        try requireReady()
        expireLeases()
        guard let lease = leases[registrationID] else {
            throw CoordinatorError(.notFound, "注册 lease 不存在或已过期")
        }
        guard lease.token == token else {
            throw CoordinatorError(.notFound, "注册 token 无效")
        }
        let expiresAt = Date().addingTimeInterval(45)
        leases[registrationID] = Lease(serviceID: lease.serviceID, source: lease.source, token: lease.token, expiresAt: expiresAt)
        return expiresAt
    }

    public func unregister(registrationID: UUID, token: String) async throws {
        try requireReady()
        expireLeases()
        guard let lease = leases.removeValue(forKey: registrationID) else {
            throw CoordinatorError(.notFound, "注册 lease 不存在或已过期")
        }
        guard lease.token == token else {
            leases[registrationID] = lease
            throw CoordinatorError(.notFound, "注册 token 无效")
        }
        removeLeasedSourceIfUnused(lease.source, from: lease.serviceID)
        try await persist()
    }

    public func openTarget(serviceID: UUID) async throws -> URL {
        try requireReady()
        guard let record = records.first(where: { $0.id == serviceID }) else {
            throw CoordinatorError(.notFound, "服务不存在")
        }
        let currentProcess = try validateProcess(pid: record.process.pid)
        guard currentProcess == record.process, inspector.ownsPort(record.port, pid: record.process.pid) else {
            removeRecord(serviceID)
            try await persist()
            throw CoordinatorError(.staleProcess, "服务进程已变化，已刷新列表")
        }
        let result = try await probe.probe(record.url)
        guard let current = records.first(where: { $0.id == serviceID }), current.process == currentProcess else {
            throw CoordinatorError(.staleProcess, "服务在打开前发生变化")
        }
        guard let verifiedProcess = inspector.fingerprint(for: current.process.pid), verifiedProcess == current.process,
              inspector.ownsPort(current.port, pid: current.process.pid) else {
            removeRecord(serviceID)
            try await persist()
            throw CoordinatorError(.staleProcess, "服务在页面验证期间发生变化")
        }
        updateEvidence(result.evidence, for: current.id)
        try await persist()
        return result.evidence.finalURL
    }

    public func prepareTermination(serviceID: UUID) throws -> TerminationPreview {
        try requireReady()
        guard let record = records.first(where: { $0.id == serviceID }) else {
            throw CoordinatorError(.notFound, "服务不存在")
        }
        guard !isProtectedProcess(record.process.pid) else {
            throw CoordinatorError(.terminationRejected, "不能终止 LocalStack 自身进程")
        }
        pruneTerminationTokens()
        guard let current = inspector.fingerprint(for: record.process.pid), current == record.process,
              inspector.ownsPort(record.port, pid: record.process.pid) else {
            throw CoordinatorError(.staleProcess, "服务进程已变化，无法终止")
        }
        let token = UUID().uuidString
        let expiresAt = Date().addingTimeInterval(30)
        terminationTokens[token] = (serviceID, expiresAt)
        return TerminationPreview(
            serviceID: record.id,
            token: token,
            displayName: record.displayName,
            url: record.url,
            pid: record.process.pid,
            executableName: inspector.executableName(for: record.process.pid),
            expiresAt: expiresAt
        )
    }

    public func terminate(serviceID: UUID, token: String, force: Bool = false) async throws -> TerminationResult {
        try requireReady()
        guard let stored = terminationTokens.removeValue(forKey: token), stored.serviceID == serviceID,
              stored.expiresAt > .now else {
            throw CoordinatorError(.staleTerminationToken, "停止确认已过期，请重新确认")
        }
        guard let record = records.first(where: { $0.id == serviceID }),
              let current = inspector.fingerprint(for: record.process.pid), current == record.process,
              inspector.ownsPort(record.port, pid: record.process.pid) else {
            throw CoordinatorError(.terminationRejected, "进程或端口已变化，未执行停止")
        }
        guard !isProtectedProcess(record.process.pid) else {
            throw CoordinatorError(.terminationRejected, "不能终止 LocalStack 自身进程")
        }
        guard inspector.terminate(record.process, force: force) else {
            throw CoordinatorError(.terminationRejected, "系统拒绝了停止信号")
        }
        for _ in 0..<16 {
            try await Task.sleep(for: .milliseconds(250))
            if inspector.fingerprint(for: record.process.pid) != record.process {
                removeRecord(serviceID)
                try await persist()
                return TerminationResult(serviceID: serviceID, signal: force ? SIGKILL : SIGTERM, exited: true)
            }
        }
        return TerminationResult(serviceID: serviceID, signal: force ? SIGKILL : SIGTERM, exited: false)
    }

    public func status(socketPath: String) -> CoordinatorStatus {
        CoordinatorStatus(version: Self.version, socketPath: socketPath, serviceCount: isReady ? records.count : 0, lastScanAt: isReady ? lastScanAt : nil)
    }

    private func scan() async -> Set<UUID> {
        lastScanAt = .now
        let candidates = discovery.listenCandidates()
        var presentKeys = Set<String>()
        var newlyValidated = Set<UUID>()
        var candidatesToProbe: [(PortCandidate, ProcessFingerprint)] = []
        var probeTargets = Set<DiscoveryProbeBackoff.Target>()
        for candidate in candidates {
            guard let process = inspector.fingerprint(for: candidate.pid), process.uid == inspector.currentUID,
                  inspector.ownsPort(candidate.port, pid: candidate.pid),
                  !inspector.isInternalDevelopmentEndpoint(candidate, process: process) else { continue }
            let candidateKey = key(port: candidate.port, process: process)
            presentKeys.insert(candidateKey)
            let target = DiscoveryProbeBackoff.Target(candidate: candidate, process: process)
            guard probeTargets.insert(target).inserted else { continue }
            if let existingIndex = records.firstIndex(where: { key(for: $0) == candidateKey }) {
                records[existingIndex].sources.insert(.discovered)
                records[existingIndex].lastSeenAt = .now
                continue
            }
            if discoveryBackoff.allows(target) {
                candidatesToProbe.append((candidate, process))
            }
        }
        discoveryBackoff.retain(probeTargets)

        var iterator = candidatesToProbe.makeIterator()
        await withTaskGroup(of: ScanProbeResult.self) { group in
            for _ in 0..<min(4, candidatesToProbe.count) {
                guard let next = iterator.next() else { break }
                addProbeTask(next, to: &group)
            }
            for await result in group {
                if let next = iterator.next() {
                    addProbeTask(next, to: &group)
                }
                let target = DiscoveryProbeBackoff.Target(candidate: result.candidate, process: result.process)
                guard case .success(let page) = result.result else {
                    if case .failure(let error) = result.result, error.code != .staleProcess {
                        discoveryBackoff.reject(target)
                    }
                    continue
                }
                discoveryBackoff.accept(target)
                guard let currentProcess = inspector.fingerprint(for: result.candidate.pid), currentProcess == result.process,
                      inspector.ownsPort(result.candidate.port, pid: result.candidate.pid),
                      !inspector.isInternalDevelopmentEndpoint(result.candidate, process: result.process) else {
                    continue
                }
                let service = upsert(
                    port: result.candidate.port,
                    url: page.evidence.finalURL,
                    process: result.process,
                    evidence: page.evidence,
                    source: .discovered,
                    displayName: nil,
                    projectRoot: nil
                )
                newlyValidated.insert(service.id)
            }
        }
        for record in records where record.sources.contains(.discovered) && !presentKeys.contains(key(for: record)) {
            var updated = record
            updated.sources.remove(.discovered)
            if updated.sources.isEmpty {
                removeRecord(record.id)
            } else {
                replace(updated)
            }
        }
        return newlyValidated
    }

    private func addProbeTask(
        _ item: (PortCandidate, ProcessFingerprint),
        to group: inout TaskGroup<ScanProbeResult>
    ) {
        let (candidate, process) = item
        group.addTask { [probe, inspector] in
            guard inspector.fingerprint(for: candidate.pid) == process,
                  inspector.ownsPort(candidate.port, pid: candidate.pid),
                  !inspector.isInternalDevelopmentEndpoint(candidate, process: process) else {
                return ScanProbeResult(candidate: candidate, process: process,
                    result: .failure(CoordinatorError(.staleProcess, "候选进程或监听端点已变化")))
            }
            do {
                return ScanProbeResult(candidate: candidate, process: process, result: .success(try await probe.probe(candidate.url)))
            } catch let error as CoordinatorError {
                return ScanProbeResult(candidate: candidate, process: process, result: .failure(error))
            } catch {
                return ScanProbeResult(candidate: candidate, process: process, result: .failure(CoordinatorError(.pageUnavailable, error.localizedDescription)))
            }
        }
    }

    private func healthCheck(excluding serviceIDs: Set<UUID>) async {
        for record in records where !serviceIDs.contains(record.id) {
            guard let currentProcess = inspector.fingerprint(for: record.process.pid), currentProcess == record.process,
                  inspector.ownsPort(record.port, pid: record.process.pid) else {
                removeRecord(record.id)
                continue
            }
            do {
                let result = try await probe.probe(record.url)
                updateEvidence(result.evidence, for: record.id)
                if let current = records.first(where: { $0.id == record.id }) {
                    var healthy = current
                    healthy.health = .active
                    healthy.consecutiveFailures = 0
                    healthy.lastHealthyAt = .now
                    healthy.lastSeenAt = .now
                    replace(healthy)
                }
            } catch {
                guard let current = records.first(where: { $0.id == record.id }) else { continue }
                var degraded = current
                degraded.consecutiveFailures += 1
                degraded.health = .degraded
                if degraded.consecutiveFailures >= 3 {
                    removeRecord(record.id)
                } else {
                    replace(degraded)
                }
            }
        }
    }

    private func expireLeases() {
        let expired = leases.filter { $0.value.expiresAt <= .now }
        for (id, lease) in expired {
            leases.removeValue(forKey: id)
            removeLeasedSourceIfUnused(lease.source, from: lease.serviceID)
        }
    }

    private func validateProcess(pid: Int32) throws -> ProcessFingerprint {
        guard let process = inspector.fingerprint(for: pid) else {
            throw CoordinatorError(.processUnavailable, "PID \(pid) 不存在或不可读取")
        }
        guard process.uid == inspector.currentUID else {
            throw CoordinatorError(.notCurrentUser, "只能管理当前用户启动的进程")
        }
        return process
    }

    private func requireReady() throws {
        guard isReady else {
            throw CoordinatorError(.internalError, "Coordinator 尚未就绪")
        }
    }

    private func normalizedURL(_ requested: URL?, port: Int) throws -> URL {
        let url = requested ?? URL(string: "http://127.0.0.1:\(port)/")!
        guard let host = url.host?.lowercased(), ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host),
              url.scheme?.lowercased() == "http",
              url.user == nil, url.password == nil,
              (url.port ?? 80) == port else {
            throw CoordinatorError(.outsideLoopback, "URL 必须是同端口的 HTTP loopback 地址")
        }
        return url
    }

    @discardableResult
    private func upsert(
        port: Int,
        url: URL,
        process: ProcessFingerprint,
        evidence: ValidationEvidence,
        source: ServiceSourceKind,
        displayName: String?,
        projectRoot: String?
    ) -> ServiceRecord {
        let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = trimmedName?.isEmpty == false ? trimmedName : nil
        let endpointKey = "127.0.0.1:\(port)"
        let conflictingIDs = records
            .filter { $0.endpointKey == endpointKey && $0.process != process }
            .map(\.id)
        for serviceID in conflictingIDs {
            removeRecord(serviceID)
        }
        if let index = records.firstIndex(where: { $0.endpointKey == endpointKey && $0.process == process }) {
            var record = records[index]
            record.url = url
            record.sources.insert(source)
            record.title = evidence.title ?? record.title
            record.faviconURL = evidence.faviconURL ?? record.faviconURL
            record.validation = evidence
            record.health = .active
            record.consecutiveFailures = 0
            record.lastSeenAt = .now
            record.lastHealthyAt = .now
            if let normalizedName {
                record.displayName = normalizedName
            } else if record.displayName.isEmpty || record.displayName == "localhost:\(port)" {
                record.displayName = evidence.title ?? "localhost:\(port)"
            }
            if let projectRoot { record.projectRoot = projectRoot }
            records[index] = record
            return record
        }
        let record = ServiceRecord(
            port: port,
            url: url,
            process: process,
            displayName: normalizedName ?? evidence.title ?? "localhost:\(port)",
            projectRoot: projectRoot,
            validation: evidence,
            source: source
        )
        records.append(record)
        return record
    }

    private func key(for record: ServiceRecord) -> String {
        key(port: record.port, process: record.process)
    }

    private func key(port: Int, process: ProcessFingerprint) -> String {
        "127.0.0.1:\(port)-\(process.pid)-\(process.startTime.timeIntervalSince1970)"
    }

    private func removeSource(_ source: ServiceSourceKind, from serviceID: UUID) {
        guard let index = records.firstIndex(where: { $0.id == serviceID }) else { return }
        var record = records[index]
        record.sources.remove(source)
        if record.sources.isEmpty { records.remove(at: index) }
        else { records[index] = record }
    }

    private func removeLeasedSourceIfUnused(_ source: ServiceSourceKind, from serviceID: UUID) {
        guard !leases.values.contains(where: { $0.serviceID == serviceID && $0.source == source }) else { return }
        removeSource(source, from: serviceID)
        guard let index = records.firstIndex(where: { $0.id == serviceID }),
              records[index].sources.isDisjoint(with: [.sdk, .unplugin, .mcp]) else {
            return
        }
        records[index].displayName = records[index].title ?? "localhost:\(records[index].port)"
        records[index].projectRoot = nil
    }

    private func removeRecord(_ serviceID: UUID) {
        records.removeAll { $0.id == serviceID }
        leases = leases.filter { $0.value.serviceID != serviceID }
        terminationTokens = terminationTokens.filter { $0.value.serviceID != serviceID }
    }

    private func replace(_ record: ServiceRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
    }

    private func updateEvidence(_ evidence: ValidationEvidence, for serviceID: UUID) {
        guard let index = records.firstIndex(where: { $0.id == serviceID }) else { return }
        records[index].url = evidence.finalURL
        records[index].validation = evidence
        records[index].title = evidence.title ?? records[index].title
        records[index].faviconURL = evidence.faviconURL ?? records[index].faviconURL
    }

    private func pruneTerminationTokens() {
        let now = Date()
        terminationTokens = terminationTokens.filter { $0.value.expiresAt > now }
    }

    private func isProtectedProcess(_ pid: Int32) -> Bool {
        if pid == getpid() { return true }
        return ["LocalStack", "LocalStackApp", "LocalStackCoordinator", "localstack"]
            .contains(inspector.executableName(for: pid))
    }

    private func persist() async throws {
        try await store.save(records)
        try? WidgetSnapshotStore().save(widgetSnapshot())
    }
}
