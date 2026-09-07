import CryptoKit
import Foundation
import Testing
@testable import LocalStackCore

@Test("Release ordering handles beta numbers, promotions, and future beta versions")
func releaseOrdering() throws {
    let ordered = ["0.2.2", "0.2.3-beta.1", "0.2.3-beta.2", "0.2.3-beta.10", "0.2.3", "0.2.4-beta.1", "0.3.0", "1.0.0-beta.1", "1.0.0"]
    let versions = try ordered.map { try #require(AppReleaseVersion($0)) }
    #expect(versions.sorted() == versions)
    for (left, right) in zip(versions, versions.dropFirst()) { #expect(left < right) }
    #expect(AppReleaseVersion("0.2.3-beta.10")?.description == "0.2.3-beta.10")
}

@Test("Unsupported channels and malformed versions cannot enter the updater", arguments: [
    "v0.2.3", "0.2", "0.2.3.4", "01.2.3", "0.02.3", "0.2.3-beta.0", "0.2.3-beta.01",
    "0.2.3-beta.-1", "0.2.3-beta.1-extra", "0.2.3-nightly.1", "0.2.3+metadata", "0.2.3-rc.1",
    "0.2.3\n", "0.2.999999999999999999999999999999999999"
])
func malformedRelease(value: String) { #expect(AppReleaseVersion(value) == nil) }

private func release(_ version: String, draft: Bool = false, prerelease: Bool? = nil,
                     urlPrefix: String = "https://github.com/backrunner/localstack", manifest: Bool = true) throws -> GitHubAppRelease {
    let tag = "v\(version)"
    let names = ["LocalStack-\(version).dmg"] + (manifest ? ["LocalStack-update.json"] : [])
    let data = try JSONSerialization.data(withJSONObject: [
        "tag_name": tag, "draft": draft, "prerelease": prerelease ?? version.contains("-"),
        "assets": names.map { ["name": $0, "size": 100, "state": "uploaded", "browser_download_url": "\(urlPrefix)/releases/download/\(tag)/\($0)"] }
    ])
    return try JSONDecoder().decode(GitHubAppRelease.self, from: data)
}

@Test("Stable excludes beta, while beta includes stable promotions without downgrading")
func updateChannels() throws {
    let releases = try [release("0.2.3-beta.2"), release("0.2.2"), release("0.2.3-beta.10"), release("0.2.3"), release("0.3.0-beta.1")]
    let current = try #require(AppReleaseVersion("0.2.3-beta.2"))
    #expect(GitHubAppRelease.candidates(releases, newerThan: current, channel: .stable).map(\.tagName) == ["v0.2.3"])
    #expect(GitHubAppRelease.candidates(releases, newerThan: current, channel: .beta).map(\.tagName) == ["v0.3.0-beta.1", "v0.2.3", "v0.2.3-beta.10"])
    let newerBeta = try #require(AppReleaseVersion("0.3.0-beta.1"))
    #expect(GitHubAppRelease.candidates(releases, newerThan: newerBeta, channel: .stable).isEmpty)
}

@Test("Drafts, mismatched channels, missing manifests, and foreign assets are ignored")
func rejectedUpdateCandidates() throws {
    let releases = try [release("1.0.0", draft: true), release("1.1.0-beta.1", prerelease: false),
                        release("1.2.0", prerelease: true), release("1.3.0", manifest: false),
                        release("1.4.0", urlPrefix: "https://github.com/another/project")]
    #expect(GitHubAppRelease.candidates(releases, newerThan: AppReleaseVersion("0.2.3")!, channel: .beta).isEmpty)
}

private func manifest(_ changes: [String: Any] = [:]) throws -> AppUpdateManifest {
    var fields: [String: Any] = [
        "schemaVersion": 1, "version": "0.2.3-beta.2", "channel": "beta", "buildNumber": "2.1",
        "bundleIdentifier": "com.localstack.app", "teamIdentifier": "ABCDEFGHIJ", "minimumSystemVersion": "15.0",
        "fileName": "LocalStack-0.2.3-beta.2.dmg", "size": 100, "sha256": String(repeating: "a", count: 64)
    ]
    fields.merge(changes) { _, value in value }
    return try JSONDecoder().decode(AppUpdateManifest.self, from: JSONSerialization.data(withJSONObject: fields))
}

@Test("Manifest identity, artifact size, and release channel must agree")
func manifestValidation() throws {
    let version = try #require(AppReleaseVersion("0.2.3-beta.2"))
    try manifest().validate(version: version, team: "ABCDEFGHIJ", size: 100)
    for change: [String: Any] in [
        ["schemaVersion": 2], ["version": "0.2.3"], ["channel": "stable"], ["teamIdentifier": "WRONGTEAM1"],
        ["bundleIdentifier": "com.other.app"], ["fileName": "../other.dmg"], ["size": 101],
        ["size": 0], ["sha256": "bad"], ["minimumSystemVersion": "15.0.0.1"], ["buildNumber": ""]
    ] {
        #expect(throws: AppUpdateError.self) { try manifest(change).validate(version: version, team: "ABCDEFGHIJ", size: 100) }
    }
}

@Test("A mismatched download checksum is rejected before mounting")
func checksumFailure() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let image = directory.appendingPathComponent("LocalStack.dmg")
    try Data("corrupt image".utf8).write(to: image)
    let offer = AppUpdateOffer(manifest: try manifest(), downloadURL: URL(string: "https://github.com/backrunner/localstack")!)
    #expect(throws: AppUpdateError.self) { try AppUpdatePackage.prepare(image: image, offer: offer, directory: directory, team: "ABCDEFGHIJ") }
    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("mount").path))
}

@Test("An unsigned app cannot be launched as an update")
func unsignedUpdateRejected() throws {
    let app = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).app")
    try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: app) }
    #expect(throws: AppUpdateError.self) { try AppUpdatePackage.verifyApp(app, version: "0.2.3-beta.2", team: "ABCDEFGHIJ") }
}

@Test("Published notarized DMG can be verified and staged for the updater",
      .enabled(if: ProcessInfo.processInfo.environment["LOCALSTACK_UPDATER_TEST_DMG"] != nil))
func publishedDMGStaging() throws {
    let source = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["LOCALSTACK_UPDATER_TEST_DMG"]))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("localstack-update-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        if !FileManager.default.fileExists(atPath: directory.appendingPathComponent("mount").path) {
            try? FileManager.default.removeItem(at: directory)
        }
    }
    let image = directory.appendingPathComponent("LocalStack.dmg")
    try FileManager.default.copyItem(at: source, to: image)
    let contents = try Data(contentsOf: image)
    let descriptor = try manifest([
        "version": "0.2.3-beta.1", "buildNumber": "1.1", "teamIdentifier": "PB8H83VL3Z",
        "fileName": "LocalStack-0.2.3-beta.1.dmg", "size": contents.count,
        "sha256": SHA256.hash(data: contents).map { String(format: "%02x", $0) }.joined()
    ])
    let offer = AppUpdateOffer(manifest: descriptor, downloadURL: URL(string: "https://github.com/backrunner/localstack")!)
    let app = try AppUpdatePackage.prepare(image: image, offer: offer, directory: directory, team: "PB8H83VL3Z")
    #expect(FileManager.default.fileExists(atPath: app.appendingPathComponent("Contents/MacOS/LocalStack").path))
    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("mount").path))
}
