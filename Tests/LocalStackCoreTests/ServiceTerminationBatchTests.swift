import Foundation
import Darwin
import Synchronization
import Testing
import LocalStackCore
import LocalStackShared

private func batchService(pid: Int32, port: Int, start: TimeInterval = 100) -> ServiceRecord {
    let url = URL(string: "http://localhost:\(port)/")!
    return ServiceRecord(port: port, url: url,
        process: ProcessFingerprint(pid: pid, uid: 501, startTime: Date(timeIntervalSince1970: start)),
        displayName: "Service \(port)",
        validation: ValidationEvidence(checkedURL: url, finalURL: url, statusCode: 200, contentType: "text/html", title: nil),
        source: .discovered)
}

private func batchPreview(_ service: ServiceRecord) -> TerminationPreview {
    TerminationPreview(serviceID: service.id, token: UUID().uuidString, displayName: service.displayName,
        url: service.url, pid: service.process.pid, executableName: "DemoServer", expiresAt: .now.addingTimeInterval(30))
}

@Test("batch stop prepares one confirmation for each full process identity")
func batchStopDeduplicatesProcessPorts() async throws {
    let services = [batchService(pid: 42, port: 3000), batchService(pid: 42, port: 3001),
        batchService(pid: 43, port: 3002), batchService(pid: 42, port: 3003, start: 101)]
    let requested = Mutex<[UUID]>([])
    let previews = try await ServiceTerminationBatch.prepare(services: services) { id in
        requested.withLock { $0.append(id) }
        return batchPreview(services.first { $0.id == id }!)
    }
    #expect(previews.map(\.serviceID) == [services[0].id, services[2].id, services[3].id])
    #expect(requested.withLock { $0 } == previews.map(\.serviceID))
}

@Test("batch preparation fails before offering a partial confirmation")
func batchStopPreparationFailure() async {
    let services = [batchService(pid: 42, port: 3000), batchService(pid: 43, port: 3001), batchService(pid: 44, port: 3002)]
    let requested = Mutex<[UUID]>([])
    do {
        _ = try await ServiceTerminationBatch.prepare(services: services) { id in
            requested.withLock { $0.append(id) }
            if id == services[1].id { throw CoordinatorError(.staleProcess, "进程已变化") }
            return batchPreview(services[0])
        }
        Issue.record("partial preparation unexpectedly succeeded")
    } catch let error as CoordinatorError {
        #expect(error.code == .staleProcess)
    } catch { Issue.record("unexpected error: \(error)") }
    #expect(requested.withLock { $0 } == [services[0].id, services[1].id])
}

private actor StopGate {
    var calls: [UUID] = []
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func enter(_ id: UUID) async {
        calls.append(id)
        if calls.count == 3 {
            waiting.forEach { $0.resume() }
            waiting.removeAll()
        } else {
            await withCheckedContinuation { waiting.append($0) }
        }
    }
}

@Test("independent batch stops run concurrently and retain all failures and force confirmations", .timeLimit(.minutes(1)))
func batchStopCollectsIndependentOutcomes() async {
    let previews = (0..<3).map { batchPreview(batchService(pid: Int32(42 + $0), port: 3000 + $0)) }
    let gate = StopGate()
    let outcome = await ServiceTerminationBatch.stop(previews: previews) { preview in
        await gate.enter(preview.serviceID)
        if preview.serviceID == previews[1].serviceID { return preview }
        if preview.serviceID == previews[2].serviceID { throw CoordinatorError(.staleTerminationToken, "确认已过期") }
        return nil
    }
    #expect(Set(await gate.calls) == Set(previews.map(\.serviceID)))
    #expect(outcome.forcePreviews.map(\.serviceID) == [previews[1].serviceID])
    #expect(outcome.failures == ["Service 3002：确认已过期"])
}

private final class BatchInspector: ProcessInspecting, Sendable {
    enum Shutdown: Sendable { case exit, closePorts, partialClose, reject }
    let shutdown: Shutdown
    let currentUID: UInt32 = 501
    let process = Mutex<ProcessFingerprint?>(ProcessFingerprint(pid: 42, uid: 501, startTime: Date(timeIntervalSince1970: 100)))
    let signalCount = Mutex(0)
    let ports = Mutex<Set<Int>>([3000, 3001])
    init(shutdown: Shutdown = .exit) { self.shutdown = shutdown }
    func fingerprint(for pid: Int32) -> ProcessFingerprint? { process.withLock { $0?.pid == pid ? $0 : nil } }
    func ownsPort(_ port: Int, pid: Int32) -> Bool { fingerprint(for: pid) != nil && ports.withLock { $0.contains(port) } }
    func listeningPorts(for pid: Int32) -> Set<Int> { fingerprint(for: pid) == nil ? [] : ports.withLock { $0 } }
    func executableName(for pid: Int32) -> String { "DemoServer" }
    func terminate(_ fingerprint: ProcessFingerprint, force: Bool) -> Bool {
        process.withLock {
            guard $0 == fingerprint else { return false }
            guard shutdown != .reject else { return false }
            signalCount.withLock { $0 += 1 }
            if force || shutdown == .exit { $0 = nil }
            else if shutdown == .closePorts { ports.withLock { $0.removeAll() } }
            else if shutdown == .partialClose { ports.withLock { _ = $0.remove(3000) } }
            return true
        }
    }
}

private struct BatchDiscovery: PortDiscovering {
    func listenCandidates() -> [PortCandidate] { [] }
}

private struct BatchPageProbe: PageProbing {
    func probe(_ url: URL) async throws -> PageProbeResult {
        PageProbeResult(evidence: ValidationEvidence(checkedURL: url, finalURL: url,
            statusCode: 200, contentType: "text/html", title: "DemoServer"))
    }
}

@Test("batch stop removes every port of an exited process and refuses a reused PID", arguments: [false, true])
func batchStopRespectsCoordinatorIdentity(reusePID: Bool) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("localstack-batch-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let inspector = BatchInspector()
    let coordinator = LocalStackCoordinator(store: RegistryStore(fileURL: directory.appendingPathComponent("services.json")),
        discovery: BatchDiscovery(), inspector: inspector, probe: BatchPageProbe())
    await coordinator.boot()
    _ = try await coordinator.register(RegistrationRequest(pid: 42, port: 3000))
    _ = try await coordinator.register(RegistrationRequest(pid: 42, port: 3001))
    let previews = try await ServiceTerminationBatch.prepare(services: await coordinator.list()) { id in
        try await coordinator.prepareTermination(serviceID: id)
    }
    #expect(previews.count == 1)
    #expect(previews[0].listeningPorts == [3000, 3001])
    #expect(Set(previews[0].affectedServiceIDs ?? []) == Set((await coordinator.list()).map(\.id)))
    if reusePID {
        inspector.process.withLock { $0 = ProcessFingerprint(pid: 42, uid: 501, startTime: Date(timeIntervalSince1970: 101)) }
    }
    let outcome = await ServiceTerminationBatch.stop(previews: previews) { preview in
        _ = try await coordinator.terminate(serviceID: preview.serviceID, token: preview.token)
        return nil
    }
    #expect(outcome.forcePreviews.isEmpty)
    if reusePID {
        #expect(outcome.failures.count == 1)
        #expect(inspector.signalCount.withLock { $0 } == 0)
    } else {
        #expect(outcome.failures.isEmpty)
        #expect(inspector.signalCount.withLock { $0 } == 1)
        #expect((await coordinator.list()).isEmpty)
    }
}

@Test("closing listeners during graceful process cleanup is a successful stop without rediscovery")
func shutdownClosesPortsBeforeProcessExit() async throws {
    let inspector = BatchInspector(shutdown: .closePorts)
    inspector.ports.withLock { _ = $0.insert(3999) }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("localstack-drain-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let coordinator = LocalStackCoordinator(store: RegistryStore(fileURL: directory.appendingPathComponent("services.json")),
        discovery: BatchDiscovery(), inspector: inspector, probe: BatchPageProbe())
    await coordinator.boot()
    let first = try await coordinator.register(RegistrationRequest(pid: 42, port: 3000))
    let second = try await coordinator.register(RegistrationRequest(pid: 42, port: 3001))
    let preview = try await coordinator.prepareTermination(serviceID: first.service.id)
    #expect(preview.listeningPorts == [3000, 3001, 3999])
    let result = try await coordinator.terminate(serviceID: preview.serviceID, token: preview.token)
    #expect(!result.exited)
    #expect(result.listenersClosed == true)
    #expect(result.forcePreview == nil)
    #expect(Set(result.removedServiceIDs ?? []) == Set([first.service.id, second.service.id]))
    #expect(inspector.fingerprint(for: 42) == preview.process)
    #expect((await coordinator.list()).isEmpty)
}

@Test("partial listener shutdown still allows force stop after the selected port is removed")
func forceStopRetainsProcessIdentityAcrossClosedPort() async throws {
    let inspector = BatchInspector(shutdown: .partialClose)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("localstack-partial-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let coordinator = LocalStackCoordinator(store: RegistryStore(fileURL: directory.appendingPathComponent("services.json")),
        discovery: BatchDiscovery(), inspector: inspector, probe: BatchPageProbe())
    await coordinator.boot()
    let first = try await coordinator.register(RegistrationRequest(pid: 42, port: 3000))
    _ = try await coordinator.register(RegistrationRequest(pid: 42, port: 3001))
    let preview = try await coordinator.prepareTermination(serviceID: first.service.id)
    let result = try await coordinator.terminate(serviceID: preview.serviceID, token: preview.token)
    #expect(!result.exited && result.listenersClosed == false)
    #expect(result.removedServiceIDs == [first.service.id])
    #expect((await coordinator.list()).map(\.port) == [3001])
    let retry = try #require(result.forcePreview)
    await coordinator.refresh()
    #expect((await coordinator.list()).map(\.port) == [3001])
    let forced = try await coordinator.terminate(serviceID: retry.serviceID, token: retry.token, force: true)
    #expect(forced.exited && forced.listenersClosed == true)
    #expect(inspector.signalCount.withLock { $0 } == 2)
    #expect((await coordinator.list()).isEmpty)
}

@Test("a delayed force confirmation never signals a replacement process")
func gracefulExitBeforeForceConfirmationIsSuccess() async throws {
    let inspector = BatchInspector(shutdown: .partialClose)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("localstack-force-race-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let coordinator = LocalStackCoordinator(store: RegistryStore(fileURL: directory.appendingPathComponent("services.json")),
        discovery: BatchDiscovery(), inspector: inspector, probe: BatchPageProbe())
    await coordinator.boot()
    let original = try await coordinator.register(RegistrationRequest(pid: 42, port: 3000))
    _ = try await coordinator.register(RegistrationRequest(pid: 42, port: 3001))
    let preview = try await coordinator.prepareTermination(serviceID: original.service.id)
    let result = try await coordinator.terminate(serviceID: preview.serviceID, token: preview.token)
    let retry = try #require(result.forcePreview)
    let replacement = ProcessFingerprint(pid: 42, uid: 501, startTime: Date(timeIntervalSince1970: 101))
    inspector.process.withLock { $0 = replacement }
    inspector.ports.withLock { $0 = [3000, 3001] }
    let newRecord = try await coordinator.register(RegistrationRequest(pid: 42, port: 3000))
    let forced = try await coordinator.terminate(serviceID: retry.serviceID, token: retry.token, force: true)
    #expect(forced.exited)
    #expect(inspector.signalCount.withLock { $0 } == 1)
    #expect((await coordinator.list()).contains { $0.id == newRecord.service.id && $0.process == replacement })
}

@Test("a rejected stop preserves all listener records")
func rejectedSignalDoesNotHideServices() async throws {
    let inspector = BatchInspector(shutdown: .reject)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("localstack-stop-rejected-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let coordinator = LocalStackCoordinator(store: RegistryStore(fileURL: directory.appendingPathComponent("services.json")),
        discovery: BatchDiscovery(), inspector: inspector, probe: BatchPageProbe())
    await coordinator.boot()
    let first = try await coordinator.register(RegistrationRequest(pid: 42, port: 3000))
    _ = try await coordinator.register(RegistrationRequest(pid: 42, port: 3001))
    let preview = try await coordinator.prepareTermination(serviceID: first.service.id)
    do {
        _ = try await coordinator.terminate(serviceID: preview.serviceID, token: preview.token)
        Issue.record("rejected signal unexpectedly succeeded")
    } catch let error as CoordinatorError { #expect(error.code == .terminationRejected) }
    #expect((await coordinator.list()).count == 2)
}

@Test("native SIGTERM removes all service ports while the child process is still cleaning up", .timeLimit(.minutes(1)))
func nativeGracefulShutdownRemovesPortsImmediately() async throws {
    let child = Process()
    let output = Pipe()
    child.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    child.arguments = ["-u", "-c", """
    import json, signal, socket, sys, time
    listeners = []
    for _ in range(2):
        listener = socket.socket()
        listener.bind(('127.0.0.1', 0))
        listener.listen()
        listeners.append(listener)
    def shutdown(signum, frame):
        for listener in listeners:
            listener.close()
        time.sleep(8)
        sys.exit(0)
    signal.signal(signal.SIGTERM, shutdown)
    print(json.dumps([listener.getsockname()[1] for listener in listeners]), flush=True)
    while True:
        time.sleep(30)
    """]
    child.standardOutput = output
    try child.run()
    defer {
        if child.isRunning { _ = kill(child.processIdentifier, SIGKILL) }
        child.waitUntilExit()
    }
    let ports = try JSONDecoder().decode([Int].self, from: output.fileHandleForReading.availableData)
    try #require(ports.count == 2)
    let inspector = ProcessInspector()
    let process = try #require(inspector.fingerprint(for: child.processIdentifier))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("localstack-native-stop-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let coordinator = LocalStackCoordinator(store: RegistryStore(fileURL: directory.appendingPathComponent("services.json")),
        discovery: BatchDiscovery(), inspector: inspector, probe: BatchPageProbe())
    await coordinator.boot()
    let first = try await coordinator.register(RegistrationRequest(pid: process.pid, port: ports[0]))
    let second = try await coordinator.register(RegistrationRequest(pid: process.pid, port: ports[1]))
    let preview = try await coordinator.prepareTermination(serviceID: first.service.id)
    #expect(Set(preview.listeningPorts ?? []) == Set(ports))
    let result = try await coordinator.terminate(serviceID: preview.serviceID, token: preview.token)
    #expect(!result.exited && result.listenersClosed == true)
    #expect(inspector.fingerprint(for: process.pid) == process)
    #expect(inspector.listeningPorts(for: process.pid).isEmpty)
    #expect(Set(result.removedServiceIDs ?? []) == Set([first.service.id, second.service.id]))
    #expect((await coordinator.list()).isEmpty)
    #expect(result.forcePreview == nil)
}

@Test("termination metadata survives RPC encoding and old payloads remain decodable")
func terminationWireCompatibility() throws {
    let record = batchService(pid: 42, port: 3000)
    let legacy = batchPreview(record)
    let oldPreview = try JSONDecoder.local.decode(TerminationPreview.self, from: JSONEncoder.local.encode(legacy))
    #expect(oldPreview.process == nil && oldPreview.listeningPorts == nil && oldPreview.affectedServiceIDs == nil)
    let oldResult = TerminationResult(serviceID: record.id, signal: SIGTERM, exited: true)
    let decodedOld = try JSONDecoder.local.decode(TerminationResult.self, from: JSONEncoder.local.encode(oldResult))
    #expect(decodedOld.listenersClosed == nil && decodedOld.removedServiceIDs == nil && decodedOld.forcePreview == nil)
    let preview = TerminationPreview(serviceID: record.id, token: legacy.token, displayName: record.displayName,
        url: record.url, pid: record.process.pid, executableName: "DemoServer", expiresAt: legacy.expiresAt,
        process: record.process, listeningPorts: [3000, 3001], affectedServiceIDs: [record.id])
    let newResult = TerminationResult(serviceID: record.id, signal: SIGTERM, exited: false,
        listenersClosed: false, removedServiceIDs: [], forcePreview: preview)
    let decoded = try JSONDecoder.local.decode(TerminationResult.self, from: JSONEncoder.local.encode(newResult))
    #expect(decoded.forcePreview?.process == record.process)
    #expect(decoded.forcePreview?.listeningPorts == [3000, 3001])
    #expect(decoded.listenersClosed == false)
}
