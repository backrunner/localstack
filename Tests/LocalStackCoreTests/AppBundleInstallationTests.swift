import Foundation
import Testing
import LocalStackCore

private func bundle(_ directory: URL, name: String, id: String = "com.localstack.app", version: String) throws -> URL {
    let url = directory.appendingPathComponent(name)
    try FileManager.default.createDirectory(at: url.appendingPathComponent("Contents"), withIntermediateDirectories: true)
    let data = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": id, "CFBundleVersion": version], format: .xml, options: 0)
    try data.write(to: url.appendingPathComponent("Contents/Info.plist"))
    try Data(version.utf8).write(to: url.appendingPathComponent("version"))
    return url
}

@Test("Installer copies a new app and atomically upgrades an existing version")
func installAndUpgrade() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = try bundle(root, name: "Source.app", version: "2")
    let destination = root.appendingPathComponent("Applications/LocalStack.app")
    try AppBundleInstallation.install(source: source, destination: destination, bundleIdentifier: "com.localstack.app")
    #expect(try String(contentsOf: destination.appendingPathComponent("version"), encoding: .utf8) == "2")
    try Data("3".utf8).write(to: source.appendingPathComponent("version"))
    try AppBundleInstallation.install(source: source, destination: destination, bundleIdentifier: "com.localstack.app")
    #expect(try String(contentsOf: destination.appendingPathComponent("version"), encoding: .utf8) == "3")
    #expect(try FileManager.default.contentsOfDirectory(atPath: destination.deletingLastPathComponent().path) == ["LocalStack.app"])
}

@Test("A failed staged copy preserves the installed app and removes partial files")
func failedCopyPreservesInstallation() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = try bundle(root, name: "Source.app", version: "2")
    let destination = try bundle(root, name: "LocalStack.app", version: "1")
    #expect(throws: CocoaError.self) {
        try AppBundleInstallation.install(source: source, destination: destination, bundleIdentifier: "com.localstack.app") { _, stage in
            try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
            throw CocoaError(.fileWriteOutOfSpace)
        }
    }
    #expect(try String(contentsOf: destination.appendingPathComponent("version"), encoding: .utf8) == "1")
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == ["LocalStack.app", "Source.app"])
}

@Test("Installer refuses to overwrite unrelated apps or accept incomplete bundles")
func refusesInvalidBundles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = try bundle(root, name: "Source.app", version: "2")
    let destination = try bundle(root, name: "LocalStack.app", id: "org.other.app", version: "1")
    #expect(throws: AppBundleInstallation.InstallationError.self) {
        try AppBundleInstallation.install(source: source, destination: destination, bundleIdentifier: "com.localstack.app")
    }
    #expect(try String(contentsOf: destination.appendingPathComponent("version"), encoding: .utf8) == "1")
    #expect(throws: AppBundleInstallation.InstallationError.self) {
        try AppBundleInstallation.install(source: root.appendingPathComponent("Missing.app"), destination: destination, bundleIdentifier: "com.localstack.app")
    }
}
