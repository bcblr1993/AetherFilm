import XCTest
import FilmDomain
import FilmSources
import VLCKit
import CryptoKit
@testable import AetherFilm
#if os(iOS)
import UIKit

/// Explicit opt-in, read-only acceptance against user-supplied media. No paths,
/// credentials, artwork, subtitles or frames are attached to the test result.
@MainActor final class UserNASPlaybackTests: XCTestCase {
    private struct Configuration: Decodable {
        let host: String
        let username: String
        let password: String
        let share: String
        let path: String
        let size: Int64
        let referenceHTTPURL: String?
        let expectedRanges: [ExpectedRange]?
    }
    private struct ExpectedRange: Decodable {
        let offset: Int64
        let count: Int64
        let sha256: String
    }

    func testReadonlyUserNASRangesPlaybackAndSeek() async throws {
        guard let address = ProcessInfo.processInfo.environment["AETHERFILM_NAS_BOOTSTRAP_URL"],
              let url = URL(string: address), url.scheme == "http", url.host == "127.0.0.1",
              url.user == nil, url.password == nil, url.query == nil else {
            throw XCTSkip("Requires the explicit private NAS acceptance launcher.")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let configuration = try JSONDecoder().decode(Configuration.self, from: data)
        let connection = SMBConnection(name: "Private acceptance source", host: configuration.host, share: configuration.share)
        let credentials = SMBCredentials(username: configuration.username, password: configuration.password)
        let provider = SMBProvider()
        let parent = configuration.path.split(separator: "/").dropLast().joined(separator: "/")
        let entries = try await provider.listDirectory(connection, credentials: credentials, path: parent)
        XCTAssertTrue(entries.contains { $0.path == configuration.path && $0.isVideo })
        let size = try await provider.fileSize(connection, credentials: credentials, path: configuration.path)
        XCTAssertEqual(size, configuration.size)
        for offset in [Int64(0), size / 2, max(0, size - 65_536)] {
            let count = min(65_536, size - offset)
            let bytes = try await provider.readFile(connection, credentials: credentials,
                path: configuration.path, range: offset..<(offset + count))
            XCTAssertEqual(bytes.count, Int(count))
        }
        for expected in configuration.expectedRanges ?? [] {
            guard expected.offset >= 0, expected.count > 0, expected.count <= 1_048_576,
                  expected.offset <= size - expected.count else { throw FilmError.invalidRange }
            let bytes = try await provider.readFile(connection, credentials: credentials,
                path: configuration.path, range: expected.offset..<(expected.offset + expected.count))
            XCTAssertTrue(digest(bytes) == expected.sha256, "Production provider must match independently read bytes.")
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = UIViewController()
        let surface = UIView(frame: window.bounds)
        surface.backgroundColor = .black
        window.rootViewController?.view.addSubview(surface)
        window.makeKeyAndVisible()
        let player = FilmPlayer()
        let stream = SMBStreamingServer(provider: provider, connection: connection, credentials: credentials,
                                       path: configuration.path, size: size)
        player.debugEnableLifecycleTrace()
        await stream.debugEnableTrace()
        defer {
            player.stop(); player.detachDrawable(surface)
            window.isHidden = true; previous?.makeKeyAndVisible()
        }
        do {
            var playbackURL = try await stream.start()
            for expected in configuration.expectedRanges ?? [] {
                var request = URLRequest(url: playbackURL, cachePolicy: .reloadIgnoringLocalCacheData)
                request.setValue("bytes=\(expected.offset)-\(expected.offset + expected.count - 1)", forHTTPHeaderField: "Range")
                let (bytes, response) = try await URLSession.shared.data(for: request)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 206)
                XCTAssertTrue(digest(bytes) == expected.sha256, "Production HTTP must match independently read bytes.")
            }
            print("NAS bounded provider and HTTP digest comparisons completed=\(configuration.expectedRanges?.count ?? 0)")
            if let address = configuration.referenceHTTPURL {
                let reference = try XCTUnwrap(URL(string: address))
                guard reference.scheme == "http", reference.host == "127.0.0.1",
                      reference.user == nil, reference.password == nil, reference.query == nil else {
                    throw FilmError.invalidPath
                }
                playbackURL = reference
                print("NAS diagnostic using independent HTTP transport; production acceptance remains separate.")
            }
            player.load(url: playbackURL)
            let outputEvents = SafeOutputEvents()
            player.backendEngineForTesting?.libraryInstance.loggers = [outputEvents]
            player.attachDrawable(surface)
            try await wait("initial output", player: player) {
                player.duration > 4 && player.position > 0.5 && player.displayedVideoFrames > 0
                    && player.playedAudioBuffers > 0 && player.errorMessage == nil
            }
            let target = min(player.duration * 0.5, player.duration - 2)
            let selectedAudioIndex = player.backendEngineForTesting?.audioTracks.firstIndex(where: { $0.isSelected })
            let selectedSubtitleIndex = player.backendEngineForTesting?.textTracks.firstIndex(where: { $0.isSelected })
            let video = player.displayedVideoFrames, audio = player.playedAudioBuffers
            player.seek(target)
            defer { print("NAS numeric outputEvents=\(outputEvents.snapshot())") }
            try await wait("seek output", player: player) {
                guard let clock = player.backendClockTime else { return false }
                return clock >= target - 0.5 && clock < target + 8
                    && player.displayedVideoFrames > video + 3 && player.playedAudioBuffers > audio + 3
                    && player.seekStatus == nil && player.errorMessage == nil
            }
            XCTAssertEqual(player.backendEngineForTesting?.audioTracks.firstIndex(where: { $0.isSelected }), selectedAudioIndex)
            XCTAssertEqual(player.backendEngineForTesting?.textTracks.firstIndex(where: { $0.isSelected }), selectedSubtitleIndex)
            print("NAS numeric compatibilityRetry=\(player.backendStreamingDemuxWasRetried)")
            let failure = await stream.readFailure()
            XCTAssertNil(failure)
            player.stop()
            await stream.stop()
            await provider.close()
        } catch {
            print("NAS diagnostic backend=\(player.backendState) sourceFailure=\(await stream.readFailure() != nil) appError=\(player.errorMessage ?? "none")")
            for (name, data) in [("numeric-player-lifecycle", player.debugLifecycleTraceData()),
                                 ("numeric-stream-lifecycle", await stream.debugTraceData())] {
                if let data {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = name
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
            player.stop(); await stream.stop(); await provider.close()
            throw error
        }
    }

    private func wait(_ label: String, player: FilmPlayer, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(100)) }
        print("NAS numeric phase=\(label) duration=\(player.duration) position=\(player.position) clock=\(player.backendClockTime ?? -1) video=\(player.displayedVideoFrames) audio=\(player.playedAudioBuffers) error=\(player.errorMessage != nil)")
        XCTAssertTrue(condition(), "Private NAS must produce real audio/video output within the deadline.")
        if !condition() { throw FilmError.missingFile }
    }
    private func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

private final class SafeOutputEvents: NSObject, VLCLogging, @unchecked Sendable {
    var level: VLCLogLevel = .debug
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var deltas: [Int64] = []
    private var clockEvents: [[Int64]] = []
    func handleMessage(_ message: String, logLevel: VLCLogLevel, context: VLCLogContext?) {
        let prefixes = ["starting late (", "deferring start (", "started",
                        "AVQueuedSampleBufferRenderingStatusFailed", "discontinuity: flushing output",
                        "playback too late (", "CMBlockBufferRef creation failure", "CMSampleBufferRef creation failure",
                        "new clock context(", "ES_OUT_RESET_PCR called",
                        "using demux module \"avformat\"", "using demux module \"mp4\""]
        let clockContext = message.hasPrefix("clock(") && message.contains("clock context(")
        guard let index = clockContext ? 12 : prefixes.firstIndex(where: { message.hasPrefix($0) }) else { return }
        let range = index < 2 ? message.range(of: "-?[0-9]+", options: .regularExpression) : nil
        let delta = range.flatMap { Int64(message[$0]) }
        let expression = try? NSRegularExpression(pattern: "-?[0-9]+")
        let values = (index == 8 || index == 9 || index == 12) ? (expression?.matches(in: message, range: NSRange(message.startIndex..., in: message)) ?? []).compactMap {
            Range($0.range, in: message).flatMap { Int64(message[$0]) }
        } : []
        lock.withLock {
            counts[String(index), default: 0] += 1
            if let delta, deltas.count < 128 { deltas.append(delta) }
            if (index == 8 || index == 9 || index == 12), clockEvents.count < 128 { clockEvents.append([Int64(index)] + values) }
        }
    }
    func snapshot() -> String { lock.withLock { "counts=\(counts) deltasMicroseconds=\(deltas) clockEvents=\(clockEvents)" } }
}

#endif
