import Foundation
import LocalStackShared

public struct PageProbeResult: Sendable {
    public let evidence: ValidationEvidence

    public init(evidence: ValidationEvidence) {
        self.evidence = evidence
    }
}

public struct PageProbe: PageProbing {
    private let timeout: TimeInterval
    private let maximumResponseBytes: Int
    private let client: BoundedHTTPClient

    public init(timeout: TimeInterval = 2.5, maximumResponseBytes: Int = 512 * 1024) {
        self.timeout = timeout
        self.maximumResponseBytes = max(1, maximumResponseBytes)
        self.client = BoundedHTTPClient(timeout: timeout)
    }

    public func probe(_ url: URL) async throws -> PageProbeResult {
        guard isLoopback(url), url.scheme?.lowercased() == "http", url.user == nil, url.password == nil else {
            throw CoordinatorError(.outsideLoopback, "只允许访问 localhost loopback 页面")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("LocalStack/1.0", forHTTPHeaderField: "User-Agent")

        let data: Data
        let http: HTTPURLResponse
        do {
            (data, http) = try await client.get(request, limit: maximumResponseBytes)
        } catch let error as CoordinatorError {
            throw error
        } catch {
            throw CoordinatorError(.pageUnavailable, "页面不可访问：\(error.localizedDescription)")
        }
        let response = http
        guard (200..<300).contains(http.statusCode) else {
            throw CoordinatorError(.pageUnavailable, "页面返回 HTTP \(http.statusCode)")
        }
        guard let finalURL = response.url, isLoopback(finalURL), finalURL.scheme?.lowercased() == "http",
              effectivePort(finalURL) == effectivePort(url) else {
            throw CoordinatorError(.outsideLoopback, "页面重定向到了本机之外")
        }

        let contentType = http.value(forHTTPHeaderField: "Content-Type")
        let bodyPrefix = String(data: data.prefix(4096), encoding: .utf8) ?? ""
        guard isHTML(contentType: contentType, bodyPrefix: bodyPrefix) else {
            throw CoordinatorError(.notBrowsablePage, "服务返回的不是可浏览 HTML 页面")
        }

        let title = firstMatch(in: bodyPrefix, pattern: #"(?is)<title[^>]*>\s*(.*?)\s*</title>"#)
            .map { stripMarkup($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
        let favicon = faviconURL(in: bodyPrefix, baseURL: finalURL)
        let evidence = ValidationEvidence(
            checkedURL: url,
            finalURL: finalURL,
            statusCode: http.statusCode,
            contentType: contentType,
            title: title,
            faviconURL: favicon
        )
        return PageProbeResult(evidence: evidence)
    }

    private func isLoopback(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
    }

    private func isHTML(contentType: String?, bodyPrefix: String) -> Bool {
        if let contentType {
            let normalized = contentType.lowercased()
            if normalized.contains("application/json") || normalized.contains("text/plain") || normalized.contains("application/grpc") {
                return false
            }
            if normalized.contains("text/html") || normalized.contains("application/xhtml+xml") { return true }
        }
        let normalized = bodyPrefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasPrefix("<!doctype html") || normalized.hasPrefix("<html") || normalized.contains("<html")
    }

    private func faviconURL(in html: String, baseURL: URL) -> URL? {
        guard let href = firstMatch(in: html, pattern: #"(?is)<link[^>]+rel=[\"'][^\"']*icon[^\"']*[\"'][^>]+href=[\"']([^\"']+)[\"']"#) ??
                firstMatch(in: html, pattern: #"(?is)<link[^>]+href=[\"']([^\"']+)[\"'][^>]+rel=[\"'][^\"']*icon[^\"']*[\"']"#),
              let url = URL(string: href, relativeTo: baseURL)?.absoluteURL,
              isSameOrigin(url, baseURL) else {
            return URL(string: "/favicon.ico", relativeTo: baseURL)?.absoluteURL
        }
        return url
    }

    private func isSameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == rhs.scheme?.lowercased() &&
        lhs.host?.lowercased() == rhs.host?.lowercased() &&
        effectivePort(lhs) == effectivePort(rhs)
    }

    private func effectivePort(_ url: URL) -> Int {
        url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80)
    }

    private func firstMatch(in value: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range), match.numberOfRanges > 1,
              let resultRange = Range(match.range(at: 1), in: value) else { return nil }
        return String(value[resultRange])
    }

    private func stripMarkup(_ value: String) -> String {
        value.replacingOccurrences(of: #"(?is)<[^>]+>"#, with: "", options: .regularExpression)
    }
}

