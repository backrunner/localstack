import Foundation

public enum ServiceSourceKind: String, Codable, CaseIterable, Sendable {
    case discovered
    case sdk
    case unplugin
    case mcp
}

public enum ServiceHealth: String, Codable, Sendable {
    case active
    case degraded
}

public struct ProcessFingerprint: Codable, Hashable, Sendable {
    public let pid: Int32
    public let uid: UInt32
    public let startTime: Date

    public init(pid: Int32, uid: UInt32, startTime: Date) {
        self.pid = pid
        self.uid = uid
        self.startTime = startTime
    }
}

public struct ValidationEvidence: Codable, Hashable, Sendable {
    public let checkedURL: URL
    public let finalURL: URL
    public let statusCode: Int
    public let contentType: String?
    public let title: String?
    public let faviconURL: URL?
    public let checkedAt: Date

    public init(
        checkedURL: URL,
        finalURL: URL,
        statusCode: Int,
        contentType: String?,
        title: String?,
        faviconURL: URL? = nil,
        checkedAt: Date = .now
    ) {
        self.checkedURL = checkedURL
        self.finalURL = finalURL
        self.statusCode = statusCode
        self.contentType = contentType
        self.title = title
        self.faviconURL = faviconURL
        self.checkedAt = checkedAt
    }
}

public struct ServiceRecord: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let port: Int
    public var url: URL
    public let process: ProcessFingerprint
    public var displayName: String
    public var projectRoot: String?
    public var title: String?
    public var faviconURL: URL?
    public var health: ServiceHealth
    public var sources: Set<ServiceSourceKind>
    public var validation: ValidationEvidence
    public var firstSeenAt: Date
    public var lastSeenAt: Date
    public var lastHealthyAt: Date
    public var consecutiveFailures: Int

    public init(
        id: UUID = UUID(),
        port: Int,
        url: URL,
        process: ProcessFingerprint,
        displayName: String,
        projectRoot: String? = nil,
        validation: ValidationEvidence,
        source: ServiceSourceKind,
        now: Date = .now
    ) {
        self.id = id
        self.port = port
        self.url = url
        self.process = process
        self.displayName = displayName
        self.projectRoot = projectRoot
        self.title = validation.title
        self.faviconURL = validation.faviconURL
        self.health = .active
        self.sources = [source]
        self.validation = validation
        self.firstSeenAt = now
        self.lastSeenAt = now
        self.lastHealthyAt = now
        self.consecutiveFailures = 0
    }

    public var endpointKey: String {
        "127.0.0.1:\(port)"
    }

    public var sourceLabel: String {
        if sources.contains(.unplugin) { return "unplugin" }
        if sources.contains(.sdk) { return "SDK" }
        if sources.contains(.mcp) { return "MCP" }
        return "自动探测"
    }
}

public struct ServiceWidgetSnapshot: Codable, Hashable, Sendable {
    public let generatedAt: Date
    public let services: [WidgetService]

    public init(generatedAt: Date = .now, services: [WidgetService]) {
        self.generatedAt = generatedAt
        self.services = services
    }
}

public struct WidgetService: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let displayName: String
    public let url: URL
    public let health: ServiceHealth
    public let sourceLabel: String

    public init(from service: ServiceRecord) {
        self.id = service.id
        self.displayName = service.displayName
        self.url = service.url
        self.health = service.health
        self.sourceLabel = service.sourceLabel
    }
}

public struct RegistrationRequest: Codable, Sendable {
    public let pid: Int32
    public let port: Int
    public let url: URL?
    public let displayName: String?
    public let projectRoot: String?
    public let source: ServiceSourceKind

    public init(
        pid: Int32,
        port: Int,
        url: URL? = nil,
        displayName: String? = nil,
        projectRoot: String? = nil,
        source: ServiceSourceKind = .sdk
    ) {
        self.pid = pid
        self.port = port
        self.url = url
        self.displayName = displayName
        self.projectRoot = projectRoot
        self.source = source
    }
}

public struct RegistrationResponse: Codable, Sendable {
    public let service: ServiceRecord
    public let registrationID: UUID
    public let leaseToken: String
    public let leaseExpiresAt: Date

    public init(service: ServiceRecord, registrationID: UUID, leaseToken: String, leaseExpiresAt: Date) {
        self.service = service
        self.registrationID = registrationID
        self.leaseToken = leaseToken
        self.leaseExpiresAt = leaseExpiresAt
    }
}

public struct TerminationPreview: Codable, Sendable {
    public let serviceID: UUID
    public let token: String
    public let displayName: String
    public let url: URL
    public let pid: Int32
    public let executableName: String
    public let expiresAt: Date
    public let process: ProcessFingerprint?
    public let listeningPorts: [Int]?
    public let affectedServiceIDs: [UUID]?

    public init(serviceID: UUID, token: String, displayName: String, url: URL, pid: Int32, executableName: String, expiresAt: Date,
                process: ProcessFingerprint? = nil, listeningPorts: [Int]? = nil, affectedServiceIDs: [UUID]? = nil) {
        self.serviceID = serviceID
        self.token = token
        self.displayName = displayName
        self.url = url
        self.pid = pid
        self.executableName = executableName
        self.expiresAt = expiresAt
        self.process = process
        self.listeningPorts = listeningPorts
        self.affectedServiceIDs = affectedServiceIDs
    }
}

public struct TerminationResult: Codable, Sendable {
    public let serviceID: UUID
    public let signal: Int32
    public let exited: Bool
    public let listenersClosed: Bool?
    public let removedServiceIDs: [UUID]?
    public let forcePreview: TerminationPreview?

    public init(serviceID: UUID, signal: Int32, exited: Bool, listenersClosed: Bool? = nil,
                removedServiceIDs: [UUID]? = nil, forcePreview: TerminationPreview? = nil) {
        self.serviceID = serviceID
        self.signal = signal
        self.exited = exited
        self.listenersClosed = listenersClosed
        self.removedServiceIDs = removedServiceIDs
        self.forcePreview = forcePreview
    }
}

public struct CoordinatorStatus: Codable, Sendable {
    public let version: String
    public let socketPath: String
    public let serviceCount: Int
    public let lastScanAt: Date?

    public init(version: String, socketPath: String, serviceCount: Int, lastScanAt: Date?) {
        self.version = version
        self.socketPath = socketPath
        self.serviceCount = serviceCount
        self.lastScanAt = lastScanAt
    }
}

public enum CoordinatorErrorCode: String, Codable, Sendable {
    case invalidRequest
    case notFound
    case notCurrentUser
    case processUnavailable
    case portUnavailable
    case pageUnavailable
    case notBrowsablePage
    case outsideLoopback
    case staleProcess
    case staleTerminationToken
    case terminationRejected
    case internalError
}

public struct CoordinatorError: Error, Codable, LocalizedError, Sendable {
    public let code: CoordinatorErrorCode
    public let message: String

    public init(_ code: CoordinatorErrorCode, _ message: String) {
        self.code = code
        self.message = message
    }

    public var errorDescription: String? { message }
}
