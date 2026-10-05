import Foundation

/// Identifies endpoints from a live process snapshot, never from a port blacklist.
enum DevelopmentEndpointDetection {
    private struct Binding {
        let name: String
        let host: String
        let port: Int

        var isInternal: Bool { ["entry", "debug", "inspector"].contains(name) }

        init?(name: String, address: String) {
            guard let url = URLComponents(string: "http://\(address)"),
                  let host = url.host?.lowercased(), let port = url.port,
                  (0...65535).contains(port), url.user == nil, url.password == nil,
                  url.path.isEmpty, url.query == nil, url.fragment == nil,
                  ["localhost", "127.0.0.1", "0.0.0.0", "::1", "[::1]", "::", "[::]"].contains(host) else { return nil }
            self.name = name
            self.host = host
            self.port = port
        }

        func matches(_ listener: ProcessSockets.Listener) -> Bool {
            guard let listenerHost = listener.loopbackURL?.host,
                  port == 0 || port == listener.port else { return false }
            if host == "localhost" { return true }
            let ipv6 = host.contains(":")
            return ipv6 == listenerHost.contains(":")
        }
    }

    static func isInternal(
        executable: String, arguments: [String], candidate: PortCandidate,
        listeners: [ProcessSockets.Listener]
    ) -> Bool {
        let flags = Array(arguments.dropFirst())
        guard executable == "workerd", flags.first == "serve", flags.contains("--binary"), flags.contains("-"),
              flags.contains(where: { $0.hasPrefix("--control-fd=") && Int($0.dropFirst("--control-fd=".count)).map { $0 > 0 } == true }),
              flags.contains(where: {
                  let prefix = "--external-addr=loopback="
                  guard $0.hasPrefix(prefix), let binding = Binding(name: "loopback", address: String($0.dropFirst(prefix.count))) else { return false }
                  return binding.port > 0 && !["0.0.0.0", "::", "[::]"].contains(binding.host)
              }) else { return false }

        var bindings: [Binding] = []
        for flag in flags {
            let name: String
            let address: String
            if flag.hasPrefix("--socket-addr=") {
                let parts = flag.dropFirst("--socket-addr=".count).split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { return false }
                name = String(parts[0]); address = String(parts[1])
            } else if flag.hasPrefix("--debug-port=") {
                name = "debug"; address = String(flag.dropFirst("--debug-port=".count))
            } else if flag.hasPrefix("--inspector-addr=") {
                name = "inspector"; address = String(flag.dropFirst("--inspector-addr=".count))
            } else { continue }
            guard let binding = Binding(name: name, address: address), !bindings.contains(where: { $0.name == name }) else { return false }
            bindings.append(binding)
        }
        guard bindings.contains(where: { $0.name == "entry" }),
              let listener = listeners.first(where: { $0.port == candidate.port && $0.loopbackURL == candidate.url }),
              !bindings.contains(where: { !$0.isInternal && $0.matches(listener) }) else { return false }

        // An explicit bind identifies this endpoint even if the process has other
        // sockets. Ephemeral binds need an unambiguous complete listener snapshot.
        if bindings.contains(where: { $0.isInternal && $0.port > 0 && $0.matches(listener) }) { return true }
        guard bindings.allSatisfy(\.isInternal), bindings.count <= 8, listeners.count == bindings.count else { return false }
        return canAssign(listeners[...], to: bindings)
    }

    private static func canAssign(_ listeners: ArraySlice<ProcessSockets.Listener>, to bindings: [Binding]) -> Bool {
        guard let listener = listeners.first else { return true }
        for index in bindings.indices where bindings[index].matches(listener) {
            var remaining = bindings
            remaining.remove(at: index)
            if canAssign(listeners.dropFirst(), to: remaining) { return true }
        }
        return false
    }
}
