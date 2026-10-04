import Foundation
import CryptoKit
import Testing
import FilmDomain
import FilmSources

/// Opt-in SMB3 positive gate. Credentials are fetched only from a private loopback fixture.
/// Unavailable encrypted share discovery is checked for rejection, never treated as supported.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["AETHERFILM_SMB3_BOOTSTRAP_URL"] != nil))
struct SMB3EncryptionIntegrationTests {
    @Test func requiredEncryptionConnectsToSMB3() async throws {
        let fixture = try await SMB3Fixture.load()
        let provider = SMBProvider(timeout: 8)
        try await provider.testConnection(fixture.connection(), credentials: fixture.credentials)
        await provider.close()
        try await fixture.completed(1)
    }

    @Test func encryptedShareDiscoveryRejectsWithoutNetworkDowngrade() async throws {
        let fixture = try await SMB3Fixture.load()
        let provider = SMBProvider(timeout: 8)
        let before = try await fixture.stats()
        do {
            _ = try await provider.listShares(fixture.connection(), credentials: fixture.credentials)
            throw SMB3Fixture.Failure.assertion
        } catch SMBError.encryptedShareDiscoveryUnavailable {}
        let after = try await fixture.stats()
        try SMB3Fixture.require(after.acceptedConnections == before.acceptedConnections)
        await provider.close()
        try await fixture.completed(2)
    }

    @Test func encryptedChineseDirectoryAndVideoMetadata() async throws {
        let fixture = try await SMB3Fixture.load()
        let provider = SMBProvider(timeout: 8)
        let root = try await provider.listDirectory(fixture.connection(), credentials: fixture.credentials, path: "")
        try SMB3Fixture.require(root.contains { $0.name == "中文目录" && $0.isDirectory })
        let directory = try await provider.listDirectory(fixture.connection(), credentials: fixture.credentials, path: "中文目录")
        try SMB3Fixture.require(directory.contains { $0.name == "测试影片.mp4" && $0.isVideo && $0.size == fixture.videoSize })
        await provider.close()
        try await fixture.completed(3)
    }

    @Test func encryptedFullBinaryHasExpectedSHA256() async throws {
        let fixture = try await SMB3Fixture.load()
        let provider = SMBProvider(timeout: 8)
        let size = try await provider.fileSize(fixture.connection(), credentials: fixture.credentials, path: "sample.bin")
        try SMB3Fixture.require(size == fixture.payloadSize)
        let data = try await provider.readFile(fixture.connection(), credentials: fixture.credentials, path: "sample.bin", range: 0..<fixture.payloadSize)
        try SMB3Fixture.require(Int64(data.count) == size && SMB3Fixture.sha256(data) == fixture.payloadSHA256)
        await provider.close()
        try await fixture.completed(4)
    }

    @Test func encryptedRandomAndBoundaryRangesMatchBytesAndSHA256() async throws {
        let fixture = try await SMB3Fixture.load()
        let provider = SMBProvider(timeout: 8)
        let ranges: [Range<Int64>] = [0..<1, 127..<3979, 65519..<132211, 500003..<764333, (fixture.payloadSize-4093)..<fixture.payloadSize]
        for range in ranges {
            let data = try await provider.readFile(fixture.connection(), credentials: fixture.credentials, path: "sample.bin", range: range)
            let expected = Data(range.map { UInt8($0 % 251) })
            try SMB3Fixture.require(data == expected && SMB3Fixture.sha256(data) == SMB3Fixture.sha256(expected))
        }
        await provider.close()
        try await fixture.completed(5)
    }

    @Test func encryptedChineseVideoHasExpectedFullSHA256() async throws {
        let fixture = try await SMB3Fixture.load()
        let provider = SMBProvider(timeout: 8)
        let data = try await provider.readFile(fixture.connection(), credentials: fixture.credentials, path: "中文目录/测试影片.mp4", range: 0..<fixture.videoSize)
        try SMB3Fixture.require(Int64(data.count) == fixture.videoSize && SMB3Fixture.sha256(data) == fixture.videoSHA256)
        await provider.close()
        try await fixture.completed(6)
    }

    @Test func invalidEncryptedAuthenticationCanRetryWithCorrectCredentials() async throws {
        let fixture = try await SMB3Fixture.load()
        let provider = SMBProvider(timeout: 8)
        try await provider.testConnection(fixture.connection(), credentials: fixture.credentials)
        let invalid = SMBCredentials(username: fixture.username, password: "deliberately-invalid-fixture-password", domain: "WORKGROUP")
        do {
            try await provider.testConnection(fixture.connection(), credentials: invalid)
            throw SMB3Fixture.Failure.assertion
        } catch SMBError.encryptedConnectionFailed {}
        try await provider.testConnection(fixture.connection(), credentials: fixture.credentials)
        await provider.close()
        try await fixture.completed(7)
    }

    @Test func activeEncryptedFileReadCancellationCanRetry() async throws {
        let fixture = try await SMB3Fixture.load()
        let provider = SMBProvider(timeout: 8)
        let connection = fixture.connection(slow: true)
        try await provider.testConnection(connection, credentials: fixture.credentials)
        let before = try await fixture.stats()
        var pending: Task<Data, any Error>?
        do {
            _ = try await fixture.control(action: "hold")
            let read = Task {
                try await provider.readFile(connection, credentials: fixture.credentials, path: "sample.bin", range: 0..<fixture.payloadSize)
            }
            pending = read
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: .seconds(3))
            var responseWasActuallyHeld = false
            while clock.now < deadline {
                if try await fixture.stats().heldEncryptedServerFrames > before.heldEncryptedServerFrames {
                    responseWasActuallyHeld = true
                    break
                }
                try await Task.sleep(for: .milliseconds(20))
            }
            try SMB3Fixture.require(responseWasActuallyHeld)
            let cancelledAt = clock.now
            read.cancel()
            do { _ = try await read.value; throw SMB3Fixture.Failure.assertion }
            catch is CancellationError {}
            let interval = clock.now - cancelledAt
            try SMB3Fixture.require(interval < .seconds(1))
            _ = try await fixture.control(action: "release")
            let retry = try await provider.readFile(connection, credentials: fixture.credentials, path: "sample.bin", range: 100..<500)
            try SMB3Fixture.require(retry == Data((100..<500).map { UInt8($0 % 251) }))
        } catch {
            pending?.cancel()
            _ = try? await fixture.control(action: "release")
            if let pending { _ = try? await pending.value }
            await provider.close()
            throw error
        }
        await provider.close()
        try await fixture.completed(8)
    }
}

private struct SMB3Fixture: Decodable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    enum Failure: Error { case unavailable, assertion }
    struct WireStats: Decodable {
        let acceptedConnections: Int
        let heldEncryptedServerFrames: Int
    }
    let port: Int
    let slowPort: Int
    let username: String
    private let password: String
    let share: String
    private let controlURL: URL
    let payloadSize: Int64
    let payloadSHA256: String
    let videoSize: Int64
    let videoSHA256: String
    var description: String { "SMB3Fixture(redacted)" }
    var debugDescription: String { description }
    var credentials: SMBCredentials { SMBCredentials(username: username, password: password, domain: "WORKGROUP") }

    // A repeated operation keeps the same source/session identity within one fixture instance.
    private var connectionID: UUID { Self.sessionID }
    private static let sessionID = UUID()
    func connection(slow: Bool = false) -> SMBConnection {
        SMBConnection(id: connectionID, name: "fixture", host: "127.0.0.1", port: slow ? slowPort : port,
                      share: share, requireEncryption: true)
    }
    static func require(_ condition: Bool) throws { if !condition { throw Failure.assertion } }
    static func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func request(_ url: URL, payload: [String: Any]? = nil) async throws -> Data {
        guard url.scheme == "http", url.host == "127.0.0.1", url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, (url.port ?? 0) > 1024 else { throw Failure.unavailable }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        if let payload {
            request.httpMethod = "POST"
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        do {
            let (data,response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  http.value(forHTTPHeaderField: "Cache-Control") == "no-store" else { throw Failure.unavailable }
            return data
        } catch { throw Failure.unavailable }
    }
    static func load() async throws -> Self {
        guard let value = ProcessInfo.processInfo.environment["AETHERFILM_SMB3_BOOTSTRAP_URL"],
              let url = URL(string: value) else { throw Failure.unavailable }
        do {
            let fixture = try JSONDecoder().decode(Self.self, from: await request(url))
            guard (1025...65535).contains(fixture.port), (1025...65535).contains(fixture.slowPort),
                  fixture.payloadSize == 1_048_649, (1...SMBProvider.maximumReadSize).contains(fixture.videoSize) else { throw Failure.unavailable }
            return fixture
        } catch { throw Failure.unavailable }
    }
    func stats() async throws -> WireStats {
        try JSONDecoder().decode(WireStats.self, from: await Self.request(controlURL))
    }
    func control(action: String) async throws -> Data {
        try await Self.request(controlURL, payload: ["action": action])
    }
    func completed(_ code: Int) async throws {
        _ = try await Self.request(controlURL, payload: ["action": "caseComplete", "code": code])
    }
}
