import Foundation
import LocalStackShared

public protocol ProcessInspecting: Sendable {
    var currentUID: UInt32 { get }
    func fingerprint(for pid: Int32) -> ProcessFingerprint?
    func ownsPort(_ port: Int, pid: Int32) -> Bool
    func ownedLoopbackURL(_ url: URL, pid: Int32) -> URL?
    func listeningPorts(for pid: Int32) -> Set<Int>
    func executableName(for pid: Int32) -> String
    func isInternalDevelopmentEndpoint(_ candidate: PortCandidate, process: ProcessFingerprint) -> Bool
    func terminate(_ fingerprint: ProcessFingerprint, force: Bool) -> Bool
}

public extension ProcessInspecting {
    func ownedLoopbackURL(_ url: URL, pid: Int32) -> URL? {
        ownsPort(url.port ?? 80, pid: pid) ? url : nil
    }
    func listeningPorts(for pid: Int32) -> Set<Int> { [] }
    func isInternalDevelopmentEndpoint(_ candidate: PortCandidate, process: ProcessFingerprint) -> Bool { false }
}

public protocol PortDiscovering: Sendable {
    func listenCandidates() -> [PortCandidate]
}

public protocol PageProbing: Sendable {
    func probe(_ url: URL) async throws -> PageProbeResult
}
