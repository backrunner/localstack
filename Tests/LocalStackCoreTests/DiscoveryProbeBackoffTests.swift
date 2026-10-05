import Foundation
import Testing
import LocalStackShared
@testable import LocalStackCore

@Test("discovery retry expires after a minute and does not survive PID reuse or listener removal")
func discoveryRetryBoundaries() {
    let candidate = PortCandidate(pid: 42, port: 3000, url: URL(string: "http://127.0.0.1:3000/")!)
    let target = DiscoveryProbeBackoff.Target(candidate: candidate,
        process: ProcessFingerprint(pid: 42, uid: 501, startTime: Date(timeIntervalSince1970: 100)))
    let reused = DiscoveryProbeBackoff.Target(candidate: candidate,
        process: ProcessFingerprint(pid: 42, uid: 501, startTime: Date(timeIntervalSince1970: 101)))
    let start = ContinuousClock.now
    var policy = DiscoveryProbeBackoff()
    policy.reject(target, at: start)
    #expect(!policy.allows(target, at: start + .seconds(59)))
    #expect(policy.allows(target, at: start + .seconds(60)))
    #expect(policy.allows(reused, at: start))
    policy.retain([], at: start)
    #expect(policy.allows(target, at: start))
}
