import CryptoKit
import Darwin
import Foundation
import Security

public enum AppUpdatePackage {
    public static func teamIdentifier(at app: URL) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let team = (information as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String,
              team.count == 10, team.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) }) else { return nil }
        return team
    }

    /// Called off the main actor. Verify the image before mounting, then copy
    /// out and verify the app so installation never depends on a mounted DMG.
    public static func prepare(image: URL, offer: AppUpdateOffer, directory: URL, team: String) throws -> URL {
        let file = try FileHandle(forReadingFrom: image)
        defer { try? file.close() }
        var hash = SHA256()
        while let bytes = try file.read(upToCount: 1024 * 1024), !bytes.isEmpty {
            try Task.checkCancellation()
            hash.update(data: bytes)
        }
        guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == offer.manifest.sha256 else { throw AppUpdateError.checksumMismatch }
        try verifySignature(image, team: team, app: false)
        try verifyNotarization(image, app: false)
        try Task.checkCancellation()
        let mount = directory.appendingPathComponent("mount", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: false)
        // Cleanup removes only an empty mountpoint; it never traverses a volume.
        // An attach that reports failure can still have mounted the volume.
        var needsDetach = true
        defer {
            if needsDetach { _ = try? run("/usr/bin/hdiutil", ["detach", mount.path]) }
            _ = mount.path.withCString { Darwin.rmdir($0) }
            try? FileManager.default.removeItem(at: image)
        }
        try run("/usr/bin/hdiutil", ["attach", image.path, "-readonly", "-nobrowse", "-noautoopen", "-mountpoint", mount.path])
        let source = mount.appendingPathComponent("LocalStack.app")
        try verifyApp(source, version: offer.manifest.version, build: offer.manifest.buildNumber, team: team)
        try Task.checkCancellation()
        let staged = directory.appendingPathComponent("LocalStack.app")
        try run("/usr/bin/ditto", [source.path, staged.path])
        try verifyApp(staged, version: offer.manifest.version, build: offer.manifest.buildNumber, team: team)
        try run("/usr/bin/hdiutil", ["detach", mount.path])
        needsDetach = false
        try FileManager.default.removeItem(at: mount)
        return staged
    }

    public static func verifyApp(_ app: URL, version: String, build: String? = nil, team: String) throws {
        try verifySignature(app, team: team, app: true)
        let data = try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        guard let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              info["CFBundleIdentifier"] as? String == "com.localstack.app",
              info["LocalStackReleaseVersion"] as? String == version,
              build == nil || info["CFBundleVersion"] as? String == build,
              let minimum = info["LSMinimumSystemVersion"] as? String,
              let required = AppUpdateManifest.systemVersion(minimum),
              ProcessInfo.processInfo.isOperatingSystemAtLeast(required) else { throw AppUpdateError.invalidRelease }
        try verifyNotarization(app, app: true)
    }

    private static func verifySignature(_ target: URL, team: String, app: Bool) throws {
        guard team.count == 10, team.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) }) else { throw AppUpdateError.invalidSignature }
        var requirement = "anchor apple generic and certificate leaf[subject.OU] = \"\(team)\" and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
        if app { requirement += " and identifier \"com.localstack.app\"" }
        do {
            try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", "--all-architectures", "-R", "=" + requirement, target.path])
        } catch { throw AppUpdateError.invalidSignature }
    }

    private static func verifyNotarization(_ target: URL, app: Bool) throws {
        var arguments = ["--assess", "--raw", "--type", app ? "execute" : "open"]
        if !app { arguments += ["--context", "context:primary-signature"] }
        arguments.append(target.path)
        let output = try run("/usr/sbin/spctl", arguments)
        guard let assessment = try PropertyListSerialization.propertyList(from: output, format: nil) as? [String: Any],
              assessment["assessment:verdict"] as? Bool == true,
              let authority = assessment["assessment:authority"] as? [String: Any],
              authority["assessment:authority:source"] as? String == "Notarized Developer ID" else { throw AppUpdateError.invalidSignature }
    }

    /// System tools only: installed apps do not require Xcode or notarytool.
    @discardableResult
    public static func run(_ executable: String, _ arguments: [String]) throws -> Data {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("localstack-update-command-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { throw AppUpdateError.unavailable }
        let output = try FileHandle(forUpdating: outputURL)
        defer { try? output.close(); try? FileManager.default.removeItem(at: outputURL) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let deadline = Date().addingTimeInterval(120)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        if process.isRunning {
            process.terminate()
            let grace = Date().addingTimeInterval(2)
            while process.isRunning && Date() < grace { Thread.sleep(forTimeInterval: 0.05) }
            if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
            throw AppUpdateError.unavailable
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw AppUpdateError.invalidSignature }
        try output.seek(toOffset: 0)
        let data = try output.read(upToCount: 1024 * 1024 + 1) ?? Data()
        guard data.count <= 1024 * 1024 else { throw AppUpdateError.unavailable }
        return data
    }
}
