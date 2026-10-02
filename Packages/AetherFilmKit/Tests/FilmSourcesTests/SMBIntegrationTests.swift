import Foundation
import Testing
import FilmDomain
import FilmSources

/// Opt-in only: credentials are injected in memory by an isolated loopback test-server launcher.
struct SMBIntegrationTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["AETHERFILM_SMB_BOOTSTRAP_URL"] != nil))
    func bootstrapDeliversCredentialsInMemoryForTestRunners() async throws {
        struct Configuration: Decodable {
            let port: Int
            let username: String
            let password: String
            let share: String
        }
        let endpoint = try #require(ProcessInfo.processInfo.environment["AETHERFILM_SMB_BOOTSTRAP_URL"])
        let url = try #require(URL(string: endpoint))
        #expect(url.host == "127.0.0.1")
        #expect(url.user == nil && url.password == nil && url.query == nil)
        let (data, response) = try await URLSession.shared.data(from: url)
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)
        #expect(http.value(forHTTPHeaderField: "Cache-Control") == "no-store")
        let configuration = try JSONDecoder().decode(Configuration.self, from: data)
        let connection = SMBConnection(name: "Bootstrap fixture", host: "127.0.0.1", port: configuration.port,
                                       share: configuration.share, rootPath: "nested")
        let credentials = SMBCredentials(username: configuration.username, password: configuration.password)
        let provider = SMBProvider(timeout: 3)
        try await provider.testConnection(connection, credentials: credentials)
        let bytes = try await provider.readFile(connection, credentials: credentials, path: "nested/sample.bin", range: 0..<100)
        #expect(bytes == Data((0..<100).map { UInt8($0 % 251) }))
        await provider.close()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["AETHERFILM_SMB_TEST_PORT"] != nil))
    func requiredEncryptionNeverFallsBackToPlaintextSMB2() async throws {
        let environment = ProcessInfo.processInfo.environment
        let port = try #require(environment["AETHERFILM_SMB_TEST_PORT"].flatMap(Int.init))
        let password = try #require(environment["AETHERFILM_SMB_TEST_PASSWORD"])
        var connection = SMBConnection(name: "SMB2 fixture", host: "127.0.0.1", port: port, share: "FILMS", rootPath: "nested")
        let credentials = SMBCredentials(username: "aetherfilm-fixture", password: password)
        let provider = SMBProvider(timeout: 1)
        try await provider.testConnection(connection, credentials: credentials)
        connection.requireEncryption = true
        await #expect(throws: SMBError.encryptedConnectionFailed) {
            try await provider.testConnection(connection, credentials: credentials)
        }
        // Disabling the requirement is an explicit user choice, and restores SMB2 access.
        connection.requireEncryption = false
        try await provider.testConnection(connection, credentials: credentials)
        await provider.close()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["AETHERFILM_SMB_STALL_PORT"] != nil))
    func stalledProtocolTimesOutAndActiveHandshakeCanBeCancelled() async throws {
        let port = try #require(ProcessInfo.processInfo.environment["AETHERFILM_SMB_STALL_PORT"].flatMap(Int.init))
        let connection = SMBConnection(name: "Stalled fixture", host: "127.0.0.1", port: port, share: "FILMS")
        let credentials = SMBCredentials(username: "fixture", password: "")
        let provider = SMBProvider(timeout: 1)
        let clock = ContinuousClock(), started = clock.now
        await #expect(throws: SMBError.timedOut) { try await provider.testConnection(connection, credentials: credentials) }
        #expect(clock.now - started < .seconds(5))
        let cancellable = SMBProvider(timeout: 3)
        let task = Task { try await cancellable.testConnection(connection, credentials: credentials) }
        try await Task.sleep(for: .milliseconds(100))
        let cancelledAt = clock.now
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(clock.now - cancelledAt < .seconds(1))
        await provider.close(); await cancellable.close()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["AETHERFILM_SMB_TEST_PORT"] != nil))
    func authenticatedProtocolListingRandomReadsAndErrors() async throws {
        let environment = ProcessInfo.processInfo.environment
        let port = try #require(environment["AETHERFILM_SMB_TEST_PORT"].flatMap(Int.init))
        let password = try #require(environment["AETHERFILM_SMB_TEST_PASSWORD"])
        let credentials = SMBCredentials(username: "aetherfilm-fixture", password: password)
        let connection = SMBConnection(name: "Isolated fixture", host: "127.0.0.1", port: port, share: "FILMS", rootPath: "nested")
        let provider = SMBProvider(timeout: 3)
        try await provider.testConnection(connection, credentials: credentials)
        let shares = try await provider.listShares(connection, credentials: credentials)
        #expect(shares.contains { $0.name == "FILMS" })
        let entries = try await provider.listDirectory(connection, credentials: credentials, path: "nested")
        #expect(entries.contains { $0.name == "sample.bin" && $0.path == "nested/sample.bin" && !$0.isDirectory })
        #expect(entries.contains { $0.name == "中文目录" && $0.isDirectory })
        let count: Int64 = 1_048_649
        #expect(try await provider.fileSize(connection, credentials: credentials, path: "nested/sample.bin") == count)
        for range in [0..<Int64(100), 1_048_576..<count, 37..<99, 0..<count] {
            let actual = try await provider.readFile(connection, credentials: credentials, path: "nested/sample.bin", range: range)
            let expected = Data(range.map { UInt8($0 % 251) })
            #expect(actual == expected)
        }
        await #expect(throws: SMBError.notFound) {
            try await provider.readFile(connection, credentials: credentials, path: "nested/missing.bin", range: 0..<1)
        }
        await #expect(throws: SMBError.authenticationFailed) {
            try await provider.testConnection(connection, credentials: SMBCredentials(username: credentials.username, password: password + "-wrong"))
        }
        try await provider.testConnection(connection, credentials: credentials)
        let cancelled = Task {
            try await provider.readFile(connection, credentials: credentials, path: "nested/sample.bin", range: 0..<count)
        }
        cancelled.cancel()
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        await provider.close()
    }
}
