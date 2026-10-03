#if DEBUG
import Foundation
import Testing
import FilmDomain
@testable import FilmSources

@Suite struct SMBStreamTraceTests {
    @Test func disabledRecorderRetainsNothingAndBoundedConcurrentRequestsAreCorrelated() async throws {
        let recorder = SMBStreamTraceRecorder()
        recorder.record(.readerSubmit)
        #expect(recorder.beginRequest() == nil)
        #expect(recorder.data() == nil)
        recorder.enable(origin: .now, capacity: 17)
        let requestIDs = await withTaskGroup(of: UInt64?.self) { group in
            for _ in 0..<32 {
                group.addTask {
                    guard let request = recorder.beginRequest() else { return nil }
                    request.record(.readerSubmit, offset: 524_288, count: 524_288)
                    request.record(.readerComplete, offset: 524_288, count: 524_288)
                    request.record(.requestFinished)
                    return request.requestID
                }
            }
            var ids: [UInt64] = []
            for await id in group { if let id { ids.append(id) } }
            return ids
        }
        #expect(Set(requestIDs) == Set(1...32))
        let snapshot = try JSONDecoder().decode(TraceSnapshot.self, from: #require(recorder.data()))
        #expect(snapshot.schemaVersion == 1 && snapshot.capacity == 17)
        #expect(snapshot.events.count == 17 && snapshot.omittedEvents == 128 - 17)
        #expect(snapshot.events.map(\.sequence) == Array(112...128))
        #expect(snapshot.events.allSatisfy { (1...32).contains($0.requestID) && $0.elapsedSeconds >= 0 })
        let capped = SMBStreamTraceRecorder()
        capped.enable(origin: .now, capacity: Int.max)
        #expect(try JSONDecoder().decode(TraceSnapshot.self, from: #require(capped.data())).capacity == 4_096)
    }

    @Test func disabledHTTPTraceStaysNilAfterActualResponseAndStop() async throws {
        let provider = TraceProvider(bytes: Data([1, 2, 3]))
        let server = makeServer(provider, size: 3)
        #expect(await server.debugTraceData() == nil)
        let url = try await server.start()
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let (data, _) = try await session.data(from: url)
        #expect(data == Data([1, 2, 3]))
        await server.stop()
        #expect(await server.debugTraceData() == nil)
    }

    @Test func actualConcurrentRangesKeepRequestStagesAndNeverRetainPrivateFields() async throws {
        let bytes = Data((0..<1_048_601).map { UInt8($0 % 251) })
        let provider = TraceProvider(bytes: bytes)
        let server = makeServer(provider, size: Int64(bytes.count))
        await server.debugEnableTrace(origin: .now, capacity: 512)
        let url = try await server.start()
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let ranges = [0..<4, 524_288..<1_048_589, 1_048_589..<1_048_601]
        try await withThrowingTaskGroup(of: Void.self) { group in
            for range in ranges {
                group.addTask {
                    var request = URLRequest(url: url)
                    request.setValue("bytes=\(range.lowerBound)-\(range.upperBound - 1)", forHTTPHeaderField: "Range")
                    let (received, response) = try await session.data(for: request)
                    #expect((response as? HTTPURLResponse)?.statusCode == 206)
                    #expect(received == bytes.subdata(in: range))
                }
            }
            try await group.waitForAll()
        }
        await server.stop()
        let data = try #require(await server.debugTraceData())
        let snapshot = try JSONDecoder().decode(TraceSnapshot.self, from: data)
        #expect(snapshot.omittedEvents == 0)
        let rangeEvents = snapshot.events.filter { $0.phase == "rangeReceived" }
        #expect(Set(rangeEvents.map(\.requestID)).count == 3)
        #expect(Set(rangeEvents.map(\.offset)) == Set(ranges.map { Int64($0.lowerBound) }))
        for event in rangeEvents {
            let phases = snapshot.events.filter { $0.requestID == event.requestID }.map(\.phase)
            let expected = ["listenerConnection", "requestAccepted", "rangeReceived", "sendCallbackComplete", "headersSent", "readerSubmit", "readerComplete", "sendCallbackComplete", "chunkSendComplete"]
            var cursor = 0
            for phase in phases where cursor < expected.count {
                if phase == expected[cursor] { cursor += 1 }
            }
            #expect(cursor == expected.count)
        }
        let text = try #require(String(data: data, encoding: .utf8))
        for forbidden in [url.absoluteString, url.path, "private-fixture-name", "private-fixture-host", "private-fixture-share", "private-fixture-user", "private-fixture-password", "private-fixture-domain", "private-fixture-path"] {
            #expect(!text.contains(forbidden))
        }
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["schemaVersion", "capacity", "omittedEvents", "events"])
        let fields = try #require(object["events"] as? [[String: Any]])
        let allowedPhases: Set<String> = ["listenerConnection", "requestAccepted", "requestRejected", "rangeReceived", "headersSent",
            "readerSubmit", "readerComplete", "readerFailed", "readerCancelled", "chunkSendComplete",
            "sendCallbackComplete", "sendCallbackFailed", "consumerTransportError", "consumerWriteEOF",
            "connectionFailed", "connectionCancelled", "cancelRequested", "requestFinished", "sourceReadFailure", "stop", "stopComplete", "serverDeinit"]
        for event in fields {
            #expect(Set(event.keys) == ["sequence", "requestID", "elapsedSeconds", "phase", "offset", "count", "httpStatus"])
            #expect(allowedPhases.contains(try #require(event["phase"] as? String)))
            #expect(event.filter { $0.key != "phase" }.values.allSatisfy { $0 is NSNumber })
        }
    }

    @Test func sourceFailureIsRecordedAfterPublicationAndBeforeRequestFinishes() async throws {
        let provider = TraceProvider(bytes: Data([1, 2, 3]), fail: true)
        let server = makeServer(provider, size: 3)
        await server.debugEnableTrace()
        let url = try await server.start()
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        do { _ = try await session.data(from: url); Issue.record("An incomplete HTTP body must fail.") }
        catch {}
        #expect(await server.readFailure() == .connectionFailed)
        await server.stop()
        let data = try #require(await server.debugTraceData())
        let events = try JSONDecoder().decode(TraceSnapshot.self, from: data).events
        let failure = try #require(events.first { $0.phase == "sourceReadFailure" })
        let reader = try #require(events.first { $0.phase == "readerFailed" && $0.requestID == failure.requestID })
        let finished = try #require(events.first { $0.phase == "requestFinished" && $0.requestID == failure.requestID })
        #expect(reader.sequence < failure.sequence && failure.sequence < finished.sequence)
        #expect(!String(decoding: data, as: UTF8.self).contains("private-fixture-error"))
    }

    private func makeServer(_ provider: any SMBFileProviding, size: Int64) -> SMBStreamingServer {
        SMBStreamingServer(provider: provider, connection: SMBConnection(name: "private-fixture-name", host: "private-fixture-host", share: "private-fixture-share"),
            credentials: SMBCredentials(username: "private-fixture-user", password: "private-fixture-password", domain: "private-fixture-domain"),
            path: "private-fixture-path.mp4", size: size)
    }
}

private struct TraceSnapshot: Decodable {
    let schemaVersion: Int
    let capacity: Int
    let omittedEvents: UInt64
    let events: [TraceEvent]
}

private struct TraceEvent: Decodable {
    let sequence: UInt64
    let requestID: UInt64
    let elapsedSeconds: Double
    let phase: String
    let offset: Int64
    let count: Int64
    let httpStatus: Int
}

private actor TraceProvider: SMBFileProviding {
    let bytes: Data
    let fail: Bool
    init(bytes: Data, fail: Bool = false) { self.bytes = bytes; self.fail = fail }
    func testConnection(_ connection: SMBConnection, credentials: SMBCredentials) async throws {}
    func listDirectory(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> [MediaItem] { [] }
    func fileSize(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> Int64 { Int64(bytes.count) }
    func readFile(_ connection: SMBConnection, credentials: SMBCredentials, path: String, range: Range<Int64>) async throws -> Data {
        if fail { throw NSError(domain: "private-fixture-error", code: 5, userInfo: [NSLocalizedDescriptionKey: "private-fixture-error"]) }
        return bytes.subdata(in: Int(range.lowerBound)..<Int(range.upperBound))
    }
}
#endif
