import Darwin
import Foundation

/// Reads the kernel's descriptor table directly, without spawning lsof per PID/port.
enum ProcessSockets {
    struct Listener {
        let port: Int
        let loopbackURL: URL?
    }

    static func currentUserPIDs() -> [Int32] {
        let needed = proc_listpids(UInt32(PROC_UID_ONLY), getuid(), nil, 0)
        guard needed > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(needed) / MemoryLayout<Int32>.stride + 256)
        let count = proc_listpids(UInt32(PROC_UID_ONLY), getuid(), &pids, Int32(pids.count * MemoryLayout<Int32>.stride))
        return Array(pids.prefix(max(0, Int(count) / MemoryLayout<Int32>.stride)).filter { $0 > 0 })
    }

    static func listeners(pid: Int32) -> [Listener] {
        let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard needed > 0 else { return [] }
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(needed) / MemoryLayout<proc_fdinfo>.stride + 32)
        let count = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, Int32(fds.count * MemoryLayout<proc_fdinfo>.stride))
        var result: [Listener] = []
        for fd in fds.prefix(max(0, Int(count) / MemoryLayout<proc_fdinfo>.stride)) where fd.proc_fdtype == PROX_FDTYPE_SOCKET {
            var info = socket_fdinfo()
            let size = Int32(MemoryLayout<socket_fdinfo>.size)
            guard proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &info, size) == size,
                  info.psi.soi_kind == SOCKINFO_TCP,
                  info.psi.soi_proto.pri_tcp.tcpsi_state == TSI_S_LISTEN else { continue }
            var address = info.psi.soi_proto.pri_tcp.tcpsi_ini
            let port = Int(UInt16(bigEndian: UInt16(truncatingIfNeeded: address.insi_lport)))
            let host: String?
            if info.psi.soi_family == AF_INET {
                let ip = UInt32(bigEndian: address.insi_laddr.ina_46.i46a_addr4.s_addr)
                host = ip == 0 || ip == 0x7F000001 ? "127.0.0.1" : nil
            } else if info.psi.soi_family == AF_INET6 {
                let bytes = withUnsafeBytes(of: &address.insi_laddr.ina_6) { Array($0) }
                let unspecified = bytes.allSatisfy { $0 == 0 }
                let loopback = bytes.prefix(15).allSatisfy { $0 == 0 } && bytes.last == 1
                host = unspecified || loopback ? "[::1]" : nil
            } else { continue }
            result.append(Listener(port: port, loopbackURL: host.flatMap { URL(string: "http://\($0):\(port)/") }))
        }
        return result
    }
}
