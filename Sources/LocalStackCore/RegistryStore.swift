import Foundation
import LocalStackShared

public actor RegistryStore {
    private struct PersistedRegistry: Codable {
        let schemaVersion: Int
        let records: [ServiceRecord]
    }

    private let fileURL: URL

    public init(fileURL: URL = RegistryStore.defaultURL()) {
        self.fileURL = fileURL
    }

    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("LocalStack", isDirectory: true).appendingPathComponent("services.json")
    }

    public func load() -> [ServiceRecord] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        if let registry = try? JSONDecoder.local.decode(PersistedRegistry.self, from: data), registry.schemaVersion == 1 {
            return registry.records
        }
        return (try? JSONDecoder.local.decode([ServiceRecord].self, from: data)) ?? []
    }

    public func save(_ records: [ServiceRecord]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if directory.lastPathComponent == "LocalStack" {
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }
        let data = try JSONEncoder.local.encode(PersistedRegistry(schemaVersion: 1, records: records))
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
