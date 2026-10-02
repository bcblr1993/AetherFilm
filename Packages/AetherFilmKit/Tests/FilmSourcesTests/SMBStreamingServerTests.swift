import Foundation
import Testing
import FilmDomain
@testable import FilmSources

struct SMBStreamingServerTests {
    @Test func boundedHTTPPlaybackAndRandomSeek() async throws {
        let bytes = Data((0..<(1_024 * 1_024 + 73)).map { UInt8($0 % 251) })
        let fixture = SMBFixtureFileProvider(bytes: bytes)
        let server = makeServer(provider: fixture, size: Int64(bytes.count))
        let url = try await server.start()
        #expect(url.host == "127.0.0.1")
        #expect(url.user == nil && url.password == nil)
        #expect(try await server.start() == url)
        do {
            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }
            let (full, response) = try await session.data(from: url)
            #expect((response as? HTTPURLResponse)?.statusCode == 200)
            #expect(full == bytes)
            #expect(await fixture.ranges == [0..<524_288, 524_288..<1_048_576, 1_048_576..<Int64(bytes.count)])

            for (header, expected) in [("bytes=37-98", 37..<99), ("bytes=-16", (bytes.count - 16)..<bytes.count),
                                       ("bytes=1048576-", 1_048_576..<bytes.count)] {
                var request = URLRequest(url: url)
                request.setValue(header, forHTTPHeaderField: "Range")
                let (data, response) = try await session.data(for: request)
                #expect((response as? HTTPURLResponse)?.statusCode == 206)
                #expect(data == bytes.subdata(in: expected))
                #expect((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Range")
                        == "bytes \(expected.lowerBound)-\(expected.upperBound - 1)/\(bytes.count)")
            }
            var head = URLRequest(url: url)
            head.httpMethod = "HEAD"; head.setValue("bytes=-16", forHTTPHeaderField: "Range")
            let (headData, headResponse) = try await session.data(for: head)
            #expect(headData.isEmpty)
            #expect((headResponse as? HTTPURLResponse)?.statusCode == 200)
            #expect((headResponse as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Length") == String(bytes.count))
        } catch { await server.stop(); throw error }
        await server.stop()
    }

    @Test func invalidRangesTokensAndMethodsAreRejected() async throws {
        let fixture = SMBFixtureFileProvider(bytes: Data([1, 2, 3, 4]))
        let server = makeServer(provider: fixture, size: 4)
        let url = try await server.start()
        do {
            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }
            for header in ["bytes=4-", "bytes=3-1", "bytes=0-1,2-3", "bytes=-0"] {
                var request = URLRequest(url: url)
                request.setValue(header, forHTTPHeaderField: "Range")
                let (_, response) = try await session.data(for: request)
                #expect((response as? HTTPURLResponse)?.statusCode == 416)
                #expect((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Range") == "bytes */4")
            }
            let badURL = url.deletingLastPathComponent().appendingPathComponent("wrong-token.mp4")
            let (_, badResponse) = try await session.data(from: badURL)
            #expect((badResponse as? HTTPURLResponse)?.statusCode == 404)
            var post = URLRequest(url: url); post.httpMethod = "POST"
            let (_, postResponse) = try await session.data(for: post)
            #expect((postResponse as? HTTPURLResponse)?.statusCode == 405)
            #expect(await fixture.ranges.isEmpty)
        } catch { await server.stop(); throw error }
        await server.stop()
    }

    @Test func emptyFilesAndServerDisposal() async throws {
        let fixture = SMBFixtureFileProvider(bytes: Data())
        let server = makeServer(provider: fixture, size: 0)
        let url = try await server.start()
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        do {
            let (data, response) = try await session.data(from: url)
            #expect(data.isEmpty)
            #expect((response as? HTTPURLResponse)?.statusCode == 200)
            var request = URLRequest(url: url); request.setValue("bytes=0-", forHTTPHeaderField: "Range")
            let (_, rangeResponse) = try await session.data(for: request)
            #expect((rangeResponse as? HTTPURLResponse)?.statusCode == 416)
        } catch { await server.stop(); throw error }
        await server.stop()
        var request = URLRequest(url: url); request.timeoutInterval = 1
        await #expect(throws: (any Error).self) { try await session.data(for: request) }
    }

    @Test func stopCancelsActiveRead() async throws {
        let fixture = SMBFixtureFileProvider(bytes: Data([1, 2, 3]), delay: .seconds(20))
        let server = makeServer(provider: fixture, size: 3)
        let url = try await server.start()
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let request = Task { try await session.data(from: url) }
        for _ in 0..<50 {
            if await !fixture.ranges.isEmpty { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(await !fixture.ranges.isEmpty)
        let clock = ContinuousClock(), start = clock.now
        await server.stop()
        #expect(clock.now - start < .seconds(2))
        await #expect(throws: (any Error).self) { try await request.value }
    }

    @Test func releasingServerCancelsActiveReadAndClosesListener() async throws {
        let fixture = SMBFixtureFileProvider(bytes: Data([1, 2, 3]), delay: .seconds(20))
        var server: SMBStreamingServer? = makeServer(provider: fixture, size: 3)
        let url = try await #require(server).start()
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        var pending = URLRequest(url: url)
        pending.timeoutInterval = 3
        let request = Task { try await session.data(for: pending) }
        for _ in 0..<50 {
            if await !fixture.ranges.isEmpty { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await !fixture.ranges.isEmpty)
        let clock = ContinuousClock(), releasedAt = clock.now
        server = nil
        await #expect(throws: (any Error).self) { try await request.value }
        #expect(clock.now - releasedAt < .seconds(2))
        var next = URLRequest(url: url)
        next.timeoutInterval = 1
        await #expect(throws: (any Error).self) { try await session.data(for: next) }
    }

    @Test func requestParserRejectsDuplicateAndFoldedHeaders() throws {
        let parsed = try SMBHTTPRequest(data: Data("GET /token.mp4 HTTP/1.1\r\nHost: 127.0.0.1\r\nRaNgE: bytes=1-2\r\n\r\n".utf8))
        #expect(parsed.method == "GET" && parsed.range == "bytes=1-2")
        for text in ["GET /x HTTP/1.1\r\nRange: bytes=1-2\r\nRange: bytes=2-3\r\n\r\n",
                     "GET /x HTTP/1.1\r\n Range: bytes=1-2\r\n\r\n", "GET /x HTTP/1.1\n\n"] {
            #expect(throws: (any Error).self) { try SMBHTTPRequest(data: Data(text.utf8)) }
        }
    }

    @Test func cancelledHTTPClientsDoNotExhaustTheConnectionLimit() async throws {
        let fixture = SMBFixtureFileProvider(bytes: Data([1, 2, 3]), delay: .seconds(20))
        let server = makeServer(provider: fixture, size: 3)
        let url = try await server.start()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = 16
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        do {
            for _ in 0..<10 {
                let before = await fixture.ranges.count
                let request = Task { try await session.data(from: url) }
                for _ in 0..<50 {
                    if await fixture.ranges.count > before { break }
                    try await Task.sleep(for: .milliseconds(10))
                }
                let readStarted = await fixture.ranges.count > before
                #expect(readStarted)
                request.cancel()
                await #expect(throws: (any Error).self) { try await request.value }
                guard readStarted else { throw SMBError.connectionFailed }
            }
            await fixture.setDelay(nil)
            var request = URLRequest(url: url)
            request.setValue("bytes=1-2", forHTTPHeaderField: "Range")
            request.timeoutInterval = 2
            let (data, response) = try await session.data(for: request)
            #expect((response as? HTTPURLResponse)?.statusCode == 206)
            #expect(data == Data([2, 3]))
        } catch { await server.stop(); throw error }
        await server.stop()
    }

    private func makeServer(provider: any SMBFileProviding, size: Int64) -> SMBStreamingServer {
        SMBStreamingServer(provider: provider, connection: SMBConnection(name: "Fixture", host: "nas.invalid", share: "media"),
                           credentials: SMBCredentials(username: "fixture", password: "memory-only"), path: "movie.mp4", size: size)
    }
}

actor SMBFixtureFileProvider: SMBFileProviding {
    let bytes: Data
    private var delay: Duration?
    private(set) var ranges: [Range<Int64>] = []
    init(bytes: Data, delay: Duration? = nil) { self.bytes = bytes; self.delay = delay }
    func setDelay(_ delay: Duration?) { self.delay = delay }
    func testConnection(_ connection: SMBConnection, credentials: SMBCredentials) async throws {}
    func listDirectory(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> [MediaItem] { [] }
    func fileSize(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> Int64 { Int64(bytes.count) }
    func readFile(_ connection: SMBConnection, credentials: SMBCredentials, path: String, range: Range<Int64>) async throws -> Data {
        ranges.append(range)
        if let delay { try await Task.sleep(for: delay) }
        return bytes.subdata(in: Int(range.lowerBound)..<Int(range.upperBound))
    }
}
