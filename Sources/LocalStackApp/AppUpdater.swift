import AppKit
import Foundation
import Observation
import LocalStackCore

@MainActor
@Observable
final class AppUpdater {
    private struct PreparedUpdate: Codable {
        let directory: UUID
        let manifest: AppUpdateManifest
    }
    enum State: Equatable {
        case idle, checking, current, available(String), downloading(String), ready(String), installing, failed(String)
        var busy: Bool {
            switch self { case .checking, .downloading, .installing: true; default: false }
        }
    }

    private let defaults: UserDefaults
    private let client = AppUpdateClient()
    private let team: String?
    private let enabled: Bool
    private var operation: Task<Void, Never>?
    private var timer: Task<Void, Never>?
    private var generation = UUID()
    private var offer: AppUpdateOffer?
    private var stagedApp: URL?
    private var lastAttempt: Date?
    private(set) var state: State = .idle
    private(set) var channel: AppUpdateChannel
    private(set) var automaticallyDownloads: Bool
    let currentVersion: String

    init(preview: Bool = false, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let bundle = Bundle.main
        currentVersion = bundle.object(forInfoDictionaryKey: "LocalStackReleaseVersion") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        channel = defaults.string(forKey: "updateChannel").flatMap(AppUpdateChannel.init(rawValue:))
            ?? (AppReleaseVersion(currentVersion)?.beta == nil ? .stable : .beta)
        automaticallyDownloads = defaults.object(forKey: "automaticallyDownloadUpdates") as? Bool ?? true
        enabled = !preview && AppInstaller.isInstalled(bundle.bundleURL)
        team = preview ? nil : AppUpdatePackage.teamIdentifier(at: bundle.bundleURL)
        if enabled && team != nil {
            // Persist the first install's channel so a beta-to-stable promotion
            // does not silently unsubscribe the user from future betas.
            defaults.set(channel.rawValue, forKey: "updateChannel")
            restorePreparedUpdate()
            let retainedDirectory = stagedApp?.deletingLastPathComponent()
            Task.detached { Self.pruneCache(retaining: retainedDirectory) }
            timer = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                while !Task.isCancelled {
                    self?.check(manual: false)
                    do { try await Task.sleep(for: .seconds(3600)) } catch { return }
                }
            }
        }
    }

    var canCheck: Bool { enabled && team != nil && !state.busy }
    var releaseURL: URL? { offer?.releaseURL }

    func setChannel(_ value: AppUpdateChannel) {
        guard channel != value, state != .installing else { return }
        generation = UUID()
        operation?.cancel()
        operation = nil
        discardPreparedUpdate()
        offer = nil
        channel = value
        defaults.set(value.rawValue, forKey: "updateChannel")
        state = .idle
        lastAttempt = nil
        check(manual: true)
    }

    func setAutomaticallyDownloads(_ value: Bool) {
        automaticallyDownloads = value
        defaults.set(value, forKey: "automaticallyDownloadUpdates")
    }

    func check(manual: Bool = true) {
        guard canCheck, let current = AppReleaseVersion(currentVersion), let team else { return }
        // Keep a prepared update until installation or a channel change.
        if case .ready = state { return }
        if let lastAttempt, Date().timeIntervalSince(lastAttempt) < 60 {
            if manual { state = .failed("刚刚检查过更新，请稍后重试。") }
            return
        }
        if !manual, let last = defaults.object(forKey: "lastUpdateCheck.\(channel.rawValue)") as? Date,
           Date().timeIntervalSince(last) < 24 * 3600 { return }
        lastAttempt = .now
        let token = generation
        let selectedChannel = channel
        state = .checking
        operation = Task { [weak self, client] in
            do {
                let result = try await client.check(current: current, channel: selectedChannel, team: team)
                try Task.checkCancellation()
                guard let self, token == self.generation else { return }
                self.defaults.set(Date(), forKey: "lastUpdateCheck.\(selectedChannel.rawValue)")
                self.offer = result
                if let result {
                    self.state = .available(result.manifest.version)
                    if self.automaticallyDownloads { self.download() }
                } else { self.state = .current }
            } catch is CancellationError {
            } catch {
                guard let self, token == self.generation else { return }
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    func download() {
        guard !state.busy, let offer, let team else { return }
        let token = generation
        state = .downloading(offer.manifest.version)
        operation = Task { [weak self, client] in
            var directory: URL?
            do {
                let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("com.localstack.app/updates", isDirectory: true)
                let work = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                directory = work
                let image = work.appendingPathComponent("LocalStack.dmg")
                try await client.download(offer, to: image)
                let task = Task.detached { try AppUpdatePackage.prepare(image: image, offer: offer, directory: work, team: team) }
                let app = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
                try Task.checkCancellation()
                guard let self, token == self.generation else { throw CancellationError() }
                self.stagedApp = app
                if let name = UUID(uuidString: work.lastPathComponent),
                   let data = try? JSONEncoder().encode(PreparedUpdate(directory: name, manifest: offer.manifest)) {
                    self.defaults.set(data, forKey: "preparedAppUpdate")
                }
                self.state = .ready(offer.manifest.version)
            } catch {
                // A failed detach may leave a volume here. Never recurse through it.
                if let directory, !FileManager.default.fileExists(atPath: directory.appendingPathComponent("mount").path) {
                    try? FileManager.default.removeItem(at: directory)
                }
                guard let self, token == self.generation, !(error is CancellationError) else { return }
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    func install() async {
        guard case .ready = state, let stagedApp, let offer, let team, channel.accepts(offer.version) else { return }
        state = .installing
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = ["--install-update", "--update-destination", Bundle.main.bundleURL.path]
        do {
            // Cached code must be revalidated immediately before it is launched.
            try await Task.detached {
                try AppUpdatePackage.verifyApp(stagedApp, version: offer.manifest.version, build: offer.manifest.buildNumber, team: team)
            }.value
            let installer = try await NSWorkspace.shared.openApplication(at: stagedApp, configuration: configuration)
            while !installer.isTerminated { try await Task.sleep(for: .seconds(1)) }
            // Success terminates this old process. If it is still running, the
            // installer was cancelled or failed and checking can be retried.
            state = .failed(AppUpdateError.installationFailed.localizedDescription)
        } catch { state = .failed(error.localizedDescription) }
    }

    func shutdown() {
        timer?.cancel()
        operation?.cancel()
    }

    private func discardPreparedUpdate() {
        defaults.removeObject(forKey: "preparedAppUpdate")
        if let stagedApp { Self.removeCacheDirectory(stagedApp.deletingLastPathComponent()) }
        stagedApp = nil
    }

    nonisolated private static func removeCacheDirectory(_ directory: URL) {
        guard !FileManager.default.fileExists(atPath: directory.appendingPathComponent("mount").path) else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    nonisolated private static func pruneCache(retaining retained: URL?) {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.localstack.app/updates", isDirectory: true)
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: Array(keys)) else { return }
        for entry in entries {
            guard entry != retained, UUID(uuidString: entry.lastPathComponent) != nil,
                  let values = try? entry.resourceValues(forKeys: keys),
                  values.isDirectory == true, values.isSymbolicLink != true,
                  let modified = values.contentModificationDate,
                  Date().timeIntervalSince(modified) > 7 * 24 * 3600 else { continue }
            removeCacheDirectory(entry)
        }
    }

    private func restorePreparedUpdate() {
        guard let data = defaults.data(forKey: "preparedAppUpdate"),
              let cached = try? JSONDecoder().decode(PreparedUpdate.self, from: data),
              let version = AppReleaseVersion(cached.manifest.version), let current = AppReleaseVersion(currentVersion),
              version > current, channel.accepts(version), let team,
              (try? cached.manifest.validate(version: version, team: team, size: cached.manifest.size)) != nil else {
            defaults.removeObject(forKey: "preparedAppUpdate")
            return
        }
        let app = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.localstack.app/updates/\(cached.directory.uuidString)/LocalStack.app")
        guard FileManager.default.fileExists(atPath: app.path) else {
            defaults.removeObject(forKey: "preparedAppUpdate")
            return
        }
        offer = AppUpdateOffer(manifest: cached.manifest, downloadURL: URL(string: "https://github.com/backrunner/localstack/releases/download/v\(version)/\(cached.manifest.fileName)")!)
        stagedApp = app
        state = .ready(version.description)
    }
}
