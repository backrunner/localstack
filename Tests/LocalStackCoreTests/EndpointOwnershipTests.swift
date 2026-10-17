import Darwin
import Foundation
import Testing
import LocalStackShared
@testable import LocalStackCore

private struct NoEndpointDiscovery: PortDiscovering {
    func listenCandidates() -> [PortCandidate] { [] }
}

private actor EndpointEchoProbe: PageProbing {
    var requests: [URL] = []
    func probe(_ url: URL) async throws -> PageProbeResult {
        requests.append(url)
        return PageProbeResult(evidence: ValidationEvidence(checkedURL: url, finalURL: url,
            statusCode: 200, contentType: "text/html", title: "Owned endpoint"))
    }
}

private final class IPv6EndpointFixture {
    let fd: Int32
    let port: Int

    init(wildcard: Bool = false, v6Only: Bool = true) throws {
        let descriptor = socket(AF_INET6, SOCK_STREAM, 0)
        fd = descriptor
        try #require(descriptor >= 0)
        var ready = false
        defer { if !ready { close(descriptor) } }
        var only: Int32 = v6Only ? 1 : 0
        try #require(setsockopt(descriptor, IPPROTO_IPV6, IPV6_V6ONLY, &only, socklen_t(MemoryLayout<Int32>.size)) == 0)
        var address = sockaddr_in6()
        address.sin6_family = sa_family_t(AF_INET6)
        _ = (wildcard ? "::" : "::1").withCString { inet_pton(AF_INET6, $0, &address.sin6_addr) }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in6>.size)) }
        }
        try #require(bound == 0 && listen(descriptor, 1) == 0)
        var size = socklen_t(MemoryLayout<sockaddr_in6>.size)
        let named = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &size) }
        }
        try #require(named == 0)
        port = Int(UInt16(bigEndian: address.sin6_port))
        ready = true
    }

    deinit { close(fd) }
}

@Test("registration rejects a URL owned by the other address family before probing")
func nativeRegistrationRejectsWrongFamily() async throws {
    let fixture = try IPv6EndpointFixture()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let probe = EndpointEchoProbe()
    let coordinator = LocalStackCoordinator(store: RegistryStore(fileURL: directory.appendingPathComponent("services.json")),
        discovery: NoEndpointDiscovery(), inspector: ProcessInspector(), probe: probe)
    await coordinator.boot()
    do {
        _ = try await coordinator.register(RegistrationRequest(pid: getpid(), port: fixture.port,
            url: URL(string: "http://127.0.0.1:\(fixture.port)/")))
        Issue.record("an IPv6-only listener was accepted as the owner of an IPv4 URL")
    } catch let error as CoordinatorError { #expect(error.code == .portUnavailable) }
    #expect(await probe.requests.isEmpty)
}

@Test("native localhost resolution preserves paths and supports IPv6-only and dual-stack binds", arguments: [false, true])
func nativeLocalhostResolvesOwnedFamily(dualStack: Bool) async throws {
    let fixture = try IPv6EndpointFixture(wildcard: dualStack, v6Only: !dualStack)
    let inspector = ProcessInspector()
    let url = URL(string: "http://localhost:\(fixture.port)/dashboard?preview=1#top")!
    let resolved = try #require(inspector.ownedLoopbackURL(url, pid: getpid()))
    #expect(resolved.host?.trimmingCharacters(in: CharacterSet(charactersIn: "[]")) == (dualStack ? "127.0.0.1" : "::1"))
    #expect(resolved.path == "/dashboard")
    #expect(resolved.query == "preview=1")
    #expect(resolved.fragment == "top")
    #expect(inspector.ownedLoopbackURL(URL(string: "http://[::1]:\(fixture.port)/")!, pid: getpid()) != nil)
    #expect((inspector.ownedLoopbackURL(URL(string: "http://127.0.0.1:\(fixture.port)/")!, pid: getpid()) != nil) == dualStack)
}

private struct EndpointCandidates: PortDiscovering {
    let candidates: [PortCandidate]
    func listenCandidates() -> [PortCandidate] { candidates }
}

private final class EndpointHTTPFixture {
    let process = Process()
    let url: URL

    init(host: String, port: Int = 0) throws {
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-u", "-c", """
            import socket, sys
            from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
            host, port = sys.argv[1], int(sys.argv[2])
            class Handler(BaseHTTPRequestHandler):
                def do_GET(self):
                    body = ('<html><title>Owned ' + host + '</title></html>').encode()
                    self.send_response(200)
                    self.send_header('Content-Type', 'text/html')
                    self.send_header('Content-Length', str(len(body)))
                    self.end_headers(); self.wfile.write(body)
                def log_message(self, *args): pass
            class Server(ThreadingHTTPServer):
                address_family = socket.AF_INET6 if ':' in host else socket.AF_INET
                def server_bind(self):
                    if self.address_family == socket.AF_INET6:
                        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
                    super().server_bind()
            server = Server((host, port), Handler)
            print(server.server_port, flush=True)
            server.serve_forever()
            """, host, String(port)]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let value = String(decoding: output.fileHandleForReading.availableData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let actualPort = try #require(Int(value))
        url = URL(string: "http://\(host.contains(":") ? "[\(host)]" : host):\(actualPort)/")!
    }

    func stop() {
        let pid = process.processIdentifier
        var status: Int32 = 0
        guard waitpid(pid, &status, WNOHANG) == 0 else { return }
        kill(pid, SIGTERM)
        let deadline = ContinuousClock.now + .seconds(2)
        while ContinuousClock.now < deadline {
            if waitpid(pid, &status, WNOHANG) != 0 { return }
            usleep(10_000)
        }
        kill(pid, SIGKILL)
        _ = waitpid(pid, &status, 0)
    }
}

@Test("real IPv4 and IPv6 processes sharing a port stay distinct and stopping one preserves the other")
func independentAddressFamiliesSharePort() async throws {
    let ipv4 = try EndpointHTTPFixture(host: "127.0.0.1")
    defer { ipv4.stop() }
    let port = try #require(ipv4.url.port)
    let ipv6 = try EndpointHTTPFixture(host: "::1", port: port)
    defer { ipv6.stop() }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let coordinator = LocalStackCoordinator(store: RegistryStore(fileURL: directory.appendingPathComponent("services.json")),
        discovery: EndpointCandidates(candidates: [
            PortCandidate(pid: ipv4.process.processIdentifier, port: port, url: ipv4.url),
            PortCandidate(pid: ipv6.process.processIdentifier, port: port, url: ipv6.url)
        ]))
    await coordinator.boot()
    let services = await coordinator.list()
    #expect(services.count == 2)
    let v4 = try #require(services.first { $0.process.pid == ipv4.process.processIdentifier })
    let v6 = try #require(services.first { $0.process.pid == ipv6.process.processIdentifier })
    let socketPath = directory.appendingPathComponent("rpc.sock").path
    let server = UnixJSONRPCServer(socketPath: socketPath)
    let rpc = CoordinatorRPCService(coordinator: coordinator, socketPath: socketPath)
    try server.start { request in await rpc.handle(request) }
    defer { server.stop() }
    let client = UnixJSONRPCClient(socketPath: socketPath)
    #expect(try await client.list().count == 2)
    #expect(v4.endpointKey != v6.endpointKey)
    #expect(try await client.openTarget(serviceID: v4.id) == ipv4.url)
    #expect(try await client.openTarget(serviceID: v6.id) == ipv6.url)
    do {
        _ = try await coordinator.register(RegistrationRequest(pid: ipv6.process.processIdentifier, port: port, url: ipv4.url))
        Issue.record("the IPv6 process claimed the IPv4 process's HTTP page")
    } catch let error as CoordinatorError { #expect(error.code == .portUnavailable) }
    let registered = try await coordinator.register(RegistrationRequest(pid: ipv6.process.processIdentifier, port: port,
        url: URL(string: "http://localhost:\(port)/")))
    #expect(registered.service.id == v6.id)
    #expect(registered.service.url == ipv6.url)
    let preview = try await client.prepareTermination(serviceID: v4.id)
    let result = try await client.terminate(serviceID: v4.id, token: preview.token, force: false)
    #expect(result.listenersClosed == true)
    try await client.refresh()
    #expect(try await client.list().map(\.id) == [v6.id])
    #expect(try await client.openTarget(serviceID: v6.id) == ipv6.url)
}
