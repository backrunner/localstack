import Testing
import Darwin
import Foundation
import LocalStackShared
@testable import LocalStackCore

@Test("native discovery includes a real listener but not an unbound TCP socket")
func nativeSocketDiscoveryFindsListener() throws {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    let idle = socket(AF_INET, SOCK_STREAM, 0)
    defer { close(fd); close(idle) }
    try #require(fd >= 0 && idle >= 0)
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_addr.s_addr = inet_addr("127.0.0.1")
    let bound = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
    }
    try #require(bound == 0 && listen(fd, 1) == 0)
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let named = withUnsafeMutablePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
    }
    try #require(named == 0)
    let port = Int(UInt16(bigEndian: address.sin_port))
    let listeners = ProcessSockets.listeners(pid: getpid())
    #expect(listeners.contains { $0.port == port && $0.loopbackURL?.host == "127.0.0.1" })
    #expect(!listeners.contains { $0.port == 0 })
    #expect(PortDiscovery().listenCandidates().contains { $0.pid == getpid() && $0.port == port })
    let inspector = ProcessInspector()
    let process = try #require(inspector.fingerprint(for: getpid()))
    let candidate = PortCandidate(pid: getpid(), port: port, url: URL(string: "http://127.0.0.1:\(port)/")!)
    #expect(!inspector.isInternalDevelopmentEndpoint(candidate, process: process))
    let stale = ProcessFingerprint(pid: process.pid, uid: process.uid, startTime: process.startTime.addingTimeInterval(1))
    #expect(!inspector.isInternalDevelopmentEndpoint(candidate, process: stale))
}

@Test("native argument parsing reads argv only and rejects malformed buffers")
func nativeArgumentParsingIsBounded() throws {
    var argc: Int32 = 3
    var bytes = withUnsafeBytes(of: &argc) { Array($0) }
    bytes += Array("/bin/workerd\0\0workerd\0serve\0\0SECRET_ENV=value\0".utf8)
    #expect(ProcessInspector.decodeArguments(bytes) == ["workerd", "serve", ""])
    #expect(ProcessInspector.decodeArguments([]) == nil)
    #expect(ProcessInspector.decodeArguments(Array(bytes.prefix(8))) == nil)
    let arguments = try #require(ProcessInspector.arguments(for: getpid()))
    #expect(arguments == ProcessInfo.processInfo.arguments)
}
