import AppKit
import SwiftUI
import LocalStackShared

/// Deterministic offscreen renders for visual review; never adds demo records to the coordinator.
@MainActor
enum PanelPreview {
    static func render(to directory: URL) async {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let originalAppearance = NSApp.appearance
        defer { NSApp.appearance = originalAppearance }
        let examples: [(String, Int, ServiceSourceKind)] = [
            ("IPA Room", 60944, .discovered), ("IPA Room", 60943, .sdk),
            ("LocalStack Website", 5173, .unplugin), ("Design System", 6006, .discovered),
            ("API Dashboard", 3000, .sdk), ("项目控制台", 8080, .mcp),
            ("文档预览", 4173, .discovered), ("账户与支付后台", 8787, .sdk),
            ("Storybook", 6007, .discovered), ("团队管理工作台", 8081, .unplugin),
            ("一个很长的本地开发服务名称", 52963, .discovered), ("Web Preview", 9000, .mcp)
        ]
        let records = examples.enumerated().map { index, example in
            let (name, port, source) = example
            let url = URL(string: "http://localhost:\(port)")!
            return ServiceRecord(port: port, url: url, process: ProcessFingerprint(pid: Int32(1234 + index), uid: 501, startTime: .now), displayName: name, validation: ValidationEvidence(checkedURL: url, finalURL: url, statusCode: 200, contentType: "text/html", title: name), source: source)
        }
        let selected = Set([records[0].id, records[2].id, records[5].id])
        let cases: [(String, [ServiceRecord], ColorScheme, Set<UUID>?, UnitPoint)] = [
            ("panel-light", records, .light, nil, .top), ("panel-dark", records, .dark, nil, .top),
            ("panel-eight", Array(records.prefix(8)), .dark, nil, .top),
            ("panel-short", Array(records.prefix(4)), .light, nil, .top),
            ("panel-selected", records, .light, selected, .top), ("panel-selected-dark", records, .dark, selected, .top),
            ("panel-scrolled", records, .dark, nil, .center), ("panel-bottom", records, .dark, nil, .bottom),
            ("panel-empty", [], .light, nil, .top),
            ("panel-settings", records, .light, nil, .top), ("panel-settings-dark", records, .dark, nil, .top)
        ]
        for (name, services, scheme, selectedIDs, anchor) in cases {
            NSApp.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            let view = TrayPanel(model: AppModel(previewServices: services), showSettings: name.hasPrefix("panel-settings"),
                selectedIDs: selectedIDs, initialScrollAnchor: anchor).environment(\.colorScheme, scheme)
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(x: 0, y: 0, width: LSPanelLayout.width, height: LSPanelLayout.height)
            let window = PreviewWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            // Native controls need an active window and a render pass before
            // capture; otherwise switches and glass buttons appear inactive.
            try? await Task.sleep(for: .milliseconds(250))
            host.layoutSubtreeIfNeeded()
            defer { window.close() }
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }
}

private final class PreviewWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
