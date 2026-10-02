import Foundation
@preconcurrency import Network
import FilmDomain

/// Bridges authenticated SMB reads to a private loopback HTTP Range stream understood by both playback backends.
public actor SMBStreamingServer {
    private let provider: any SMBFileProviding
    private let connection: SMBConnection
    private let credentials: SMBCredentials
    private let path: String
    private let size: Int64
    private let queue = DispatchQueue(label: "com.aethernative.film.smb-stream")
    private let route: String
    private let mimeType: String
    private var listener: NWListener?
    private var startTask: Task<URL, any Error>?
    private var sessions: [UUID: (NWConnection, Task<Void, Never>)] = [:]
    private var generation = UUID()

    public init(provider: any SMBFileProviding, connection: SMBConnection, credentials: SMBCredentials,
                path: String, size: Int64) {
        self.provider = provider; self.connection = connection; self.credentials = credentials
        self.path = path; self.size = size
        let fileExtension = (path as NSString).pathExtension.lowercased()
        let safeExtension = fileExtension.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        route = "/" + UUID().uuidString + (safeExtension.isEmpty ? "" : "." + safeExtension)
        mimeType = Self.contentType(for: fileExtension)
    }

    deinit {
        listener?.cancel()
        startTask?.cancel()
        for (connection, task) in sessions.values {
            task.cancel()
            connection.cancel()
        }
    }

    public func start() async throws -> URL {
        if let startTask { return try await startTask.value }
        guard size >= 0 else { throw FilmError.invalidRange }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters, on: .any)
        let generation = self.generation
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            Task { await self?.accept(connection, generation: generation) }
        }
        let queue = self.queue, route = self.route
        let task = Task<URL, any Error> {
            try await withSMBDeadline(seconds: 5) {
                try await SMBNetworkWait.run(cancel: { listener.cancel() }) { completion in
                    listener.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            guard let port = listener.port,
                                  let url = URL(string: "http://127.0.0.1:\(port.rawValue)\(route)") else {
                                completion(.failure(SMBError.connectionFailed)); return
                            }
                            completion(.success(url))
                        case .failed: completion(.failure(SMBError.connectionFailed))
                        case .cancelled: completion(.failure(CancellationError()))
                        default: break
                        }
                    }
                    listener.start(queue: queue)
                }
            }
        }
        startTask = task
        do {
            return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
        } catch {
            listener.cancel()
            if self.generation == generation { self.listener = nil; startTask = nil }
            throw error
        }
    }

    public func stop() async {
        generation = UUID()
        listener?.cancel(); listener = nil
        startTask?.cancel(); startTask = nil
        let active = Array(sessions.values)
        sessions.removeAll()
        for (connection, task) in active { task.cancel(); connection.cancel() }
        for (_, task) in active { await task.value }
    }

    private func accept(_ client: NWConnection, generation: UUID) {
        guard generation == self.generation, listener != nil, sessions.count < 8 else { client.cancel(); return }
        let id = UUID()
        client.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                Task { await self?.cancelSession(id) }
            default: break
            }
        }
        client.start(queue: queue)
        let provider = self.provider, connection = self.connection, credentials = self.credentials
        let path = self.path, size = self.size, route = self.route, mimeType = self.mimeType
        let task = Task { [weak self] in
            await Self.serve(client, provider: provider, connection: connection, credentials: credentials,
                             path: path, size: size, route: route, mimeType: mimeType,
                             onConsumerClosed: { [weak self] in Task { await self?.cancelSession(id) } })
            client.cancel()
            await self?.finished(id)
        }
        sessions[id] = (client, task)
    }

    private func finished(_ id: UUID) { sessions.removeValue(forKey: id) }

    private func cancelSession(_ id: UUID) {
        guard let (client, task) = sessions.removeValue(forKey: id) else { return }
        task.cancel()
        client.cancel()
    }

    private nonisolated static func serve(_ client: NWConnection, provider: any SMBFileProviding,
                                         connection: SMBConnection, credentials: SMBCredentials,
                                         path: String, size: Int64, route: String, mimeType: String,
                                         onConsumerClosed: @escaping @Sendable () -> Void) async {
        var headersSent = false
        do {
            let request: SMBHTTPRequest
            do { request = try SMBHTTPRequest(data: await client.readHTTPHeader()) }
            catch {
                try await client.sendHTTP(SMBHTTPResponse(status: 400, length: 0).data)
                return
            }
            guard request.target == route else {
                try await client.sendHTTP(SMBHTTPResponse(status: 404, length: 0).data); return
            }
            guard request.method == "GET" || request.method == "HEAD" else {
                try await client.sendHTTP(SMBHTTPResponse(status: 405, length: 0, extraHeaders: ["Allow": "GET, HEAD"]).data)
                return
            }
            // RFC 9112 § 9.6: a client write half-close does not abandon the response.
            // Only transport errors cancel consumption; stop/deinit and write failures also release reads.
            client.receive(minimumIncompleteLength: 1, maximumLength: 1) { _, _, _, error in
                if error != nil { onConsumerClosed() }
            }
            // HTTP Range is defined for GET. HEAD describes the complete representation.
            let rangeHeader = request.method == "GET" ? request.range : nil
            if size == 0 && rangeHeader == nil {
                try await client.sendHTTP(SMBHTTPResponse(status: 200, length: 0, contentType: mimeType).data); return
            }
            let range: ByteRange
            do { range = try ByteRange(header: rangeHeader, size: size) }
            catch {
                try await client.sendHTTP(SMBHTTPResponse(status: 416, length: 0,
                                                         extraHeaders: ["Content-Range": "bytes */\(size)"]).data)
                return
            }
            var extraHeaders: [String: String] = [:]
            if rangeHeader != nil { extraHeaders["Content-Range"] = "bytes \(range.lowerBound)-\(range.upperBound)/\(size)" }
            let response = SMBHTTPResponse(status: rangeHeader == nil ? 200 : 206, length: range.length,
                                           contentType: mimeType, extraHeaders: extraHeaders)
            try await client.sendHTTP(response.data)
            headersSent = true
            guard request.method == "GET" else { return }
            var offset = range.lowerBound
            let end = range.upperBound + 1
            while offset < end {
                try Task.checkCancellation()
                let chunkEnd = offset + min(512 * 1_024, end - offset)
                let data = try await provider.readFile(connection, credentials: credentials, path: path, range: offset..<chunkEnd)
                guard !data.isEmpty, Int64(data.count) <= chunkEnd - offset else { throw SMBError.invalidResponse }
                try await client.sendHTTP(data)
                offset += Int64(data.count)
            }
        } catch {
            if !headersSent, !Task.isCancelled {
                try? await client.sendHTTP(SMBHTTPResponse(status: 502, length: 0).data)
            }
        }
    }

    private nonisolated static func contentType(for fileExtension: String) -> String {
        switch fileExtension {
        case "mp4", "m4v": "video/mp4"
        case "mov": "video/quicktime"
        case "mkv": "video/x-matroska"
        case "webm": "video/webm"
        case "ts", "m2ts": "video/mp2t"
        case "avi": "video/x-msvideo"
        default: "application/octet-stream"
        }
    }
}

struct SMBHTTPRequest: Equatable, Sendable {
    let method: String
    let target: String
    let range: String?

    init(data: Data) throws {
        guard data.count <= 16 * 1_024, let header = String(data: data, encoding: .utf8),
              header.hasSuffix("\r\n\r\n") else { throw SMBError.invalidResponse }
        let lines = header.components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ", omittingEmptySubsequences: false)
        guard requestLine.count == 3, requestLine[2] == "HTTP/1.1" || requestLine[2] == "HTTP/1.0",
              requestLine[1].hasPrefix("/"), !requestLine[0].isEmpty else { throw SMBError.invalidResponse }
        method = String(requestLine[0]); target = String(requestLine[1])
        var range: String?
        for line in lines.dropFirst() where !line.isEmpty {
            guard !line.hasPrefix(" "), !line.hasPrefix("\t"), let separator = line.firstIndex(of: ":") else {
                throw SMBError.invalidResponse
            }
            let key = line[..<separator].lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            if key == "range" {
                guard range == nil else { throw FilmError.invalidRange }
                range = value
            }
        }
        self.range = range
    }
}

struct SMBHTTPResponse: Sendable {
    let status: Int
    let length: Int64
    var contentType: String = "application/octet-stream"
    var extraHeaders: [String: String] = [:]

    var data: Data {
        let phrase: String
        switch status {
        case 200: phrase = "OK"
        case 206: phrase = "Partial Content"
        case 400: phrase = "Bad Request"
        case 404: phrase = "Not Found"
        case 405: phrase = "Method Not Allowed"
        case 416: phrase = "Range Not Satisfiable"
        default: phrase = "Bad Gateway"
        }
        var headers = ["Content-Length": String(length), "Content-Type": contentType,
                       "Accept-Ranges": "bytes", "Connection": "close", "Cache-Control": "no-store"]
        headers.merge(extraHeaders) { _, new in new }
        let text = "HTTP/1.1 \(status) \(phrase)\r\n" + headers.sorted(by: { $0.key < $1.key })
            .map { "\($0.key): \($0.value)\r\n" }.joined() + "\r\n"
        return Data(text.utf8)
    }
}

private extension NWConnection {
    func readHTTPHeader() async throws -> Data {
        try await withSMBDeadline(seconds: 10) {
            var accumulated = Data()
            let terminator = Data("\r\n\r\n".utf8)
            while accumulated.count <= 16 * 1_024 {
                let chunk: Data = try await SMBNetworkWait.run(cancel: { self.cancel() }) { completion in
                    self.receive(minimumIncompleteLength: 1, maximumLength: 4 * 1_024) { data, _, complete, error in
                        if error != nil { completion(.failure(SMBError.connectionFailed)) }
                        else if let data, !data.isEmpty { completion(.success(data)) }
                        else if complete { completion(.failure(SMBError.connectionFailed)) }
                        else { completion(.success(Data())) }
                    }
                }
                accumulated.append(chunk)
                if let range = accumulated.range(of: terminator) {
                    return accumulated.subdata(in: 0..<range.upperBound)
                }
            }
            throw SMBError.invalidResponse
        }
    }

    func sendHTTP(_ data: Data) async throws {
        let _: Bool = try await withSMBDeadline(seconds: 15) {
            try await SMBNetworkWait.run(cancel: { self.cancel() }) { completion in
                self.send(content: data, completion: .contentProcessed { error in
                    if error != nil { completion(.failure(SMBError.connectionFailed)) }
                    else { completion(.success(true)) }
                })
            }
        }
    }
}

private func withSMBDeadline<Value: Sendable>(seconds: Int, operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask { try await operation() }
        group.addTask { try await Task.sleep(for: .seconds(seconds)); throw SMBError.timedOut }
        defer { group.cancelAll() }
        guard let value = try await group.next() else { throw CancellationError() }
        return value
    }
}

private final class SMBNetworkWait<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?
    private var cancelled = false
    private var finished = false

    static func run(cancel: @escaping @Sendable () -> Void,
                    start: @escaping @Sendable (@escaping @Sendable (Result<Value, any Error>) -> Void) -> Void) async throws -> Value {
        let wait = SMBNetworkWait<Value>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let shouldStart = wait.lock.withLock {
                    guard !wait.cancelled else { return false }
                    wait.continuation = continuation
                    return true
                }
                guard shouldStart else { continuation.resume(throwing: CancellationError()); return }
                start { wait.finish($0) }
            }
        } onCancel: {
            wait.lock.withLock { wait.cancelled = true }
            wait.finish(.failure(CancellationError()))
            cancel()
        }
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
}
