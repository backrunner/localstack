import Foundation
import LocalStackShared

public struct PortCandidate: Hashable, Sendable {
    public let pid: Int32
    public let port: Int
    public let url: URL

    public init(pid: Int32, port: Int, url: URL) {
        self.pid = pid
        self.port = port
        self.url = url
    }
}

public struct PortDiscovery: PortDiscovering {
    private let inspector: any ProcessInspecting

    public init(inspector: any ProcessInspecting = ProcessInspector()) {
        self.inspector = inspector
    }

    public func listenCandidates() -> [PortCandidate] {
        var candidates = Set<PortCandidate>()
        for pid in ProcessSockets.currentUserPIDs() {
            guard let fingerprint = inspector.fingerprint(for: pid), fingerprint.uid == inspector.currentUID else { continue }
            for socket in ProcessSockets.listeners(pid: pid) {
                guard let url = socket.loopbackURL else { continue }
                candidates.insert(PortCandidate(pid: pid, port: socket.port, url: url))
            }
        }
        return candidates.sorted { $0.port < $1.port }
    }
}
