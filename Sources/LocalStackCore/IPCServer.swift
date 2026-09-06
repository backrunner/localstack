import Darwin
import Foundation
import LocalStackShared
import Synchronization

public final class UnixJSONRPCServer: @unchecked Sendable {
    public typealias Handler = @Sendable (RPCRequest) async -> RPCResponse

    private static let maximumMessageBytes = 1_048_576

    private let socketPath: String
    private let serverFD = Mutex<Int32>(-1)
    private let lifecycleLock = NSLock()
    private let queue = DispatchQueue(label: "localstack.ipc")

    public init(socketPath: String = UnixJSONRPCServer.defaultSocketPath()) {
        self.socketPath = socketPath
    }

    public static func defaultSocketPath() -> String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("LocalStack", isDirectory: true).appendingPathComponent("coordinator.sock").path
    }

    public func start(handler: @escaping Handler) throws {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        signal(SIGPIPE, SIG_IGN)
        guard serverFD.withLock({ $0 < 0 }) else { throw POSIXError(.EALREADY) }

        let directory = URL(fileURLWithPath: socketPath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if directory.lastPathComponent == "LocalStack" {
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }

        if FileManager.default.fileExists(atPath: socketPath) {
            if UnixSocketConnection.canConnect(to: socketPath) {
                throw POSIXError(.EADDRINUSE)
            }
            var fileInfo = stat()
            guard lstat(socketPath, &fileInfo) == 0,
                  (fileInfo.st_mode & S_IFMT) == S_IFSOCK else {
                throw POSIXError(.EEXIST)
            }
            guard unlink(socketPath) == 0 || errno == ENOENT else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var didBind = false
        do {
            var address = try UnixSocketConnection.address(for: socketPath)
            let addressLength = socklen_t(MemoryLayout<sockaddr_un>.size)
            let bound = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, addressLength) }
            }
            guard bound == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            didBind = true
            guard Darwin.listen(fd, 16) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            guard chmod(socketPath, 0o600) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        } catch {
            if didBind { unlink(socketPath) }
            close(fd)
            throw error
        }

        serverFD.withLock { $0 = fd }
        queue.async { [weak self] in self?.acceptConnections(handler: handler) }
    }

    public func stop() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        let fd = serverFD.withLock { state -> Int32 in
            let current = state
            state = -1
            return current
        }
        guard fd >= 0 else { return }
        unlink(socketPath)
        shutdown(fd, SHUT_RDWR)
        close(fd)
    }

    private func acceptConnections(handler: @escaping Handler) {
        while true {
            let fd = serverFD.withLock { $0 }
            guard fd >= 0 else { return }
            let client = accept(fd, nil, nil)
            guard client >= 0 else {
                if errno == EINTR { continue }
                if serverFD.withLock({ $0 < 0 }) { return }
                if errno == EBADF || errno == EINVAL || errno == ENOTSOCK { return }
                usleep(10_000)
                continue
            }

            var noPipe: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noPipe, socklen_t(MemoryLayout<Int32>.size))
            var timeout = timeval(tv_sec: 5, tv_usec: 0)
            setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            var peerUID: uid_t = 0
            var peerGID: gid_t = 0
            guard getpeereid(client, &peerUID, &peerGID) == 0, peerUID == getuid() else {
                close(client)
                continue
            }
            Task { await self.handle(client: client, handler: handler) }
        }
    }

    private func handle(client: Int32, handler: @escaping Handler) async {
        defer { close(client) }
        do {
            let data = try UnixSocketConnection.readRequest(from: client, limit: Self.maximumMessageBytes)
            guard let line = String(data: data, encoding: .utf8), !line.isEmpty else {
                throw CoordinatorError(.invalidRequest, "请求不是 UTF-8 JSON")
            }
            let request = try JSONDecoder.local.decode(RPCRequest.self, from: Data(line.utf8))
            let response = await handler(request)
            try UnixSocketConnection.write(JSONEncoder.local.encode(response) + Data([0x0A]), to: client)
        } catch {
            let response = RPCResponse.failure(id: "unknown", code: CoordinatorErrorCode.invalidRequest.rawValue, message: error.localizedDescription)
            if let data = try? JSONEncoder.local.encode(response) + Data([0x0A]) {
                try? UnixSocketConnection.write(data, to: client)
            }
        }
    }
}

public struct UnixJSONRPCClient: Sendable {
    private static let maximumMessageBytes = 8 * 1_048_576

    public let socketPath: String

    public init(socketPath: String = UnixJSONRPCServer.defaultSocketPath()) {
        self.socketPath = socketPath
    }

    public func status() async throws -> CoordinatorStatus {
        try await call(method: "system.status", params: EmptyParams())
    }

    public func list() async throws -> [ServiceRecord] {
        try await call(method: "service.list", params: EmptyParams())
    }

    public func refresh() async throws {
        let _: OKResponse = try await call(method: "system.refresh", params: EmptyParams())
    }

    public func openTarget(serviceID: UUID) async throws -> URL {
        let response: OpenTargetResponse = try await call(method: "service.openTarget", params: ServiceIDParams(serviceID: serviceID))
        return response.url
    }

    public func prepareTermination(serviceID: UUID) async throws -> TerminationPreview {
        try await call(method: "service.prepareTermination", params: ServiceIDParams(serviceID: serviceID))
    }

    public func terminate(serviceID: UUID, token: String, force: Bool) async throws -> TerminationResult {
        try await call(method: "service.terminate", params: TerminateParams(serviceID: serviceID, token: token, force: force))
    }

    @concurrent
    private func call<Params: Encodable & Sendable, Result: Decodable & Sendable>(method: String, params: Params) async throws -> Result {
        let request = RPCRequest(id: UUID().uuidString, method: method, params: try JSONValue.from(params))
        let fd = try UnixSocketConnection.connect(to: socketPath)
        defer { close(fd) }
        try UnixSocketConnection.write(JSONEncoder.local.encode(request) + Data([0x0A]), to: fd)
        shutdown(fd, SHUT_WR)
        let data = try UnixSocketConnection.readAll(from: fd, limit: Self.maximumMessageBytes)
        let response = try JSONDecoder.local.decode(RPCResponse.self, from: data)
        if let error = response.error {
            throw CoordinatorError(CoordinatorErrorCode(rawValue: error.code) ?? .internalError, error.message)
        }
        guard let result = response.result else {
            throw CoordinatorError(.internalError, "Coordinator 返回了空响应")
        }
        return try result.decode(Result.self)
    }

    private struct EmptyParams: Codable, Sendable {}
    private struct OKResponse: Codable, Sendable { let ok: Bool }
    private struct ServiceIDParams: Codable, Sendable { let serviceID: UUID }
    private struct OpenTargetResponse: Codable, Sendable { let url: URL }
    private struct TerminateParams: Codable, Sendable {
        let serviceID: UUID
        let token: String
        let force: Bool
    }
}

private enum UnixSocketConnection {
    static func address(for path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8CString)
        let pathCapacity = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count <= pathCapacity else { throw POSIXError(.ENAMETOOLONG) }
        withUnsafeMutablePointer(to: &address.sun_path) { pathPointer in
            pathPointer.withMemoryRebound(to: CChar.self, capacity: pathCapacity) { destination in
                pathBytes.withUnsafeBufferPointer { source in
                    _ = memcpy(destination, source.baseAddress!, source.count)
                }
            }
        }
        return address
    }

    static func connect(to path: String) throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var noPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noPipe, socklen_t(MemoryLayout<Int32>.size))
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        do {
            var address = try address(for: path)
            let result = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            return fd
        } catch {
            close(fd)
            throw error
        }
    }

    static func canConnect(to path: String) -> Bool {
        guard let fd = try? connect(to: path) else { return false }
        close(fd)
        return true
    }

    static func readAll(from fd: Int32, limit: Int) throws -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            let count = recv(fd, &buffer, buffer.count, 0)
            if count == 0 { return data }
            if count < 0 {
                if errno == EINTR { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            guard data.count + count <= limit else { throw CoordinatorError(.invalidRequest, "IPC 消息超过大小限制") }
            data.append(buffer, count: count)
        }
    }

    static func readRequest(from fd: Int32, limit: Int) throws -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            let count = recv(fd, &buffer, buffer.count, 0)
            if count == 0 { return data }
            if count < 0 {
                if errno == EINTR { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            guard data.count + count <= limit else { throw CoordinatorError(.invalidRequest, "IPC 消息超过大小限制") }
            if let newline = buffer[..<count].firstIndex(of: 0x0A) {
                data.append(buffer, count: newline)
                return data
            }
            data.append(buffer, count: count)
        }
    }

    static func write(_ data: Data, to fd: Int32) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var written = 0
            while written < rawBuffer.count {
                let count = send(fd, baseAddress.advanced(by: written), rawBuffer.count - written, 0)
                if count < 0 {
                    if errno == EINTR { continue }
                    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                }
                guard count > 0 else { throw POSIXError(.EPIPE) }
                written += count
            }
        }
    }
}

public final class CoordinatorRPCService: Sendable {
    private let coordinator: LocalStackCoordinator
    private let socketPath: String

    public init(coordinator: LocalStackCoordinator, socketPath: String) {
        self.coordinator = coordinator
        self.socketPath = socketPath
    }

    public func handle(_ request: RPCRequest) async -> RPCResponse {
        do {
            switch request.method {
            case "service.list":
                return .success(id: request.id, value: await coordinator.list())
            case "service.register":
                let input = try decode(RegisterParams.self, from: request.params)
                let response = try await coordinator.register(RegistrationRequest(
                    pid: input.pid,
                    port: input.port,
                    url: input.url,
                    displayName: input.displayName,
                    projectRoot: input.projectRoot,
                    source: input.source ?? .sdk
                ))
                return .success(id: request.id, value: response)
            case "service.heartbeat":
                let input = try decode(HeartbeatParams.self, from: request.params)
                let expiry = try await coordinator.heartbeat(registrationID: input.registrationID, token: input.leaseToken)
                return .success(id: request.id, value: ExpiryResponse(expiresAt: expiry))
            case "service.unregister":
                let input = try decode(HeartbeatParams.self, from: request.params)
                try await coordinator.unregister(registrationID: input.registrationID, token: input.leaseToken)
                return .success(id: request.id, value: EmptyResponse(ok: true))
            case "service.openTarget":
                let input = try decode(ServiceIDParams.self, from: request.params)
                let url = try await coordinator.openTarget(serviceID: input.serviceID)
                return .success(id: request.id, value: OpenTargetResponse(url: url))
            case "service.prepareTermination":
                let input = try decode(ServiceIDParams.self, from: request.params)
                return .success(id: request.id, value: try await coordinator.prepareTermination(serviceID: input.serviceID))
            case "service.terminate":
                let input = try decode(TerminateParams.self, from: request.params)
                let result = try await coordinator.terminate(serviceID: input.serviceID, token: input.token, force: input.force ?? false)
                return .success(id: request.id, value: result)
            case "system.status":
                return .success(id: request.id, value: await coordinator.status(socketPath: socketPath))
            case "system.refresh":
                await coordinator.refresh()
                return .success(id: request.id, value: EmptyResponse(ok: true))
            default:
                return .failure(id: request.id, code: CoordinatorErrorCode.invalidRequest.rawValue, message: "未知方法 \(request.method)")
            }
        } catch let error as CoordinatorError {
            return .failure(id: request.id, code: error.code.rawValue, message: error.message)
        } catch {
            return .failure(id: request.id, code: CoordinatorErrorCode.internalError.rawValue, message: error.localizedDescription)
        }
    }

    private struct RegisterParams: Codable {
        let pid: Int32
        let port: Int
        let url: URL?
        let displayName: String?
        let projectRoot: String?
        let source: ServiceSourceKind?
    }

    private struct HeartbeatParams: Codable {
        let registrationID: UUID
        let leaseToken: String
    }

    private struct ServiceIDParams: Codable {
        let serviceID: UUID
    }

    private struct TerminateParams: Codable {
        let serviceID: UUID
        let token: String
        let force: Bool?
    }

    private struct ExpiryResponse: Codable { let expiresAt: Date }
    private struct OpenTargetResponse: Codable { let url: URL }
    private struct EmptyResponse: Codable { let ok: Bool }

    private func decode<T: Decodable>(_ type: T.Type, from value: JSONValue?) throws -> T {
        guard let value else { throw CoordinatorError(.invalidRequest, "缺少请求参数") }
        return try value.decode(type)
    }
}
