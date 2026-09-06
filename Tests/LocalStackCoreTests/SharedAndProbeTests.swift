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

    init(outcomes: [Outcome]) { self.outcomes = outcomes }

    func probe(_ url: URL) async throws -> PageProbeResult {
        guard !outcomes.isEmpty else { throw CoordinatorError(.pageUnavailable, "no mock result") }
        switch outcomes.removeFirst() {
        case .success(let result): return result
        case .failure(let error): throw error
        }
    }
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
func ipcRespondsBeforeClientHalfClose() throws {
    let path = "/tmp/ls-newline-\(UUID().uuidString).sock"
    let server = UnixJSONRPCServer(socketPath: path)
    defer { server.stop() }
    try server.start { request in
        .success(id: request.id, value: CoordinatorStatus(version: "test", socketPath: path, serviceCount: 0, lastScanAt: nil))
    }

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    #expect(fd >= 0)
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
    #expect(connected == 0)
    let request = Data("{\"id\":\"test\",\"method\":\"system.status\",\"params\":{}}\n".utf8)
    let sent = request.withUnsafeBytes { buffer in
        send(fd, buffer.baseAddress, buffer.count, 0)
    }
    #expect(sent == request.count)
    var response = [UInt8](repeating: 0, count: 4096)
    let received = recv(fd, &response, response.count, 0)
    #expect(received > 0)
}
