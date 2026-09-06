import AppKit
import Foundation

@MainActor
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    private var pendingURL: URL?
    private var handler: ((URL) -> Void)?

    func register(handler: @escaping (URL) -> Void) {
        self.handler = handler
        if let pendingURL {
            self.pendingURL = nil
            handler(pendingURL)
        }
    }

    func receive(_ url: URL) {
        if let handler {
            handler(url)
        } else {
            pendingURL = url
        }
    }
}

