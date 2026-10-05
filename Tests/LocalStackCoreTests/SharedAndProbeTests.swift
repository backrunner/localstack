import Foundation
import Darwin
import Testing
import LocalStackCore
import LocalStackShared
import Synchronization

@Test("JSON value round trips dates and service records")
func jsonValueRoundTrip() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let evidence = ValidationEvidence(
        checkedURL: URL(string: "http://127.0.0.1:4173/")!,
        finalURL: URL(string: "http://127.0.0.1:4173/")!,
        statusCode: 200,
        contentType: "text/html",
        title: "Console",
        checkedAt: now
    )
    let record = ServiceRecord(
        port: 4173,
        url: evidence.finalURL,
        process: ProcessFingerprint(pid: 42, uid: 501, startTime: Date(timeIntervalSince1970: 100)),
        displayName: "Console",
        validation: evidence,
        source: .discovered,
        now: now
    )
    let value = try JSONValue.from(record)
    let decoded = try value.decode(ServiceRecord.self)
    #expect(decoded == record)
}

@Test("Registry store writes and restores records")
func registryStorePersists() async throws {
    let now = Date(timeIntervalSince1970: 1_700_000_001)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = RegistryStore(fileURL: directory.appendingPathComponent("services.json"))
    let evidence = ValidationEvidence(
        checkedURL: URL(string: "http://127.0.0.1:3000/")!,
        finalURL: URL(string: "http://127.0.0.1:3000/")!,
        statusCode: 200,
        contentType: "text/html",
        title: "Demo",
        checkedAt: now
    )
    let record = ServiceRecord(
        port: 3000,
        url: evidence.finalURL,
        process: ProcessFingerprint(pid: 43, uid: 501, startTime: Date(timeIntervalSince1970: 101)),
        displayName: "Demo",
        validation: evidence,
        source: .discovered,
        now: now
    )
    try await store.save([record])
    #expect(await store.load() == [record])
}

@Test("Page probe rejects non-loopback targets before network access")
func pageProbeRejectsOutsideLoopback() async {
    do {
        _ = try await PageProbe().probe(URL(string: "http://example.com/")!)
        Issue.record("expected outside loopback error")
    } catch let error as CoordinatorError {
        #expect(error.code == .outsideLoopback)
    } catch {
        Issue.record("unexpected error: \(error)")
    }

    do {
        _ = try await PageProbe().probe(URL(string: "http://user:password@127.0.0.1:4173/")!)
        Issue.record("expected userinfo URL rejection")
    } catch let error as CoordinatorError {
        #expect(error.code == .outsideLoopback)
    } catch {
        Issue.record("unexpected userinfo error: \(error)")
    }
}

@Test("Widget snapshot contains no process identity")
func widgetSnapshotIsSafe() {
    let evidence = ValidationEvidence(
        checkedURL: URL(string: "http://127.0.0.1:8080/")!,
        finalURL: URL(string: "http://127.0.0.1:8080/")!,
        statusCode: 200,
        contentType: "text/html",
        title: "Docs"
    )
    let record = ServiceRecord(
        port: 8080,
        url: evidence.finalURL,
        process: ProcessFingerprint(pid: 44, uid: 501, startTime: .now),
        displayName: "Docs",
        projectRoot: "/private/project",
        validation: evidence,
        source: .sdk
    )
    let snapshot = ServiceWidgetSnapshot(services: [WidgetService(from: record)])
    let data = try? JSONEncoder.local.encode(snapshot)
    let string = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    #expect(!string.contains("pid"))
    #expect(!string.contains("projectRoot"))
    #expect(!string.contains("private/project"))
}

private struct MockDiscovery: PortDiscovering {
    let candidates: [PortCandidate]

    func listenCandidates() -> [PortCandidate] { candidates }
}

private struct MockInspector: ProcessInspecting {
    let process: ProcessFingerprint
    let listeningPort: Int

    init(process: ProcessFingerprint, listeningPort: Int = 4173) {
        self.process = process
        self.listeningPort = listeningPort
    }

    var currentUID: UInt32 { process.uid }
    func fingerprint(for pid: Int32) -> ProcessFingerprint? { pid == process.pid ? process : nil }
    func ownsPort(_ port: Int, pid: Int32) -> Bool { port == listeningPort && pid == process.pid }
    func executableName(for pid: Int32) -> String { "DemoServer" }
    func terminate(_ fingerprint: ProcessFingerprint, force: Bool) -> Bool { true }
}

private actor MockProbe: PageProbing {
    enum Outcome: Sendable {
        case success(PageProbeResult)
        case failure(CoordinatorError)
    }

    var outcomes: [Outcome]
    var callCount = 0

    init(outcomes: [Outcome]) { self.outcomes = outcomes }

    func probe(_ url: URL) async throws -> PageProbeResult {
        callCount += 1
        guard !outcomes.isEmpty else { throw CoordinatorError(.pageUnavailable, "no mock result") }
        switch outcomes.removeFirst() {
        case .success(let result): return result
        case .failure(let error): throw error
        }
    }
}

@Test("rejected discovery targets are not retried on every refresh")
func rejectedDiscoveryBacksOff() async {
    let process = ProcessFingerprint(pid: 42, uid: 501, startTime: Date(timeIntervalSince1970: 100))
    let candidate = PortCandidate(pid: process.pid, port: 4173, url: URL(string: "http://127.0.0.1:4173/")!)
    let probe = MockProbe(outcomes: [.failure(CoordinatorError(.notBrowsablePage, "API"))])
    let coordinator = LocalStackCoordinator(
        store: testStore(),
        discovery: MockDiscovery(candidates: [candidate, candidate]),
        inspector: MockInspector(process: process),
        probe: probe
    )
    await coordinator.boot()
    for _ in 0..<5 { await coordinator.refresh() }
    #expect(await probe.callCount == 1)
    #expect((await coordinator.list()).isEmpty)
    // Explicit registration is user initiated and bypasses automatic backoff.
    _ = try? await coordinator.register(RegistrationRequest(pid: process.pid, port: 4173))
    #expect(await probe.callCount == 2)
}

private func mockEvidence(port: Int = 4173, path: String = "/") -> PageProbeResult {
    let url = URL(string: "http://127.0.0.1:\(port)\(path)")!
    return PageProbeResult(evidence: ValidationEvidence(
        checkedURL: url,
        finalURL: url,
        statusCode: 200,
        contentType: "text/html",
        title: "Demo",
        checkedAt: Date(timeIntervalSince1970: 1_700_000_000)
    ))
}

private func testStore() -> RegistryStore {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("localstack-review-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("services.json")
    return RegistryStore(fileURL: path)
}

private final class LiveDiscovery: PortDiscovering, ProcessInspecting, Sendable {
    struct Snapshot: Sendable {
        let process: ProcessFingerprint
        let ports: Set<Int>
        let internalPorts: Set<Int>
    }
    let state: Mutex<Snapshot>
    init(_ snapshot: Snapshot) { state = Mutex(snapshot) }
    var currentUID: UInt32 { 501 }
    func listenCandidates() -> [PortCandidate] {
        state.withLock { snapshot in snapshot.ports.sorted().map {
            PortCandidate(pid: snapshot.process.pid, port: $0, url: URL(string: "http://127.0.0.1:\($0)/")!)
        } }
    }
    func fingerprint(for pid: Int32) -> ProcessFingerprint? {
        state.withLock { $0.process.pid == pid ? $0.process : nil }
    }
    func ownsPort(_ port: Int, pid: Int32) -> Bool {
        state.withLock { $0.process.pid == pid && $0.ports.contains(port) }
    }
    func isInternalDevelopmentEndpoint(_ candidate: PortCandidate, process: ProcessFingerprint) -> Bool {
        state.withLock { $0.process == process && candidate.pid == process.pid && $0.internalPorts.contains(candidate.port) }
    }
    func executableName(for pid: Int32) -> String { "DemoServer" }
    func terminate(_ fingerprint: ProcessFingerprint, force: Bool) -> Bool { false }
}

@Test("internal exclusions disappear immediately when live evidence changes", arguments: ["metadata", "pid-reuse", "port-owner"])
func internalExclusionIsProcessBound(change: String) async throws {
    let original = ProcessFingerprint(pid: 42, uid: 501, startTime: Date(timeIntervalSince1970: 100))
    let live = LiveDiscovery(.init(process: original, ports: [4173], internalPorts: [4173]))
    let probe = MockProbe(outcomes: [.success(mockEvidence()), .success(mockEvidence())])
    let coordinator = LocalStackCoordinator(store: testStore(), discovery: live, inspector: live, probe: probe)
    await coordinator.boot()
    await coordinator.refresh()
    #expect(await probe.callCount == 0)
    #expect((await coordinator.list()).isEmpty)

    let current = ProcessFingerprint(pid: change == "port-owner" ? 43 : 42, uid: 501,
        startTime: Date(timeIntervalSince1970: change == "metadata" ? 100 : 101))
    live.state.withLock { $0 = .init(process: current, ports: [4173], internalPorts: []) }
    await coordinator.refresh()
    #expect(await probe.callCount == 1)
    #expect((await coordinator.list()).first?.process == current)

    // Existing discovered records also stop being probed while proven internal.
    live.state.withLock { $0 = .init(process: current, ports: [4173], internalPorts: [4173]) }
    await coordinator.refresh()
    #expect(await probe.callCount == 1)
    #expect((await coordinator.list()).isEmpty)
    live.state.withLock { $0 = .init(process: current, ports: [4173], internalPorts: []) }
    await coordinator.refresh()
    #expect(await probe.callCount == 2)
    #expect((await coordinator.list()).count == 1)
}

@Test("an internal endpoint does not exclude a public listener of the same process")
func internalExclusionIsEndpointBound() async {
    let process = ProcessFingerprint(pid: 42, uid: 501, startTime: Date(timeIntervalSince1970: 100))
    let live = LiveDiscovery(.init(process: process, ports: [4173, 4174], internalPorts: [4173]))
    let probe = MockProbe(outcomes: [.success(mockEvidence(port: 4174))])
    let coordinator = LocalStackCoordinator(store: testStore(), discovery: live, inspector: live, probe: probe)
    await coordinator.boot()
    #expect(await probe.callCount == 1)
    #expect((await coordinator.list()).map(\.port) == [4174])
}

private actor GatedDiscoveryProbe: PageProbing {
    var callCount = 0
    private var started: CheckedContinuation<Void, Never>?
    private var pending: [CheckedContinuation<Void, Never>] = []
    private var released = false

    func waitForInitialBatch() async {
        if callCount >= 4 { return }
        await withCheckedContinuation { started = $0 }
    }

    func release() {
        released = true
        pending.forEach { $0.resume() }
        pending.removeAll()
    }

    func probe(_ url: URL) async throws -> PageProbeResult {
        callCount += 1
        if callCount == 4 { started?.resume(); started = nil }
        if !released { await withCheckedContinuation { pending.append($0) } }
        return mockEvidence(port: url.port!)
    }
}

@Test("queued probes revalidate process identity before contacting a reused port")
func queuedProbeRejectsChangedProcess() async {
    let original = ProcessFingerprint(pid: 42, uid: 501, startTime: Date(timeIntervalSince1970: 100))
    let ports: Set<Int> = [4173, 4174, 4175, 4176, 4177]
    let live = LiveDiscovery(.init(process: original, ports: ports, internalPorts: []))
    let probe = GatedDiscoveryProbe()
    let coordinator = LocalStackCoordinator(store: testStore(), discovery: live, inspector: live, probe: probe)
    let boot = Task { await coordinator.boot() }
    await probe.waitForInitialBatch()
    let reused = ProcessFingerprint(pid: 42, uid: 501, startTime: Date(timeIntervalSince1970: 101))
    live.state.withLock { $0 = .init(process: reused, ports: ports, internalPorts: []) }
    await probe.release()
    await boot.value
    #expect(await probe.callCount == 4)
    #expect((await coordinator.list()).isEmpty)
    // Neither queued stale work nor its rejection delays the new process.
    await coordinator.refresh()
    #expect(await probe.callCount == 9)
    #expect((await coordinator.list()).count == 5)
}

@Test("a transient discovered probe failure gets the three-failure grace period")
func discoveredFailureGracePeriod() async throws {
    let process = ProcessFingerprint(pid: 42, uid: 501, startTime: Date(timeIntervalSince1970: 100))
    let candidate = PortCandidate(pid: process.pid, port: 4173, url: URL(string: "http://127.0.0.1:4173/")!)
    let probe = MockProbe(outcomes: [
        .success(mockEvidence()),
        .failure(CoordinatorError(.pageUnavailable, "temporary")),
        .failure(CoordinatorError(.pageUnavailable, "temporary")),
        .failure(CoordinatorError(.pageUnavailable, "temporary"))
    ])
    let coordinator = LocalStackCoordinator(
        store: testStore(),
        discovery: MockDiscovery(candidates: [candidate]),
        inspector: MockInspector(process: process),
        probe: probe
    )

    await coordinator.boot()
    #expect((await coordinator.list()).count == 1)
    await coordinator.refresh()
    #expect((await coordinator.list()).first?.health == .degraded)
    await coordinator.refresh()
    #expect((await coordinator.list()).count == 1)
    await coordinator.refresh()
    #expect((await coordinator.list()).isEmpty)
}

@Test("multiple leases of the same source do not unregister one another")
func duplicateLeasesAreReferenceCounted() async throws {
    let process = ProcessFingerprint(pid: 42, uid: 501, startTime: Date(timeIntervalSince1970: 100))
    let probe = MockProbe(outcomes: [.success(mockEvidence()), .success(mockEvidence())])
    let coordinator = LocalStackCoordinator(
        store: testStore(),
        discovery: MockDiscovery(candidates: []),
        inspector: MockInspector(process: process),
        probe: probe
    )
    await coordinator.boot()
    let request = RegistrationRequest(pid: process.pid, port: 4173)
    let first = try await coordinator.register(request)
    let second = try await coordinator.register(request)
    try await coordinator.unregister(registrationID: first.registrationID, token: first.leaseToken)
    #expect((await coordinator.list()).count == 1)
    try await coordinator.unregister(registrationID: second.registrationID, token: second.leaseToken)
    #expect((await coordinator.list()).isEmpty)
}

@Test("a second IPC server does not replace an active server socket")
func activeSocketIsNotReplaced() async throws {
    let path = "/tmp/ls-\(UUID().uuidString).sock"
    let first = UnixJSONRPCServer(socketPath: path)
    let status = CoordinatorStatus(version: "test", socketPath: path, serviceCount: 0, lastScanAt: nil)
    try first.start { request in .success(id: request.id, value: status) }
    defer { first.stop() }

    let second = UnixJSONRPCServer(socketPath: path)
    do {
        try second.start { request in .success(id: request.id, value: status) }
        Issue.record("second server unexpectedly replaced the active socket")
    } catch let error as POSIXError {
        #expect(error.code == .EADDRINUSE)
    }
    let client = UnixJSONRPCClient(socketPath: path)
    #expect(try await client.status().version == "test")
}

@Test("mutating RPCs cannot race coordinator startup")
func coordinatorRejectsRegistrationBeforeBoot() async {
    let process = ProcessFingerprint(pid: 47, uid: 501, startTime: Date(timeIntervalSince1970: 100))
    let coordinator = LocalStackCoordinator(
        store: testStore(),
        discovery: MockDiscovery(candidates: []),
        inspector: MockInspector(process: process),
        probe: MockProbe(outcomes: [.success(mockEvidence())])
    )
    do {
        _ = try await coordinator.register(RegistrationRequest(pid: process.pid, port: 4173))
        Issue.record("registration unexpectedly succeeded before boot")
    } catch let error as CoordinatorError {
        #expect(error.code == .internalError)
    } catch {
        Issue.record("unexpected error: \(error)")
    }
    #expect((await coordinator.list()).isEmpty)
}

@Test("registration accepts an implicit HTTP port and falls back from an empty name")
func registrationNormalizesDefaultPortAndName() async throws {
    let process = ProcessFingerprint(pid: 45, uid: 501, startTime: Date(timeIntervalSince1970: 100))
    let coordinator = LocalStackCoordinator(
        store: testStore(),
        discovery: MockDiscovery(candidates: []),
        inspector: MockInspector(process: process, listeningPort: 80),
        probe: MockProbe(outcomes: [.success(mockEvidence(port: 80))])
    )
    await coordinator.boot()

    let response = try await coordinator.register(RegistrationRequest(
        pid: process.pid,
        port: 80,
        url: URL(string: "http://127.0.0.1/"),
        displayName: "   "
    ))
    #expect(response.service.displayName == "Demo")
    #expect(response.service.url == URL(string: "http://127.0.0.1:80/")!)
}

@Test("re-registering a service updates its preferred URL")
func registrationUpdatesURL() async throws {
    let process = ProcessFingerprint(pid: 46, uid: 501, startTime: Date(timeIntervalSince1970: 100))
    let coordinator = LocalStackCoordinator(
        store: testStore(),
        discovery: MockDiscovery(candidates: []),
        inspector: MockInspector(process: process),
        probe: MockProbe(outcomes: [.success(mockEvidence(path: "/first")), .success(mockEvidence(path: "/second"))])
    )
    await coordinator.boot()

    let first = try await coordinator.register(RegistrationRequest(pid: process.pid, port: 4173))
    let second = try await coordinator.register(RegistrationRequest(
        pid: process.pid,
        port: 4173,
        url: URL(string: "http://127.0.0.1:4173/second"),
        displayName: "Console"
    ))
    #expect(second.service.id == first.service.id)
    #expect(second.service.url == URL(string: "http://127.0.0.1:4173/second")!)
    #expect((await coordinator.list()).first?.url == second.service.url)
}

@Test("IPC responds to a newline request without waiting for EOF")
func ipcRespondsBeforeClientHalfClose() async throws {
    let path = "/tmp/ls-newline-\(UUID().uuidString).sock"
    let server = UnixJSONRPCServer(socketPath: path)
    defer { server.stop() }
    try server.start { request in
        .success(id: request.id, value: CoordinatorStatus(version: "test", socketPath: path, serviceCount: 0, lastScanAt: nil))
    }

    // Blocking recv on the cooperative executor can prevent the server's async
    // handler from running on low-core CI machines. Keep the client socket open
    // (no half-close), but wait on a Dispatch worker instead.
    let data: Data = try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global().async {
            do { continuation.resume(returning: try receiveResponseBeforeHalfClose(path: path)) }
            catch { continuation.resume(throwing: error) }
        }
    }
    let response = try JSONDecoder.local.decode(RPCResponse.self, from: data)
    #expect(response.id == "test")
    #expect(response.error == nil)
}

private func receiveResponseBeforeHalfClose(path: String) throws -> Data {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { throw POSIXError(.EIO) }
    defer { close(fd) }
    var timeout = timeval(tv_sec: 2, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = Array(path.utf8CString)
    let pathCapacity = MemoryLayout.size(ofValue: address.sun_path)
    withUnsafeMutablePointer(to: &address.sun_path) { pointer in
        pointer.withMemoryRebound(to: CChar.self, capacity: pathCapacity) { destination in
            pathBytes.withUnsafeBufferPointer { source in
                _ = memcpy(destination, source.baseAddress!, source.count)
            }
        }
    }
    let connected = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    guard connected == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    let request = Data("{\"id\":\"test\",\"method\":\"system.status\",\"params\":{}}\n".utf8)
    let sent = request.withUnsafeBytes { buffer in
        send(fd, buffer.baseAddress, buffer.count, 0)
    }
    guard sent == request.count else { throw POSIXError(.EIO) }
    var data = Data()
    var response = [UInt8](repeating: 0, count: 4096)
    while !data.contains(0x0A) {
        let received = recv(fd, &response, response.count, 0)
        if received < 0 && errno == EINTR { continue }
        guard received > 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        data.append(response, count: received)
        guard data.count <= 4096 else { throw POSIXError(.EMSGSIZE) }
    }
    return data
}
