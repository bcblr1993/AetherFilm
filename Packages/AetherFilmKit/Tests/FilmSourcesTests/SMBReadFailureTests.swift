import Foundation
import Darwin
import Testing
import FilmDomain
@testable import FilmSources

@Suite struct SMBReadFailureTests {
    @Test func sourceFailureIsPublishedBeforeClientEOFAndObserverIsSticky() async throws {
        let provider = SMBReadFailureProvider(bytes: Data(repeating: 3, count: 1_048_649), behavior: .failAfter(1, .timedOut))
        let observer = SMBReadFailureObserver()
        let server = makeServer(provider, size: 1_048_649, observer: observer)
        let url = try await server.start()
        let response = try await SMBReadFailureTCPClient.receiveAfterHalfClosingWrite(to: url, range: nil)
        #expect(response.length == 1_048_649 && response.body.count == 524_288)
        #expect(observer.errors == [.timedOut])
        #expect(await server.readFailure() == .timedOut)
        await provider.setBehavior(.normal)
        await #expect(throws: SMBError.timedOut) { try await server.start() }
        #expect(observer.errors.count == 1)
        await server.stop()
        #expect(await server.readFailure() == .timedOut)
    }

    @Test func terminalEarlyEmptyFailsWhileNonemptyShortChunksRemainValid() async throws {
        let bytes = Data(repeating: 17, count: 32_789)
        let short = SMBReadFailureProvider(bytes: bytes, behavior: .shortChunks(777))
        let healthy = makeServer(short, size: Int64(bytes.count))
        let healthyURL = try await healthy.start()
        let full = try await SMBReadFailureTCPClient.receiveAfterHalfClosingWrite(to: healthyURL, range: nil)
        #expect(full.body == bytes)
        #expect(await healthy.readFailure() == nil)
        await healthy.stop()
        let early = SMBReadFailureProvider(bytes: bytes, behavior: .emptyAfter(1))
        let failed = makeServer(early, size: Int64(bytes.count)+1)
        let failedURL = try await failed.start()
        let incomplete = try await SMBReadFailureTCPClient.receiveAfterHalfClosingWrite(to: failedURL, range: nil)
        #expect(incomplete.body == bytes && incomplete.length == bytes.count + 1)
        #expect(await failed.readFailure() == .invalidResponse)
        await failed.stop()
    }

    @Test func realTCPResetWithLateProviderErrorIsConsumerCancellation() async throws {
        let provider = SMBReadFailureProvider(bytes: Data([1, 2, 3]), behavior: .lateError)
        let observer = SMBReadFailureObserver()
        let server = makeServer(provider, size: 3, observer: observer)
        let url = try await server.start()
        let socket = try await SMBReadFailureTCPClient.sendRequest(to: url)
        try await waitForRead(provider)
        try await SMBReadFailureTCPClient.closeWithReset(socket)
        try await Task.sleep(for: .milliseconds(400))
        #expect(await provider.completed == 1)
        #expect(await server.readFailure() == nil && observer.errors.isEmpty)
        await server.stop()
    }

    @Test func explicitStopAndDisposalDoNotPublishSourceFailure() async throws {
        let provider = SMBReadFailureProvider(bytes: Data([1, 2, 3]), behavior: .stall)
        let observer = SMBReadFailureObserver()
        let server = makeServer(provider, size: 3, observer: observer)
        let url = try await server.start()
        let socket = try await SMBReadFailureTCPClient.sendRequest(to: url)
        try await waitForRead(provider)
        await server.stop()
        await SMBReadFailureTCPClient.close(socket)
        #expect(await server.readFailure() == nil && observer.errors.isEmpty)
        let secondProvider = SMBReadFailureProvider(bytes: Data([1, 2, 3]), behavior: .stall)
        var disposable: SMBStreamingServer? = makeServer(secondProvider, size: 3, observer: observer)
        let secondURL = try await #require(disposable).start()
        let secondSocket = try await SMBReadFailureTCPClient.sendRequest(to: secondURL)
        try await waitForRead(secondProvider)
        disposable = nil
        try await Task.sleep(for: .milliseconds(100))
        await SMBReadFailureTCPClient.close(secondSocket)
        #expect(observer.errors.isEmpty)
    }

    @Test func retryUsesFreshStreamAndPreviousFailureCannotTaintNewFilm() async throws {
        let provider = SMBReadFailureProvider(bytes: Data([1, 2, 3]), behavior: .failAfter(0, .permissionDenied))
        let old = makeServer(provider, size: 3)
        let oldURL = try await old.start()
        _ = try await SMBReadFailureTCPClient.receiveAfterHalfClosingWrite(to: oldURL, range: nil)
        #expect(await old.readFailure() == .permissionDenied)
        await old.stop()
        await provider.setBehavior(.normal)
        let next = makeServer(provider, size: 3)
        let nextURL = try await next.start()
        let full = try await SMBReadFailureTCPClient.receiveAfterHalfClosingWrite(to: nextURL, range: nil)
        #expect(full.body == Data([1, 2, 3]))
        #expect(await next.readFailure() == nil)
        #expect(await old.readFailure() == .permissionDenied)
        await next.stop()
    }

    @Test func malformedHTTPAndInvalidRangeNeverPublishSourceFailure() async throws {
        let provider = SMBReadFailureProvider(bytes: Data([1, 2, 3]), behavior: .failAfter(0, .connectionFailed))
        let observer = SMBReadFailureObserver()
        let server = makeServer(provider, size: 3, observer: observer)
        let url = try await server.start()
        let response = try await SMBReadFailureTCPClient.receiveAfterHalfClosingWrite(to: url, range: "bytes=3-")
        #expect(response.status == 416)
        #expect(await provider.calls == 0)
        #expect(await server.readFailure() == nil && observer.errors.isEmpty)
        await server.stop()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["AETHERFILM_SMB_BOOTSTRAP_URL"] != nil))
    func realSMBAuthenticationFailureIsSanitizedAndPublished() async throws {
        guard let bootstrap = ProcessInfo.processInfo.environment["AETHERFILM_SMB_BOOTSTRAP_URL"], let configurationURL = URL(string: bootstrap) else {
            Issue.record("Real isolated SMB fixture bootstrap is required for this diagnostic.")
            return
        }
        let (data, _) = try await URLSession.shared.data(from: configurationURL)
        let fields = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let port = try #require(fields["port"] as? Int)
        let username = try #require(fields["username"] as? String)
        let connection = SMBConnection(name: "Isolated", host: "127.0.0.1", port: port, share: "FILMS")
        let observer = SMBReadFailureObserver()
        let server = SMBStreamingServer(provider: SMBProvider(timeout: 1), connection: connection,
            credentials: SMBCredentials(username: username, password: UUID().uuidString),
            path: "nested/sample.bin", size: 1_048_649, onReadFailure: { observer.record($0) })
        let url = try await server.start()
        let response = try await SMBReadFailureTCPClient.receiveAfterHalfClosingWrite(to: url, range: nil)
        #expect(response.body.isEmpty)
        #expect(await server.readFailure() == .authenticationFailed)
        #expect(observer.errors == [.authenticationFailed])
        await server.stop()
    }

    private func makeServer(_ provider: any SMBFileProviding, size: Int64, observer: SMBReadFailureObserver? = nil) -> SMBStreamingServer {
        SMBStreamingServer(provider: provider,
            connection: SMBConnection(name: "Owned fixture", host: "nas.invalid", share: "media"),
            credentials: SMBCredentials(username: "fixture", password: UUID().uuidString),
            path: "movie.mp4", size: size, onReadFailure: { observer?.record($0) })
    }

    private func waitForRead(_ provider: SMBReadFailureProvider) async throws {
        for _ in 0..<50 {
            if await provider.calls > 0 { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw SMBError.timedOut
    }
}

private final class SMBReadFailureObserver: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [SMBError] = []
    var errors: [SMBError] { lock.withLock { values } }
    func record(_ error: SMBError) { lock.withLock { values.append(error) } }
}

private final class SMBReadCancellationBarrier: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var continuation: CheckedContinuation<Void, Never>?

    func install(_ continuation: CheckedContinuation<Void, Never>) {
        let alreadyCancelled = lock.withLock {
            if cancelled { return true }
            self.continuation = continuation
            return false
        }
        if alreadyCancelled { continuation.resume() }
    }

    func cancel() {
        let waiting = lock.withLock {
            cancelled = true
            defer { continuation = nil }
            return continuation
        }
        waiting?.resume()
    }
}

private actor SMBReadFailureProvider: SMBFileProviding {
    enum Behavior: Sendable {
        case normal, shortChunks(Int), emptyAfter(Int), failAfter(Int, SMBError), lateError, stall
    }
    let bytes: Data
    var behavior: Behavior
    private(set) var calls = 0
    private(set) var completed = 0
    init(bytes: Data, behavior: Behavior) { self.bytes = bytes; self.behavior = behavior }
    func setBehavior(_ behavior: Behavior) { self.behavior = behavior; calls = 0 }
    func testConnection(_ connection: SMBConnection, credentials: SMBCredentials) async throws {}
    func listDirectory(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> [MediaItem] { [] }
    func fileSize(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> Int64 { Int64(bytes.count) }
    func readFile(_ connection: SMBConnection, credentials: SMBCredentials, path: String, range: Range<Int64>) async throws -> Data {
        let index = calls
        calls += 1
        switch behavior {
        case .failAfter(let count, let error) where index >= count: throw error
        case .emptyAfter(let count) where index >= count: return Data()
        case .lateError:
            let cancellation = SMBReadCancellationBarrier()
            // The error must arrive after the real consumer reset cancels this
            // read task, rather than after an unrelated scheduler deadline.
            await withTaskCancellationHandler {
                await withCheckedContinuation { cancellation.install($0) }
            } onCancel: {
                cancellation.cancel()
            }
            completed += 1
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(ECONNRESET), userInfo: [NSLocalizedDescriptionKey: "unsafe endpoint detail"])
        case .stall: try await Task.sleep(for: .seconds(20))
        default: break
        }
        let lower = min(Int(range.lowerBound), bytes.count)
        var upper = min(Int(range.upperBound), bytes.count)
        if case .shortChunks(let count) = behavior { upper = min(upper, lower+count) }
        return bytes.subdata(in: lower..<upper)
    }
}

private enum SMBReadFailureTCPClient {
    struct Response: Sendable {
        let status: Int
        let length: Int
        let header: String
        let body: Data
    }

    // A detached Swift task still occupies the cooperative executor. These
    // bounded BSD socket calls run on GCD so the actor-based server can reply.
    private static let socketQueue = DispatchQueue(label: "com.aethernative.film.tests.read-failure-socket", attributes: .concurrent)

    private static func socketOperation<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            socketQueue.async {
                do { continuation.resume(returning: try operation()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    static func sendRequest(to url: URL, range: String? = nil) async throws -> Int32 {
        try await socketOperation { try sendRequestBlocking(to: url, range: range) }
    }

    static func closeWithReset(_ socket: Int32) async throws {
        try await socketOperation { try closeWithResetBlocking(socket) }
    }

    static func close(_ socket: Int32) async {
        try? await socketOperation { _ = Darwin.close(socket) }
    }

    static func receiveAfterHalfClosingWrite(to url: URL, range: String?) async throws -> Response {
        try await socketOperation { try receiveAfterHalfClosingWriteBlocking(to: url, range: range) }
    }

    private static func sendRequestBlocking(to url: URL, range: String? = nil) throws -> Int32 {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard socket >= 0 else { throw socketError() }
        do {
            var noSIGPIPE: Int32 = 1
            guard setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &noSIGPIPE, socklen_t(MemoryLayout.size(ofValue: noSIGPIPE))) == 0 else {
                throw socketError()
            }
            var timeout = timeval(tv_sec: 3, tv_usec: 0)
            guard setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout))) == 0 else {
                throw socketError()
            }
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            guard let port = url.port else { throw SMBError.invalidResponse }
            address.sin_port = UInt16(port).bigEndian
            guard inet_pton(AF_INET, "127.0.0.1", &address.sin_addr) == 1 else { throw socketError() }
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard result == 0 else { throw socketError() }
            let rangeHeader = range.map { "Range: \($0)\r\n" } ?? ""
            let request = Data("GET \(url.path) HTTP/1.1\r\nHost: 127.0.0.1\r\n\(rangeHeader)Connection: close\r\n\r\n".utf8)
            try request.withUnsafeBytes { bytes in
                var sent = 0
                while sent < bytes.count {
                    let count = Darwin.send(socket, bytes.baseAddress!.advanced(by: sent), bytes.count - sent, 0)
                    guard count > 0 else { throw socketError() }
                    sent += count
                }
            }
            return socket
        } catch { Darwin.close(socket); throw error }
    }

    private static func closeWithResetBlocking(_ socket: Int32) throws {
        defer { Darwin.close(socket) }
        var reset = linger(l_onoff: 1, l_linger: 0)
        guard setsockopt(socket, SOL_SOCKET, SO_LINGER, &reset, socklen_t(MemoryLayout.size(ofValue: reset))) == 0 else {
            throw socketError()
        }
    }

    private static func receiveAfterHalfClosingWriteBlocking(to url: URL, range: String?) throws -> Response {
        let socket = try sendRequestBlocking(to: url, range: range)
        defer { Darwin.close(socket) }
        guard shutdown(socket, SHUT_WR) == 0 else { throw socketError() }
        var received = Data()
        var buffer = [UInt8](repeating: 0, count: 32_768)
        while true {
            let count = recv(socket, &buffer, buffer.count, 0)
            if count > 0 { received.append(contentsOf: buffer.prefix(count)) }
            else if count == 0 { break }
            else if errno != EINTR { throw socketError() }
            guard received.count < 2_097_152 else { throw SMBError.invalidResponse }
        }
        guard let delimiter = received.range(of: Data("\r\n\r\n".utf8)) else { throw SMBError.invalidResponse }
        let header = String(decoding: received[..<delimiter.lowerBound], as: UTF8.self)
        let lines = header.components(separatedBy: "\r\n")
        guard let status = lines.first?.split(separator: " ").dropFirst().first.flatMap({ Int($0) }),
              let length = lines.first(where: { $0.lowercased().hasPrefix("content-length:") })
                .flatMap({ Int($0.dropFirst("Content-Length:".count).trimmingCharacters(in: .whitespaces)) }) else {
            throw SMBError.invalidResponse
        }
        return Response(status: status, length: length, header: header, body: Data(received[delimiter.upperBound...]))
    }

    private static func socketError() -> POSIXError { POSIXError(.init(rawValue: errno) ?? .EIO) }
}
