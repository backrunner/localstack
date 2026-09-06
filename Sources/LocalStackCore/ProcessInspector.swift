import Darwin
import Foundation
import LocalStackShared

public struct ProcessInspector: ProcessInspecting {
    public init() {}

    public var currentUID: UInt32 { getuid() }

    public func fingerprint(for pid: Int32) -> ProcessFingerprint? {
        guard pid > 0, let info = processInfo(pid: pid), info.uid == currentUID, kill(pid, 0) == 0 else { return nil }
        let startTime = Date(timeIntervalSince1970: TimeInterval(info.startSeconds) + TimeInterval(info.startMicroseconds) / 1_000_000)
        return ProcessFingerprint(pid: pid, uid: info.uid, startTime: startTime)
    }

    public func ownsPort(_ port: Int, pid: Int32) -> Bool {
        ProcessSockets.listeners(pid: pid).contains { $0.port == port }
    }

    public func executableName(for pid: Int32) -> String {
        var path = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return "未知进程" }
        let bytes = path.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return URL(fileURLWithPath: String(decoding: bytes, as: UTF8.self)).lastPathComponent
    }

    public func terminate(_ fingerprint: ProcessFingerprint, force: Bool = false) -> Bool {
        guard let current = self.fingerprint(for: fingerprint.pid), current == fingerprint else { return false }
        return kill(fingerprint.pid, force ? SIGKILL : SIGTERM) == 0
    }

    private func processInfo(pid: Int32) -> (uid: UInt32, startSeconds: UInt64, startMicroseconds: UInt64)? {
        var info = proc_bsdinfo()
        let size = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
        guard size == Int32(MemoryLayout<proc_bsdinfo>.size) else { return nil }
        return (info.pbi_uid, info.pbi_start_tvsec, info.pbi_start_tvusec)
    }

}
