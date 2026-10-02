import Foundation
import FilmDomain
import AMSMB2

public enum SMBError: Error, LocalizedError, Equatable, Sendable {
    case authenticationFailed, permissionDenied, notFound, timedOut, connectionFailed, invalidResponse
    case encryptedConnectionFailed, encryptedShareDiscoveryUnavailable

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed: "登录 NAS 失败，请检查用户名、密码和域。"
        case .permissionDenied: "没有权限访问这个 NAS 目录。"
        case .notFound: "NAS 文件或共享目录不存在。"
        case .timedOut: "NAS 响应超时，请检查网络后重试。"
        case .connectionFailed: "无法连接 NAS，请检查服务器和网络。"
        case .invalidResponse: "NAS 返回了无法读取的文件信息。"
        case .encryptedConnectionFailed: "无法建立加密 SMB 连接，请检查登录信息和网络，并确认 NAS 支持 SMB3 加密。"
        case .encryptedShareDiscoveryUnavailable: "加密连接请手动填写共享目录，暂不支持自动发现共享。"
        }
    }

    static func sanitized(_ error: any Error, authenticating: Bool = false) -> any Error {
        if error is CancellationError { return CancellationError() }
        if let error = error as? SMBError { return error }
        if let error = error as? FilmError { return error }
        let value = error as NSError
        if value.domain == NSPOSIXErrorDomain {
            switch value.code {
            case Int(EACCES), Int(EPERM): return authenticating ? SMBError.authenticationFailed : SMBError.permissionDenied
            case Int(ENOENT), Int(ENOTDIR): return SMBError.notFound
            case Int(ETIMEDOUT): return SMBError.timedOut
            default: break
            }
        }
        if value.domain == NSURLErrorDomain && value.code == NSURLErrorTimedOut { return SMBError.timedOut }
        // Raw protocol error descriptions can contain endpoint or credential details.
        return SMBError.connectionFailed
    }
}

public struct SMBShare: Equatable, Sendable {
    public let name: String
    public let comment: String
    public init(name: String, comment: String = "") { self.name = name; self.comment = comment }
}

public struct SMBEntry: Equatable, Sendable {
    public let name: String
    public let isDirectory: Bool
    public let size: Int64?
    public let modifiedAt: Date?
    public init(name: String, isDirectory: Bool, size: Int64? = nil, modifiedAt: Date? = nil) {
        self.name = name; self.isDirectory = isDirectory; self.size = size; self.modifiedAt = modifiedAt
    }
}

/// The adapter exposes read-only operations; removing a library item cannot mutate a NAS.
public protocol SMBTransport: Sendable {
    func connect(share: String) async throws
    func listShares() async throws -> [SMBShare]
    func listDirectory(path: String) async throws -> [SMBEntry]
    func fileSize(path: String) async throws -> Int64
    func read(path: String, range: Range<Int64>) async throws -> Data
}

public actor SMBProvider: SMBFileProviding {
    public typealias TransportFactory = @Sendable (SMBConnection, SMBCredentials) throws -> any SMBTransport
    public static let maximumReadSize: Int64 = 16 * 1_024 * 1_024

    private struct Session {
        let id: UUID
        let connection: SMBConnection
        let credentials: SMBCredentials
        let transport: any SMBTransport
        var lastUsed: UInt64

        func matches(_ connection: SMBConnection, _ credentials: SMBCredentials) -> Bool {
            self.connection == connection && self.credentials.username == credentials.username
                && self.credentials.domain == credentials.domain && self.credentials.password == credentials.password
        }
    }

    private let factory: TransportFactory
    private var sessions: [UUID: Session] = [:]
    private var usageCounter: UInt64 = 0

    public init(timeout: TimeInterval = 12) {
        factory = { connection, credentials in
            try AMSMB2Transport(connection: connection, credentials: credentials, timeout: timeout)
        }
    }

    public init(transportFactory: @escaping TransportFactory) { self.factory = transportFactory }

    public func testConnection(_ connection: SMBConnection, credentials: SMBCredentials) async throws {
        let path = try checkedPath(connection.rootPath, connection: connection)
        _ = try await listDirectory(connection, credentials: credentials, path: path)
    }

    public func listShares(_ connection: SMBConnection, credentials: SMBCredentials) async throws -> [SMBShare] {
        // AMSMB2's share enumeration creates its own unencrypted IPC connection.
        // Do not perform that operation when the user requires encrypted transport.
        guard !connection.requireEncryption else { throw SMBError.encryptedShareDiscoveryUnavailable }
        var endpoint = connection
        endpoint.share = "IPC$"
        _ = try endpoint.validated()
        try Task.checkCancellation()
        let transport = try factory(endpoint, credentials)
        do {
            let shares = try await transport.listShares()
            try Task.checkCancellation()
            return shares.filter { !$0.name.isEmpty && !$0.name.hasSuffix("$") }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch { throw SMBError.sanitized(error, authenticating: true) }
    }

    public func listDirectory(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> [MediaItem] {
        let path = try checkedPath(path, connection: connection)
        return try await perform(connection, credentials: credentials) { transport in
            let entries = try await transport.listDirectory(path: path)
            try Task.checkCancellation()
            return try MediaFormats.sorted(entries.map { entry in
                let entryPath = try SMBPath.joining(path, entry.name)
                guard entry.size.map({ $0 >= 0 }) ?? true else { throw SMBError.invalidResponse }
                return MediaItem(name: entry.name, path: entryPath, sourceID: connection.id,
                                 isDirectory: entry.isDirectory, size: entry.size, modifiedAt: entry.modifiedAt)
            })
        }
    }

    public func fileSize(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> Int64 {
        let path = try checkedPath(path, connection: connection)
        return try await perform(connection, credentials: credentials) { transport in
            let size = try await transport.fileSize(path: path)
            guard size >= 0 else { throw SMBError.invalidResponse }
            return size
        }
    }

    public func readFile(_ connection: SMBConnection, credentials: SMBCredentials, path: String, range: Range<Int64>) async throws -> Data {
        let path = try checkedPath(path, connection: connection)
        guard range.lowerBound >= 0, range.upperBound >= range.lowerBound,
              range.upperBound - range.lowerBound <= Self.maximumReadSize else { throw FilmError.invalidRange }
        if range.isEmpty { return Data() }
        return try await perform(connection, credentials: credentials) { transport in
            let data = try await transport.read(path: path, range: range)
            guard Int64(data.count) <= range.upperBound - range.lowerBound else { throw SMBError.invalidResponse }
            return data
        }
    }

    /// Eviction drops our ownership. In-flight callbacks keep their context alive until completion.
    public func forgetConnection(_ sourceID: UUID) { sessions.removeValue(forKey: sourceID) }
    public func close() { sessions.removeAll() }

    private func checkedPath(_ path: String, connection: SMBConnection) throws -> String {
        _ = try connection.validated()
        let canonical = try SMBPath.normalized(path)
        guard try SMBPath.isWithin(canonical, root: connection.rootPath) else { throw FilmError.invalidPath }
        return canonical
    }

    private func perform<T: Sendable>(_ connection: SMBConnection, credentials: SMBCredentials,
                                     operation: @Sendable (any SMBTransport) async throws -> T) async throws -> T {
        try Task.checkCancellation()
        usageCounter &+= 1
        var session: Session
        if let existing = sessions[connection.id], existing.matches(connection, credentials) {
            session = existing
            session.lastUsed = usageCounter
        } else {
            let transport = try factory(connection, credentials)
            session = Session(id: UUID(), connection: connection, credentials: credentials, transport: transport, lastUsed: usageCounter)
        }
        sessions[connection.id] = session
        if sessions.count > 8, let oldest = sessions.min(by: { $0.value.lastUsed < $1.value.lastUsed })?.key {
            sessions.removeValue(forKey: oldest)
        }
        do {
            try await session.transport.connect(share: connection.share)
            try Task.checkCancellation()
            let result = try await operation(session.transport)
            try Task.checkCancellation()
            return result
        } catch {
            // A cancelled or failed context is not reused for a retry.
            if sessions[connection.id]?.id == session.id { sessions.removeValue(forKey: connection.id) }
            throw SMBError.sanitized(error)
        }
    }
}

private final class AMSMB2Transport: SMBTransport, @unchecked Sendable {
    private let manager: SMB2Manager
    private let requireEncryption: Bool
    private let lock = NSLock()
    private var connectedShare: String?

    init(connection: SMBConnection, credentials: SMBCredentials, timeout: TimeInterval) throws {
        guard let endpoint = connection.endpoint,
              let manager = SMB2Manager(url: endpoint, domain: credentials.domain,
                                        credential: URLCredential(user: credentials.username.isEmpty ? "guest" : credentials.username,
                                                                  password: credentials.password, persistence: .forSession)) else {
            throw FilmError.invalidConnection
        }
        manager.timeout = max(1, min(timeout.isFinite ? timeout : 12, 60))
        self.manager = manager
        self.requireEncryption = connection.requireEncryption
    }

    func connect(share: String) async throws {
        if lock.withLock({ connectedShare == share }) { return }
        let _: Bool = try await SMBOperation.run { completion, _ in
            self.manager.connectShare(name: share, encrypted: self.requireEncryption) { error in
                if let error {
                    let sanitized = SMBError.sanitized(error, authenticating: true)
                    // libsmb2 also reports EACCES for unsupported encrypted tree connections,
                    // so encryption failures cannot be distinguished from rejected credentials here.
                    if self.requireEncryption, sanitized is SMBError {
                        completion(.failure(SMBError.encryptedConnectionFailed))
                    } else { completion(.failure(sanitized)) }
                }
                else { completion(.success(true)) }
            }
        }
        lock.withLock { connectedShare = share }
    }

    func listShares() async throws -> [SMBShare] {
        try await SMBOperation.run { completion, _ in
            self.manager.listShares { result in
                completion(result.map { $0.map { SMBShare(name: $0.name, comment: $0.comment) } }
                    .mapError { SMBError.sanitized($0, authenticating: true) })
            }
        }
    }

    func listDirectory(path: String) async throws -> [SMBEntry] {
        try await SMBOperation.run { completion, _ in
            self.manager.contentsOfDirectory(atPath: path) { result in
                completion(result.flatMap { dictionaries in
                    Result {
                        try dictionaries.compactMap { values in
                            guard let name = values[.nameKey] as? String,
                                  let type = values[.fileResourceTypeKey] as? URLFileResourceType else { throw SMBError.invalidResponse }
                            // Symbolic links returned by the server are not exposed as navigable items.
                            guard type == .directory || type == .regular else { return nil }
                            return SMBEntry(name: name, isDirectory: type == .directory,
                                            size: Self.size(in: values), modifiedAt: values[.contentModificationDateKey] as? Date)
                        }
                    }
                }.mapError { SMBError.sanitized($0) })
            }
        }
    }

    func fileSize(path: String) async throws -> Int64 {
        try await SMBOperation.run { completion, _ in
            self.manager.attributesOfItem(atPath: path) { result in
                completion(result.flatMap { values in
                    Result {
                        guard values[.fileResourceTypeKey] as? URLFileResourceType == .regular,
                              let size = Self.size(in: values), size >= 0 else { throw SMBError.invalidResponse }
                        return size
                    }
                }.mapError { SMBError.sanitized($0) })
            }
        }
    }

    func read(path: String, range: Range<Int64>) async throws -> Data {
        try await SMBOperation.run { completion, isCancelled in
            self.manager.contents(atPath: path, range: range, progress: { _, _ in !isCancelled() }) { result in
                completion(result.mapError { SMBError.sanitized($0) })
            }
        }
    }

    private static func size(in values: [URLResourceKey: any Sendable]) -> Int64? {
        if let value = values[.fileSizeKey] as? Int64 { return value }
        if let value = values[.fileSizeKey] as? Int { return Int64(value) }
        if let value = values[.fileSizeKey] as? NSNumber { return value.int64Value }
        return nil
    }
}

/// Cancellation resumes the caller once and signals progress callbacks without destroying active C contexts.
private final class SMBOperation<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?
    private var cancelled = false
    private var finished = false

    static func run(_ start: @escaping @Sendable (@escaping @Sendable (Result<Value, any Error>) -> Void,
                                                  @escaping @Sendable () -> Bool) -> Void) async throws -> Value {
        let operation = SMBOperation<Value>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let shouldStart = operation.lock.withLock {
                    if operation.cancelled { return false }
                    operation.continuation = continuation
                    return true
                }
                guard shouldStart else { continuation.resume(throwing: CancellationError()); return }
                start({ operation.finish($0) }, { operation.lock.withLock { operation.cancelled } })
            }
        } onCancel: { operation.cancel() }
    }

    private func finish(_ result: Result<Value, any Error>) {
        let continuation = lock.withLock {
            guard !finished else { return Optional<CheckedContinuation<Value, any Error>>.none }
            finished = true
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(with: result)
    }

    private func cancel() {
        let continuation = lock.withLock {
            cancelled = true
            guard !finished else { return Optional<CheckedContinuation<Value, any Error>>.none }
            finished = true
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(throwing: CancellationError())
    }
}
