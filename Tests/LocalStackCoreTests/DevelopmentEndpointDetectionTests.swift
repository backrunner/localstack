import Foundation
import Testing
@testable import LocalStackCore

private let miniflareArguments = [
    "workerd", "serve", "--binary", "--experimental", "--socket-addr=entry=127.0.0.1:0",
    "--external-addr=loopback=127.0.0.1:62839", "--control-fd=3", "-", "--debug-port=127.0.0.1:0"
]

private func detected(_ port: Int = 3000, executable: String = "workerd", arguments: [String] = miniflareArguments,
                      ports: [Int] = [3000, 3001]) -> Bool {
    let candidate = PortCandidate(pid: 42, port: port, url: URL(string: "http://127.0.0.1:\(port)/")!)
    return DevelopmentEndpointDetection.isInternal(executable: executable, arguments: arguments, candidate: candidate,
        listeners: ports.map { ProcessSockets.Listener(port: $0, loopbackURL: URL(string: "http://127.0.0.1:\($0)/")!) })
}

@Test("Miniflare detection requires launch and actual endpoint evidence")
func developmentEndpointEvidence() {
    #expect(detected())
    #expect(detected(3001))
    #expect(!detected(3002))
    #expect(!detected(executable: "node"))
    #expect(!detected(executable: "未知进程"))
    #expect(!detected(arguments: []))
    #expect(!detected(arguments: ["workerd", "serve", "site.capnp"]))
    #expect(!detected(arguments: ["workerd", "serve", "--external-addr=loopback=127.0.0.1:62839"]))
    for flag in ["--binary", "--control-fd=3", "-", "--socket-addr=entry=127.0.0.1:0"] {
        #expect(!detected(arguments: miniflareArguments.filter { $0 != flag }))
    }
    // Unaccounted listeners or a public ephemeral socket make the mapping ambiguous.
    #expect(!detected(ports: [3000, 3001, 3002]))
    #expect(!detected(arguments: miniflareArguments + ["--socket-addr=public=127.0.0.1:0"]))
    #expect(!detected(arguments: miniflareArguments + ["--socket-addr=entry=127.0.0.1:0"]))
    #expect(!detected(arguments: miniflareArguments + ["--inspector-addr=invalid"]))
}

@Test("fixed internal sockets do not exclude the process's public sockets")
func publicSocketRemainsEligible() {
    let flags = miniflareArguments.map { $0 == "--socket-addr=entry=127.0.0.1:0" ? "--socket-addr=entry=127.0.0.1:3000" : $0 }
        + ["--socket-addr=public=127.0.0.1:3002"]
    #expect(detected(arguments: flags, ports: [3000, 3001, 3002]))
    #expect(!detected(3002, arguments: flags, ports: [3000, 3001, 3002]))
    #expect(!detected(3001, arguments: flags, ports: [3000, 3001, 3002]))
    let inspector = miniflareArguments + ["--inspector-addr=127.0.0.1:0"]
    #expect(detected(3002, arguments: inspector, ports: [3000, 3001, 3002]))
}

@Test("IPv6 internal binds require matching live IPv6 listeners")
func ipv6EndpointEvidence() {
    let flags = miniflareArguments.map { $0.replacingOccurrences(of: "127.0.0.1", with: "[::1]") }
    let candidate = PortCandidate(pid: 42, port: 3000, url: URL(string: "http://[::1]:3000/")!)
    let listeners = [3000, 3001].map { ProcessSockets.Listener(port: $0, loopbackURL: URL(string: "http://[::1]:\($0)/")!) }
    #expect(DevelopmentEndpointDetection.isInternal(executable: "workerd", arguments: flags, candidate: candidate, listeners: listeners))
    #expect(!DevelopmentEndpointDetection.isInternal(executable: "workerd", arguments: miniflareArguments, candidate: candidate, listeners: listeners))
}
