import AppKit
import Foundation
import Testing
@testable import LocalStackCore

/// Runs only on the disposable release runner, using two notarized builds of
/// this source. Never replaces an existing installation on a developer's Mac.
@Test("Notarized updater replaces and relaunches both installation locations while preserving an HTTP server",
      .enabled(if: ProcessInfo.processInfo.environment["LOCALSTACK_UPDATE_INSTALL_FIXTURE"] != nil))
@MainActor
func notarizedUpdateInstallation() async throws {
    let env = ProcessInfo.processInfo.environment
    try #require(env["GITHUB_ACTIONS"] == "true")
    let fm = FileManager.default
    let fixture = URL(fileURLWithPath: try #require(env["LOCALSTACK_UPDATE_INSTALL_FIXTURE"]))
    let image = URL(fileURLWithPath: try #require(env["LOCALSTACK_UPDATE_INSTALL_DMG"]))
    let manifestURL = URL(fileURLWithPath: try #require(env["LOCALSTACK_UPDATE_INSTALL_MANIFEST"]))
    let manifest = try JSONDecoder().decode(AppUpdateManifest.self, from: Data(contentsOf: manifestURL))
    let version = try #require(AppReleaseVersion(manifest.version))
    try manifest.validate(version: version, team: manifest.teamIdentifier, size: manifest.size)
    let destinations = [URL(fileURLWithPath: "/Applications/LocalStack.app"),
                        fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications/LocalStack.app")]
    for destination in destinations { try #require(!fm.fileExists(atPath: destination.path)) }
    try #require(NSRunningApplication.runningApplications(withBundleIdentifier: "com.localstack.app").isEmpty)

    let work = fm.temporaryDirectory.appendingPathComponent("localstack-install-test-\(UUID().uuidString)")
    try fm.createDirectory(at: work, withIntermediateDirectories: false)
    defer {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: "com.localstack.app") {
            if let url = app.bundleURL, destinations.contains(where: { $0.path == url.path }) || url.path.hasPrefix(work.path + "/") {
                app.forceTerminate()
            }
        }
        for destination in destinations { try? fm.removeItem(at: destination) }
        if !fm.fileExists(atPath: work.appendingPathComponent("mount").path) { try? fm.removeItem(at: work) }
    }

    let copiedImage = work.appendingPathComponent("LocalStack.dmg")
    try fm.copyItem(at: image, to: copiedImage)
    let offer = AppUpdateOffer(manifest: manifest, downloadURL: URL(string: "https://github.com/backrunner/localstack/releases/download/v\(version)/\(manifest.fileName)")!)
    let staged = try await Task.detached {
        try AppUpdatePackage.prepare(image: copiedImage, offer: offer, directory: work, team: manifest.teamIdentifier)
    }.value

    let server = Process()
    let serverOutput = Pipe()
    server.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    server.arguments = ["-u", "-c", """
        from http.server import BaseHTTPRequestHandler, HTTPServer
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'localstack-update-smoke')
            def log_message(self, *args): pass
        server = HTTPServer(('127.0.0.1', 0), Handler)
        print(server.server_port, flush=True)
        server.serve_forever()
        """]
    server.standardOutput = serverOutput
    server.standardError = FileHandle.nullDevice
    try server.run()
    defer { server.terminate(); server.waitUntilExit() }
    let portText = String(decoding: serverOutput.fileHandleForReading.availableData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    let port = try #require(UInt16(portText))
    let serverURL = URL(string: "http://127.0.0.1:\(port)")!

    for destination in destinations {
        print("Testing update at \(destination.path)")
        try await Task.detached {
            try AppUpdatePackage.verifyApp(fixture, version: "0.0.0-beta.1", team: manifest.teamIdentifier)
            try AppBundleInstallation.install(source: fixture, destination: destination, bundleIdentifier: "com.localstack.app") {
                try AppUpdatePackage.run("/usr/bin/ditto", [$0.path, $1.path])
            }
        }.value
        let old = try await NSWorkspace.shared.openApplication(at: destination, configuration: NSWorkspace.OpenConfiguration())
        try await waitForUpdateCondition { old.isFinishedLaunching && !old.isTerminated }
        let (before, _) = try await URLSession.shared.data(from: serverURL)
        try #require(String(decoding: before, as: UTF8.self) == "localstack-update-smoke")

        // Exercise the same NSWorkspace handoff used by AppUpdater.install().
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = ["--install-update", "--update-destination", destination.path]
        let installer = try await NSWorkspace.shared.openApplication(at: staged, configuration: configuration)
        try await waitForUpdateCondition { old.isTerminated && installer.isTerminated }
        let installed = try #require(NSRunningApplication.runningApplications(withBundleIdentifier: "com.localstack.app")
            .first { $0.bundleURL?.path == destination.path && $0.processIdentifier != old.processIdentifier && !$0.isTerminated })
        try await waitForUpdateCondition { installed.isFinishedLaunching && !installed.isTerminated }
        try await Task.detached {
            try AppUpdatePackage.verifyApp(destination, version: manifest.version, build: manifest.buildNumber, team: manifest.teamIdentifier)
        }.value
        // The newly launched version must stay alive beyond its initial setup.
        try await Task.sleep(for: .seconds(2))
        try #require(!installed.isTerminated && server.isRunning)
        let (after, _) = try await URLSession.shared.data(from: serverURL)
        try #require(after == before)
        installed.terminate()
        try await waitForUpdateCondition { installed.isTerminated }
        try fm.removeItem(at: destination)
        print("Verified replacement, relaunch, and HTTP server preservation at \(destination.path)")
    }
}

@MainActor
private func waitForUpdateCondition(_ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(90)
    while !condition(), Date() < deadline { try await Task.sleep(for: .milliseconds(200)) }
    try #require(condition(), "Timed out waiting for the updater installation handoff")
}
