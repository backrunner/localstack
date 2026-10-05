import Foundation
import LocalStackShared

/// Only automatic discovery is throttled; explicit registration/open still
/// validates immediately. A new process fingerprint never inherits a rejection.
struct DiscoveryProbeBackoff {
    struct Target: Hashable {
        let candidate: PortCandidate
        let process: ProcessFingerprint
    }

    private var rejectedUntil: [Target: ContinuousClock.Instant] = [:]
    private let retryDelay: Duration = .seconds(60)

    func allows(_ target: Target, at now: ContinuousClock.Instant = .now) -> Bool {
        rejectedUntil[target].map { $0 <= now } ?? true
    }

    mutating func reject(_ target: Target, at now: ContinuousClock.Instant = .now) {
        rejectedUntil[target] = now + retryDelay
    }

    mutating func accept(_ target: Target) {
        rejectedUntil.removeValue(forKey: target)
    }

    mutating func retain(_ targets: Set<Target>, at now: ContinuousClock.Instant = .now) {
        rejectedUntil = rejectedUntil.filter { targets.contains($0.key) && $0.value > now }
    }
}
