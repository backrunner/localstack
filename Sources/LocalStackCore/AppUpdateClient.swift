import Foundation

/// Release metadata is untrusted input. The downloaded image and app must still
/// pass Developer ID, notarization, identity, and signed-version verification.
public actor AppUpdateClient {
    private let session: URLSession
    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        session = URLSession(configuration: configuration)
    }

    public func check(current: AppReleaseVersion, channel: AppUpdateChannel, team: String) async throws -> AppUpdateOffer? {
        var releases: [GitHubAppRelease] = []
        var complete = false
        // Bound public API usage. Refuse a truncated catalog rather than silently
        // choosing by GitHub's creation dates, which do not reflect version order.
        for page in 1...5 {
            try Task.checkCancellation()
            let url = URL(string: "https://api.github.com/repos/backrunner/localstack/releases?per_page=100&page=\(page)")!
            let data = try await fetch(url, limit: 8 * 1024 * 1024)
            let batch = try JSONDecoder().decode([GitHubAppRelease].self, from: data)
            releases += batch
            if batch.count < 100 { complete = true; break }
        }
        guard complete else { throw AppUpdateError.unavailable }
        let candidates = GitHubAppRelease.candidates(releases, newerThan: current, channel: channel)
        for release in candidates {
            try Task.checkCancellation()
            let version = release.releaseVersion!
            let descriptor = release.asset(named: "LocalStack-update.json")!
            let image = release.asset(named: "LocalStack-\(version).dmg")!
            guard descriptor.size > 0, descriptor.size <= 64 * 1024 else { throw AppUpdateError.invalidRelease }
            let manifest = try JSONDecoder().decode(AppUpdateManifest.self, from: await fetch(descriptor.browserDownloadURL, limit: 64 * 1024))
            try manifest.validate(version: version, team: team, size: image.size)
            guard let minimum = AppUpdateManifest.systemVersion(manifest.minimumSystemVersion) else { throw AppUpdateError.invalidRelease }
            if ProcessInfo.processInfo.isOperatingSystemAtLeast(minimum) {
                return AppUpdateOffer(manifest: manifest, downloadURL: image.browserDownloadURL)
            }
        }
        if !candidates.isEmpty { throw AppUpdateError.incompatibleSystem }
        return nil
    }

    public func download(_ offer: AppUpdateOffer, to destination: URL) async throws {
        let (bytes, response) = try await session.bytes(for: request(offer.downloadURL))
        try validate(response)
        if response.expectedContentLength > offer.manifest.size { throw AppUpdateError.invalidRelease }
        guard FileManager.default.createFile(atPath: destination.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { throw AppUpdateError.unavailable }
        let file = try FileHandle(forWritingTo: destination)
        defer { try? file.close() }
        var buffer = Data()
        var count: Int64 = 0
        for try await byte in bytes {
            count += 1
            guard count <= offer.manifest.size else { throw AppUpdateError.invalidRelease }
            buffer.append(byte)
            if buffer.count == 64 * 1024 {
                try Task.checkCancellation()
                try file.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
            }
        }
        try file.write(contentsOf: buffer)
        guard count == offer.manifest.size else { throw AppUpdateError.checksumMismatch }
    }

    private func fetch(_ url: URL, limit: Int) async throws -> Data {
        let (bytes, response) = try await session.bytes(for: request(url))
        try validate(response)
        guard response.expectedContentLength <= limit else { throw AppUpdateError.invalidRelease }
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw AppUpdateError.invalidRelease }
            data.append(byte)
        }
        return data
    }

    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("LocalStack-Updater", forHTTPHeaderField: "User-Agent")
        if url.host == "api.github.com" {
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        }
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, let url = http.url,
              url.scheme == "https", ["api.github.com", "github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"].contains(url.host ?? "") else { throw AppUpdateError.unavailable }
        if http.statusCode == 403 || http.statusCode == 429 { throw AppUpdateError.rateLimited }
        guard http.statusCode == 200 else { throw AppUpdateError.unavailable }
    }
}
