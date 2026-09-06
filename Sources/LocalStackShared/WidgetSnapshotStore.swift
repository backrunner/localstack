import Foundation

public struct WidgetSnapshotStore: Sendable {
    private let fileURL: URL

    public init(fileURL: URL = WidgetSnapshotStore.defaultURL()) {
        self.fileURL = fileURL
    }

    public static func defaultURL() -> URL {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.localstack") {
            return groupURL.appendingPathComponent("service-snapshot.json")
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.com.localstack", isDirectory: true)
            .appendingPathComponent("service-snapshot.json")
    }

    public func save(_ snapshot: ServiceWidgetSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.local.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    public func load() -> ServiceWidgetSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder.local.decode(ServiceWidgetSnapshot.self, from: data)
    }
}
