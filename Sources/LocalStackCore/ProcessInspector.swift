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

    public func listeningPorts(for pid: Int32) -> Set<Int> {
        Set(ProcessSockets.listeners(pid: pid).map(\.port))
    }

    public func executableName(for pid: Int32) -> String {
        var path = [CChar](repeating: 0, count: 4096)
        if proc_pidpath(pid, &path, UInt32(path.count)) <= 0 {
            // Deleted temporary binaries can still have live listeners. Use the
            // kernel's process name rather than guessing from argv[0].
            path = [CChar](repeating: 0, count: 256)
            guard proc_name(pid, &path, UInt32(path.count)) > 0 else { return "未知进程" }
        }
        let bytes = path.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return URL(fileURLWithPath: String(decoding: bytes, as: UTF8.self)).lastPathComponent
    }

    public func isInternalDevelopmentEndpoint(_ candidate: PortCandidate, process: ProcessFingerprint) -> Bool {
        guard candidate.pid == process.pid, fingerprint(for: process.pid) == process else { return false }
        let executable = executableName(for: process.pid)
        guard executable == "workerd", let arguments = Self.arguments(for: process.pid) else { return false }
        let listeners = ProcessSockets.listeners(pid: process.pid)
        let isInternal = DevelopmentEndpointDetection.isInternal(
            executable: executable, arguments: arguments, candidate: candidate, listeners: listeners
        )
        // No exclusions are cached: every scan reads the current launch metadata
        // and owned sockets, and rejects evidence spanning a process restart.
        return isInternal && fingerprint(for: process.pid) == process
    }

    static func arguments(for pid: Int32) -> [String]? {
        var mib = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0,
              size > MemoryLayout<Int32>.size, size <= 1_048_576 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, UInt32(mib.count), &bytes, &size, nil, 0) == 0 else { return nil }
        return decodeArguments(Array(bytes.prefix(size)))
    }

    static func decodeArguments(_ bytes: [UInt8]) -> [String]? {
        guard bytes.count > MemoryLayout<Int32>.size else { return nil }
        let count = bytes.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        guard count > 0, count <= bytes.count else { return nil }
        var index = MemoryLayout<Int32>.size
        // KERN_PROCARGS2 starts with argc, the executable path and NUL padding,
        // followed by exactly argc argument strings. Never read the environment.
        guard let pathEnd = bytes[index...].firstIndex(of: 0) else { return nil }
        index = pathEnd
        while index < bytes.count && bytes[index] == 0 { index += 1 }
        var arguments: [String] = []
        for _ in 0..<count {
            guard index < bytes.count, let end = bytes[index...].firstIndex(of: 0) else { return nil }
            arguments.append(String(decoding: bytes[index..<end], as: UTF8.self))
            index = end + 1
        }
        return arguments
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
