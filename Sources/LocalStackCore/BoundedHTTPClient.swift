import Foundation
import LocalStackShared
import Synchronization

/// Reuses a coordinator session while explicitly cancelling abandoned bodies.
/// Redirects are validated before following, and abandoned bodies are cancelled.
final class BoundedHTTPClient: @unchecked Sendable {
    private let session: URLSession

    init(timeout: TimeInterval) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        // Discovery must connect directly to the local listener, regardless of
        // system proxy/PAC settings.
        configuration.connectionProxyDictionary = [:]
        configuration.urlCache = nil
        configuration.httpMaximumConnectionsPerHost = 2
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    deinit { session.invalidateAndCancel() }

    func get(_ request: URLRequest, limit: Int) async throws -> (Data, HTTPURLResponse) {
        let delegate = ProbeTaskDelegate(origin: request.url)
        let (bytes, response) = try await session.bytes(for: request, delegate: delegate)
        defer { bytes.task.cancel() }
        if let error = delegate.redirectError { throw error }
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

private final class ProbeTaskDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private let origin: URL?
    private let state = Mutex<(redirects: Int, error: CoordinatorError?)>((0, nil))

    init(origin: URL?) { self.origin = origin }

    var redirectError: CoordinatorError? { state.withLock { $0.error } }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        let allowed = state.withLock { state -> Bool in
            guard let origin, let target = request.url,
                  target.scheme?.lowercased() == "http",
                  target.host?.lowercased() == origin.host?.lowercased(),
                  (target.port ?? 80) == (origin.port ?? 80),
                  target.user == nil, target.password == nil else {
                state.error = CoordinatorError(.outsideLoopback, "页面重定向到了其他地址")
                return false
            }
            guard state.redirects < 3 else {
                state.error = CoordinatorError(.pageUnavailable, "页面重定向超过 3 次限制")
                return false
            }
            state.redirects += 1
            return true
        }
        completionHandler(allowed ? request : nil)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // A discovery request must never prompt or reuse the user's credentials.
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
