import Foundation

/// Public release ordering is independent of CI run/build numbers.
public struct AppReleaseVersion: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let beta: Int?

    public init?(_ value: String) {
        let parts = value.components(separatedBy: "-beta.")
        guard parts.count <= 2 else { return nil }
        let core = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        func number(_ text: String) -> Int? {
            guard !text.isEmpty, text.utf8.allSatisfy({ (48...57).contains($0) }),
                  text == "0" || !text.hasPrefix("0") else { return nil }
            return Int(text)
        }
        guard core.count == 3, let major = number(String(core[0])),
              let minor = number(String(core[1])), let patch = number(String(core[2])) else { return nil }
        var beta: Int?
        if parts.count == 2 {
            guard let value = number(parts[1]), value > 0 else { return nil }
            beta = value
        }
        self.major = major; self.minor = minor; self.patch = patch; self.beta = beta
    }

    public var description: String {
        "\(major).\(minor).\(patch)" + (beta.map { "-beta.\($0)" } ?? "")
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        switch (lhs.beta, rhs.beta) {
        case let (a?, b?): return a < b
        case (_?, nil): return true
        default: return false
        }
    }
}

public enum AppUpdateChannel: String, CaseIterable, Codable, Sendable {
    case stable, beta

    public func accepts(_ version: AppReleaseVersion) -> Bool {
        self == .beta || version.beta == nil
    }
}

public struct AppUpdateManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let version: String
    public let channel: AppUpdateChannel
    public let buildNumber: String
    public let bundleIdentifier: String
    public let teamIdentifier: String
    public let minimumSystemVersion: String
    public let fileName: String
    public let size: Int64
    public let sha256: String

    public func validate(version expected: AppReleaseVersion, team: String, size expectedSize: Int64) throws {
        guard schemaVersion == 1, version == expected.description,
              channel == (expected.beta == nil ? .stable : .beta),
              bundleIdentifier == "com.localstack.app", teamIdentifier == team,
              fileName == "LocalStack-\(version).dmg", size == expectedSize,
              size > 0, size <= 512 * 1024 * 1024,
              sha256.count == 64, sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              !buildNumber.isEmpty,
              Self.systemVersion(minimumSystemVersion) != nil else {
            throw AppUpdateError.invalidRelease
        }
    }

    public static func systemVersion(_ value: String) -> OperatingSystemVersion? {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }) else { return nil }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == parts.count else { return nil }
        return OperatingSystemVersion(majorVersion: numbers[0], minorVersion: numbers.count > 1 ? numbers[1] : 0,
                                      patchVersion: numbers.count > 2 ? numbers[2] : 0)
    }
}

public struct GitHubAppRelease: Decodable, Sendable {
    public struct Asset: Decodable, Sendable {
        public let name: String
        public let size: Int64
        public let state: String
        public let browserDownloadURL: URL
        enum CodingKeys: String, CodingKey {
            case name, size, state
            case browserDownloadURL = "browser_download_url"
        }
    }
    public let tagName: String
    public let draft: Bool
    public let prerelease: Bool
    public let assets: [Asset]
    enum CodingKeys: String, CodingKey {
        case draft, prerelease, assets
        case tagName = "tag_name"
    }

    public var releaseVersion: AppReleaseVersion? {
        guard tagName.hasPrefix("v"), let version = AppReleaseVersion(String(tagName.dropFirst())),
              prerelease == (version.beta != nil), !draft else { return nil }
        return version
    }

    public func asset(named name: String) -> Asset? {
        let matches = assets.filter { $0.name == name && $0.state == "uploaded" }
        guard matches.count == 1, let asset = matches.first,
              asset.browserDownloadURL.absoluteString == "https://github.com/backrunner/localstack/releases/download/\(tagName)/\(name)" else { return nil }
        return asset
    }

    public static func candidates(_ releases: [Self], newerThan current: AppReleaseVersion, channel: AppUpdateChannel) -> [Self] {
        releases.filter {
            guard let version = $0.releaseVersion else { return false }
            return version > current && channel.accepts(version)
                && $0.asset(named: "LocalStack-update.json") != nil
                && $0.asset(named: "LocalStack-\(version).dmg") != nil
        }.sorted { $0.releaseVersion! > $1.releaseVersion! }
    }
}

public struct AppUpdateOffer: Sendable {
    public let manifest: AppUpdateManifest
    public let downloadURL: URL
    public init(manifest: AppUpdateManifest, downloadURL: URL) {
        self.manifest = manifest; self.downloadURL = downloadURL
    }
    public var version: AppReleaseVersion { AppReleaseVersion(manifest.version)! }
    public var releaseURL: URL { URL(string: "https://github.com/backrunner/localstack/releases/tag/v\(manifest.version)")! }
}

public enum AppUpdateError: LocalizedError {
    case invalidRelease, unavailable, rateLimited, incompatibleSystem, invalidSignature, checksumMismatch, notInstalled, installationFailed
    public var errorDescription: String? {
        switch self {
        case .invalidRelease: "更新信息不完整或不匹配，请稍后重试。"
        case .unavailable: "暂时无法检查更新，请检查网络连接后重试。"
        case .rateLimited: "更新检查暂时受到服务器限制，请稍后重试。"
        case .incompatibleSystem: "新版本需要更新的 macOS。"
        case .invalidSignature: "更新包的签名或公证验证失败，请重新下载。"
        case .checksumMismatch: "更新包下载不完整，请重新下载。"
        case .notInstalled: "请先将 LocalStack 安装到应用程序文件夹。"
        case .installationFailed: "更新安装未完成，请重试或手动安装。"
        }
    }
}
