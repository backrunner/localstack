import Foundation

/// Stages a complete bundle beside its destination before replacing an existing install.
/// A failed copy or commit leaves the previous version available.
public enum AppBundleInstallation {
    public static func install(source: URL, destination: URL, bundleIdentifier: String,
                               copy: (URL, URL) throws -> Void = { try FileManager.default.copyItem(at: $0, to: $1) }) throws {
        let fm = FileManager.default
        let parent = destination.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        guard identifier(at: source) == bundleIdentifier else { throw InstallationError.invalidSource }
        if fm.fileExists(atPath: destination.path), identifier(at: destination) != bundleIdentifier {
            throw InstallationError.unrelatedDestination
        }
        let stage = parent.appendingPathComponent(".LocalStack-stage-\(UUID().uuidString).app")
        let backup = parent.appendingPathComponent(".LocalStack-backup-\(UUID().uuidString).app")
        defer { try? fm.removeItem(at: stage) }
        try copy(source, stage)
        guard identifier(at: stage) == bundleIdentifier else { throw InstallationError.invalidSource }
        let replacing = fm.fileExists(atPath: destination.path)
        if replacing { try fm.moveItem(at: destination, to: backup) }
        do {
            try fm.moveItem(at: stage, to: destination)
        } catch {
            if replacing { try fm.moveItem(at: backup, to: destination) }
            throw error
        }
        if replacing { try? fm.removeItem(at: backup) }
    }

    private static func identifier(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url.appendingPathComponent("Contents/Info.plist")),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        return plist["CFBundleIdentifier"] as? String
    }

    public enum InstallationError: LocalizedError {
        case invalidSource, unrelatedDestination
        public var errorDescription: String? {
            switch self {
            case .invalidSource: "应用程序不完整，无法安装。请重新下载。"
            case .unrelatedDestination: "目标位置存在另一个同名应用，LocalStack 不会覆盖它。请先在 Finder 中检查。"
            }
        }
    }
}
