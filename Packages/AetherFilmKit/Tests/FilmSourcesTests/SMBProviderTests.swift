import Foundation
import Testing
import FilmDomain
@testable import FilmSources

struct SMBProviderTests {
    private let connection = SMBConnection(name: "Test NAS", host: "nas.invalid", share: "media", rootPath: "films")
    private let credentials = SMBCredentials(username: "viewer", password: "fixture-only")

    @Test func directoryIdentitySortingAndRootBoundary() async throws {
        let transport = SMBFixtureTransport(entries: [
            SMBEntry(name: "Episode 10.mkv", isDirectory: false, size: 123),
            SMBEntry(name: "Series", isDirectory: true),
            SMBEntry(name: "Episode 2.mkv", isDirectory: false, size: 42)
        ])
        let provider = SMBProvider(transportFactory: { _, _ in transport })
        let items = try await provider.listDirectory(connection, credentials: credentials, path: "/films/./")
        #expect(items.map(\.name) == ["Series", "Episode 2.mkv", "Episode 10.mkv"])
        #expect(items[2].path == "films/Episode 10.mkv")
        #expect(items[2].sourceID == connection.id)
        #expect(items[2].id == "\(connection.id.uuidString):films/Episode 10.mkv")
        await #expect(throws: FilmError.self) {
            try await provider.listDirectory(connection, credentials: credentials, path: "films-other")
        }
        await #expect(throws: FilmError.self) {
            try await provider.listDirectory(connection, credentials: credentials, path: "films/../secrets")
        }
        #expect(await transport.listedPaths == ["films"])
    }

    @Test func maliciousDirectoryNameIsRejected() async {
        let transport = SMBFixtureTransport(entries: [SMBEntry(name: "../outside.mkv", isDirectory: false)])
        let provider = SMBProvider(transportFactory: { _, _ in transport })
        await #expect(throws: FilmError.self) {
            try await provider.listDirectory(connection, credentials: credentials, path: "films")
        }
    }

    @Test func randomReadsRespectOffsetsAndBounds() async throws {
        let bytes = Data((0..<1_024).map { UInt8($0 % 251) })
        let transport = SMBFixtureTransport(bytes: bytes)
        let provider = SMBProvider(transportFactory: { _, _ in transport })
        #expect(try await provider.fileSize(connection, credentials: credentials, path: "films/movie.mp4") == 1_024)
        #expect(try await provider.readFile(connection, credentials: credentials, path: "films/movie.mp4", range: 997..<1_024)
                == bytes.subdata(in: 997..<1_024))
        #expect(try await provider.readFile(connection, credentials: credentials, path: "films/movie.mp4", range: 3..<41)
                == bytes.subdata(in: 3..<41))
        #expect(try await provider.readFile(connection, credentials: credentials, path: "films/movie.mp4", range: 3..<3).isEmpty)
        await #expect(throws: FilmError.self) {
            try await provider.readFile(connection, credentials: credentials, path: "films/movie.mp4", range: -1..<2)
        }
        await #expect(throws: FilmError.self) {
            try await provider.readFile(connection, credentials: credentials, path: "films/movie.mp4", range: 0..<(SMBProvider.maximumReadSize + 1))
        }
        #expect(await transport.readRanges == [997..<1_024, 3..<41])
    }

    @Test func credentialChangesAndFailuresInvalidateSessions() async throws {
        let counter = SMBFactoryCounter()
        let provider = SMBProvider(transportFactory: { _, _ in
            counter.increment()
            return SMBFixtureTransport(bytes: Data([1, 2, 3]))
        })
        _ = try await provider.fileSize(connection, credentials: credentials, path: "films/movie.mp4")
        _ = try await provider.readFile(connection, credentials: credentials, path: "films/movie.mp4", range: 0..<1)
        #expect(counter.value == 1)
        _ = try await provider.fileSize(connection, credentials: SMBCredentials(username: "viewer", password: "changed"), path: "films/movie.mp4")
        #expect(counter.value == 2)
        await provider.forgetConnection(connection.id)
        _ = try await provider.fileSize(connection, credentials: credentials, path: "films/movie.mp4")
        #expect(counter.value == 3)

        let failingCounter = SMBFactoryCounter()
        let failing = SMBProvider(transportFactory: { _, _ in
            failingCounter.increment()
            return SMBFixtureTransport(failure: SMBError.authenticationFailed)
        })
        for _ in 0..<2 {
            await #expect(throws: SMBError.authenticationFailed) { try await failing.testConnection(connection, credentials: credentials) }
        }
        #expect(failingCounter.value == 2)
    }

    @Test func cancellationAndErrorsNeverExposeRawProtocolMessages() async throws {
        let transport = SMBFixtureTransport(delay: .seconds(20))
        let provider = SMBProvider(transportFactory: { _, _ in transport })
        let task = Task { try await provider.readFile(connection, credentials: credentials, path: "films/movie.mp4", range: 0..<1) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        let unsafe = NSError(domain: NSPOSIXErrorDomain, code: Int(ECONNREFUSED),
                             userInfo: [NSLocalizedDescriptionKey: "smb://viewer:fixture-secret@nas.invalid"])
        let sanitized = SMBError.sanitized(unsafe)
        #expect(sanitized as? SMBError == .connectionFailed)
        #expect(!sanitized.localizedDescription.contains("fixture-secret"))
        #expect(SMBError.sanitized(POSIXError(.ETIMEDOUT)) as? SMBError == .timedOut)
        #expect(SMBError.sanitized(POSIXError(.EACCES), authenticating: true) as? SMBError == .authenticationFailed)
        #expect(SMBError.sanitized(POSIXError(.EACCES)) as? SMBError == .permissionDenied)
        #expect(SMBError.sanitized(POSIXError(.ENOENT)) as? SMBError == .notFound)
    }

    @Test func concurrentReadsCannotKeepACancelledSessionCached() async throws {
        let transport = SMBFixtureTransport(delay: .seconds(20))
        let counter = SMBFactoryCounter()
        let provider = SMBProvider(transportFactory: { _, _ in counter.increment(); return transport })
        let reader = Task {
            try await provider.readFile(connection, credentials: credentials, path: "films/movie.mp4", range: 0..<1)
        }
        for _ in 0..<50 {
            if await !transport.readRanges.isEmpty { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await !transport.readRanges.isEmpty)
        _ = try await provider.fileSize(connection, credentials: credentials, path: "films/movie.mp4")
        #expect(counter.value == 1)
        reader.cancel()
        await #expect(throws: CancellationError.self) { try await reader.value }
        _ = try await provider.fileSize(connection, credentials: credentials, path: "films/movie.mp4")
        #expect(counter.value == 2)
    }

    @Test func sharedFoldersAreListedWithoutAdministrativeShares() async throws {
        let provider = SMBProvider(transportFactory: { _, _ in SMBFixtureTransport() })
        var endpoint = connection
        endpoint.share = ""
        let shares = try await provider.listShares(endpoint, credentials: credentials)
        #expect(shares.map(\.name) == ["Films", "Music"])
    }

    @Test func encryptionRequirementInvalidatesSessionsAndCannotEnumerateInPlaintext() async throws {
        let counter = SMBFactoryCounter()
        let provider = SMBProvider(transportFactory: { _, _ in counter.increment(); return SMBFixtureTransport() })
        _ = try await provider.fileSize(connection, credentials: credentials, path: "films/movie.mp4")
        var encrypted = connection
        encrypted.requireEncryption = true
        _ = try await provider.fileSize(encrypted, credentials: credentials, path: "films/movie.mp4")
        #expect(counter.value == 2)
        await #expect(throws: SMBError.encryptedShareDiscoveryUnavailable) {
            try await provider.listShares(encrypted, credentials: credentials)
        }
        #expect(counter.value == 2)
    }
}

actor SMBFixtureTransport: SMBTransport {
    let entries: [SMBEntry]
    let bytes: Data
    let failure: (any Error)?
    let delay: Duration?
    private(set) var listedPaths: [String] = []
    private(set) var readRanges: [Range<Int64>] = []

    init(entries: [SMBEntry] = [], bytes: Data = Data([1, 2, 3]), failure: (any Error)? = nil, delay: Duration? = nil) {
        self.entries = entries; self.bytes = bytes; self.failure = failure; self.delay = delay
    }
    func connect(share: String) async throws { if let failure { throw failure } }
    func listShares() async throws -> [SMBShare] {
        [SMBShare(name: "Music"), SMBShare(name: "ADMIN$"), SMBShare(name: "Films")]
    }
    func listDirectory(path: String) async throws -> [SMBEntry] { listedPaths.append(path); return entries }
    func fileSize(path: String) async throws -> Int64 { Int64(bytes.count) }
    func read(path: String, range: Range<Int64>) async throws -> Data {
        readRanges.append(range)
        if let delay { try await Task.sleep(for: delay) }
        guard range.lowerBound < bytes.count else { return Data() }
        return bytes.subdata(in: Int(range.lowerBound)..<min(Int(range.upperBound), bytes.count))
    }
}

private final class SMBFactoryCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}
