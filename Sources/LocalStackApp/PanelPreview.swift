import AppKit
import SwiftUI
import LocalStackShared

/// Deterministic offscreen renders for visual review; never adds demo records to the coordinator.
@MainActor
enum PanelPreview {
    static func render(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let records = [("LocalStack Website", 5173, ServiceSourceKind.unplugin), ("Design System", 6006, .discovered), ("API Dashboard", 3000, .sdk), ("项目控制台", 8080, .mcp)].map { name, port, source in
            let url = URL(string: "http://localhost:\(port)")!
            return ServiceRecord(port: port, url: url, process: ProcessFingerprint(pid: 1234, uid: 501, startTime: .now), displayName: name, validation: ValidationEvidence(checkedURL: url, finalURL: url, statusCode: 200, contentType: "text/html", title: name), source: source)
        }
        for (name, services, scheme) in [("panel-light", records, ColorScheme.light), ("panel-dark", records, .dark), ("panel-empty", [], .light), ("panel-settings", records, .light)] {
            let view = TrayPanel(model: AppModel(previewServices: services), showSettings: name == "panel-settings").environment(\.colorScheme, scheme)
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(x: 0, y: 0, width: LSPanelLayout.width, height: LSPanelLayout.height)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }
}
