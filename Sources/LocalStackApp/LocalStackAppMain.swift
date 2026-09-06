import AppKit
import SwiftUI
import ServiceManagement

@main
@MainActor
struct LocalStackApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = LocalStackAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class LocalStackAppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppInstaller.isRunningFromDiskImage(Bundle.main.bundleURL) || CommandLine.arguments.contains("--install") {
            Task { await AppInstaller.installFromDiskImage() }
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render-previews"), CommandLine.arguments.count > index + 1 {
            PanelPreview.render(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            NSApp.terminate(nil)
            return
        }
        let existing = NSRunningApplication.runningApplications(withBundleIdentifier: "com.localstack.app")
            .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && $0.bundleURL == Bundle.main.bundleURL }
        if let existing { existing.activate(); NSApp.terminate(nil); return }
        let model = AppModel()
        self.model = model
        model.configureFirstLaunch()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            let image = NSImage(size: NSSize(width: 20, height: 20), flipped: true) { rect in
                let path = StackMark().path(in: rect.insetBy(dx: 1, dy: 1)).cgPath
                let context = NSGraphicsContext.current!.cgContext
                context.addPath(path)
                context.setStrokeColor(NSColor.black.cgColor)
                context.setLineWidth(1.6)
                context.setLineJoin(.round); context.setLineCap(.round)
                context.strokePath()
                return true
            }
            image.isTemplate = true
            button.image = image
            button.toolTip = "LocalStack · 本地开发服务"
            button.setAccessibilityLabel("LocalStack 本地开发服务")
            button.target = self
            button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        popover.contentSize = NSSize(width: LSPanelLayout.width, height: LSPanelLayout.height)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: TrayPanel(model: model))
        if CommandLine.arguments.contains("--installed") || CommandLine.arguments.contains("--show-panel") {
            // The status item's window initially has zero height during didFinishLaunching.
            Task { @MainActor [weak self] in
                for _ in 0..<20 {
                    guard let self else { return }
                    if let window = self.statusItem?.button?.window, window.frame.height > 0 {
                        self.showPanel()
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
        }
    }

    @objc private func togglePanel() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "打开 LocalStack", action: #selector(showPanel), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "退出 LocalStack", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else if popover.isShown { popover.performClose(nil) }
        else { showPanel() }
    }

    @objc private func showPanel() {
        guard let button = statusItem?.button else { return }
        model?.refreshLaunchAtLoginStatus()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPanel(); return true }
    func application(_ application: NSApplication, open urls: [URL]) { urls.forEach { DeepLinkRouter.shared.receive($0) } }
}
