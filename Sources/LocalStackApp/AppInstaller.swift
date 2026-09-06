import AppKit
import LocalStackCore

@MainActor
enum AppInstaller {
    static func isInstalled(_ url: URL) -> Bool {
        let parent = url.resolvingSymlinksInPath().deletingLastPathComponent()
        return parent.path == "/Applications" || parent == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    }

    /// Resolve the actual disk image mount, including App Translocation's original volume.
    static func isRunningFromDiskImage(_ bundle: URL) -> Bool {
        if bundle.path.contains("/AppTranslocation/") { return true }
        guard bundle.path.hasPrefix("/Volumes/") else { return false }
        guard let data = try? run("/usr/bin/hdiutil", ["info", "-plist"]),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let images = plist["images"] as? [[String: Any]] else { return false }
        return images.contains { image in
            (image["system-entities"] as? [[String: Any]] ?? []).contains { entity in
                guard let mount = entity["mount-point"] as? String else { return false }
                return bundle.path.hasPrefix(mount + "/")
            }
        }
    }

    static func installFromDiskImage() async {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let fm = FileManager.default
        let directory = fm.isWritableFile(atPath: "/Applications")
            ? URL(fileURLWithPath: "/Applications")
            : fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        let destination = directory.appendingPathComponent("LocalStack.app")
        if fm.fileExists(atPath: destination.path) {
            let alert = NSAlert()
            alert.messageText = "更新 LocalStack？"
            alert.informativeText = "将替换应用程序中的现有版本，服务记录和偏好设置会保留。"
            alert.addButton(withTitle: "更新并打开")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { NSApp.terminate(nil); return }
        }
        do {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.localstack.app")
                .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && $0.bundleURL?.resolvingSymlinksInPath() == destination.resolvingSymlinksInPath() }
            for app in running { app.terminate() }
            for _ in 0..<50 {
                if running.allSatisfy(\.isTerminated) { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            guard running.allSatisfy(\.isTerminated) else {
                throw NSError(domain: "LocalStack", code: 1, userInfo: [NSLocalizedDescriptionKey: "请先退出正在运行的 LocalStack，再重新安装。"])
            }
            let source = Bundle.main.bundleURL
            let progress = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 120), styleMask: [.titled], backing: .buffered, defer: false)
            progress.isReleasedWhenClosed = false
            progress.title = "安装 LocalStack"
            let label = NSTextField(labelWithString: "正在安装到应用程序…")
            label.frame = NSRect(x: 30, y: 50, width: 280, height: 22)
            progress.contentView?.addSubview(label)
            progress.center(); progress.makeKeyAndOrderFront(nil)
            defer { progress.close() }
            try await Task.detached {
                try AppBundleInstallation.install(source: source, destination: destination, bundleIdentifier: "com.localstack.app") { source, stage in
                    _ = try Self.run("/usr/bin/ditto", [source.path, stage.path])
                    _ = try Self.run("/usr/bin/codesign", ["--verify", "--strict", stage.path])
                }
            }.value
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = true
            config.arguments = ["--installed"] + (CommandLine.arguments.contains("--enable-login") ? ["--enable-login"] : [])
            _ = try await NSWorkspace.shared.openApplication(at: destination, configuration: config)
            NSApp.terminate(nil)
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "LocalStack 安装未完成"
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    nonisolated private static func run(_ executable: String, _ arguments: [String]) throws -> Data {
        let task = Process()
        let output = Pipe()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        task.standardOutput = output
        task.standardError = FileHandle.nullDevice
        try task.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw NSError(domain: "LocalStack.Install", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "复制或校验应用失败，请检查应用程序目录的写入权限，并重新下载完整的 DMG。"])
        }
        return data
    }
}
