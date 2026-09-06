import Foundation
import LocalStackShared

/// Reuses one short-lived session per coordinator and rejects oversized responses.
/// The caller validates the final URL against its original loopback origin.
final class BoundedHTTPClient: @unchecked Sendable {
    private let session: URLSession
    private let timeout: TimeInterval

    init(timeout: TimeInterval) {
        self.timeout = timeout
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.httpMaximumConnectionsPerHost = 2
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    deinit { session.invalidateAndCancel() }

    func get(_ request: URLRequest, limit: Int) async throws -> (Data, HTTPURLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CoordinatorError(.pageUnavailable, "服务没有返回 HTTP 页面")
        }
        if response.expectedContentLength > Int64(limit) {
            throw CoordinatorError(.pageUnavailable, "页面响应超过 \(limit / 1024) KiB 限制")
        }
        var data = Data()
        data.reserveCapacity(min(limit, max(0, Int(response.expectedContentLength))))
        for try await byte in bytes {
            guard data.count < limit else {
                throw CoordinatorError(.pageUnavailable, "页面响应超过 \(limit / 1024) KiB 限制")
            }
            data.append(byte)
        }
        return (data, http)
    }
}
