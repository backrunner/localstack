import Foundation
import LocalStackShared

/// Multiple selected ports can belong to one process. Prepare one identity-bound
/// confirmation per process and run independent stops without serial timeouts.
public enum ServiceTerminationBatch {
    public struct Outcome: Sendable {
        public let forcePreviews: [TerminationPreview]
        public let failures: [String]
    }

    public static func prepare(
        services: [ServiceRecord],
        operation: @Sendable (UUID) async throws -> TerminationPreview
    ) async throws -> [TerminationPreview] {
        var processes = Set<ProcessFingerprint>()
        var previews: [TerminationPreview] = []
        for service in services where processes.insert(service.process).inserted {
            previews.append(try await operation(service.id))
        }
        return previews
    }

    public static func stop(
        previews: [TerminationPreview],
        operation: @escaping @Sendable (TerminationPreview) async throws -> TerminationPreview?
    ) async -> Outcome {
        await withTaskGroup(of: (Int, TerminationPreview?, String?).self) { group in
            for (index, preview) in previews.enumerated() {
                group.addTask {
                    do { return (index, try await operation(preview), nil) }
                    catch { return (index, nil, "\(preview.displayName)：\(error.localizedDescription)") }
                }
            }
            var results: [(Int, TerminationPreview?, String?)] = []
            for await result in group { results.append(result) }
            results.sort { $0.0 < $1.0 }
            return Outcome(forcePreviews: results.compactMap { $0.1 }, failures: results.compactMap { $0.2 })
        }
    }
}
