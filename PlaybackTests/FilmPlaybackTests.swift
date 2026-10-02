import XCTest
import VLCKit
import FilmDomain
import FilmSources
import VideoToolbox
@testable import AetherFilm

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// These tests decode real generated media. Run desktop UI tests in the
/// macos27 VM. A simulator result does not prove iPhone hardware/output support.
@MainActor
final class FilmPlaybackTests: XCTestCase {
    private var player: FilmPlayer!
    #if os(macOS)
    private var window: NSWindow!
    private var surface: VLCVideoView!
    #elseif os(iOS)
    private var window: UIWindow!
    private var surface: UIView!
    private weak var previousKeyWindow: UIWindow?
    #endif

    override func setUp() async throws {
        player = FilmPlayer()
        #if os(macOS)
        window = NSWindow(contentRect: NSRect(x: 60, y: 60, width: 640, height: 360),
                          styleMask: [.titled], backing: .buffered, defer: false)
        surface = VLCVideoView(frame: NSRect(x: 0, y: 0, width: 640, height: 360))
        surface.backColor = .black
        window.contentView = surface
        window.orderFront(nil)
        #elseif os(iOS)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first,
                                 "The iOS playback test needs an initialized application scene.")
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = UIViewController()
        surface = UIView(frame: window.bounds)
        surface.backgroundColor = .black
        window.rootViewController?.view.addSubview(surface)
        window.makeKeyAndVisible()
        #endif
        player.attachDrawable(surface)
    }

    override func tearDown() async throws {
        player?.stop()
        player?.detachDrawable(surface)
        #if os(macOS)
        window?.close()
        #elseif os(iOS)
        window?.isHidden = true
        previousKeyWindow?.makeKeyAndVisible()
        previousKeyWindow = nil
        #endif
        window = nil
        surface = nil
        player = nil
    }

    func testCommonContainersProduceVideoAndAudioOutput() async throws {
        for name in ["clip-h264.mp4", "clip-hevc.mov", "clip-mpeg4.avi", "clip-multitrack.mkv"] {
            player.load(url: try fixture(name))
            try await waitUntil("\(name): decode and output") { self.player.position > 0.8 && self.player.displayedVideoFrames > 0
                && self.player.playedAudioBuffers > 0 }
            XCTAssertNil(player.errorMessage, name)
            XCTAssertGreaterThan(player.duration, 11, name)
            XCTAssertGreaterThan(player.decodedVideoFrames, 0, name)
            XCTAssertGreaterThan(player.decodedAudioBuffers, 0, name)
            player.stop()
        }
    }

    func test4KHEVCProducesVideoAndAudioOutput() async throws {
        player.capturesDecoderEvidence = true
        player.load(url: try fixture("clip-4k-hevc.mp4"))
        try await waitUntil("4K HEVC actual video and audio output", timeout: 30) {
            self.player.position > 0.8 && self.player.displayedVideoFrames > 0 && self.player.playedAudioBuffers > 0
        }
        XCTAssertGreaterThan(player.duration, 5)
        XCTAssertGreaterThan(player.decodedVideoFrames, 0)
        XCTAssertGreaterThan(player.decodedAudioBuffers, 0)
        XCTAssertNil(player.errorMessage)
        let hardwareCapability = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)
        print("4K HEVC: VideoToolbox selected=\(player.videoToolboxSelected), "
              + "acceptedFrame=\(player.videoToolboxAcceptedFrame), hardwareCapability=\(hardwareCapability)")
        #if os(iOS) && !targetEnvironment(simulator)
        if hardwareCapability {
            try await waitUntil("4K HEVC VideoToolbox decoder accepted a frame", timeout: 3) {
                self.player.videoToolboxSelected && self.player.videoToolboxAcceptedFrame
            }
        }
        #endif
        // Output counters establish decoding/output, not hardware acceleration.
        // The release also needs separate VideoToolbox and real-device evidence.
    }

    func testPauseSeekRateResumeAndNaturalCompletion() async throws {
        let url = try fixture("clip-h264.mp4")
        player.load(url: url, startAt: 2)
        try await waitUntil("resume at two seconds") { self.player.position >= 2.1 }
        player.pause()
        try await Task.sleep(for: .milliseconds(300))
        let paused = player.position
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertEqual(player.position, paused, accuracy: 0.35)
        XCTAssertFalse(player.isPlaying)
        player.seek(4)
        try await waitUntil("seek while paused") { abs(self.player.position - 4) < 0.5 }
        player.setRate(2)
        player.play()
        let before = player.position
        try await waitUntil("double speed progression") { self.player.position > before + 1.5 }
        XCTAssertTrue(player.isPlaying)
        XCTAssertTrue(player.isSeekable)
        player.setVolume(0.5)
        XCTAssertEqual(player.volume, 0.5)
        XCTAssertEqual(player.appliedVolume ?? -1, 0.5, accuracy: 0.02)
        var ended = false
        player.onEnded = { ended = true }
        player.seek(11)
        try await waitUntil("natural completion", timeout: 6) { ended }
        XCTAssertEqual(player.position, player.duration, accuracy: 0.2)
        XCTAssertNil(player.errorMessage)
    }

    func testRapidPauseResumeSettlesInLatestRequestedState() async throws {
        player.load(url: try fixture("clip-h264.mp4"))
        try await waitUntil("rapid controls initial output") { self.player.position > 0.8 && self.player.displayedVideoFrames > 0 }
        let before = player.position
        for _ in 0..<10 {
            player.pause()
            player.play()
            try await Task.sleep(for: .milliseconds(20))
        }
        try await waitUntil("latest rapid control request resumes actual playback") {
            self.player.isPlaying && self.player.position > before + 0.5
        }
        player.pause()
        try await Task.sleep(for: .milliseconds(300))
        let paused = player.position
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.position, paused, accuracy: 0.35)
    }

    func testTracksEmbeddedAndExternalSubtitlesAndChapters() async throws {
        player.load(url: try fixture("clip-multitrack.mkv"))
        try await waitUntil("discover embedded audio and subtitle tracks") { self.player.audioTracks.count >= 2 && self.player.subtitleTracks.count >= 2 }
        player.pause()
        let audioID = try XCTUnwrap(player.audioTracks.last?.id)
        player.selectAudio(audioID)
        try await waitUntil("select second audio track") { self.player.selectedAudioID == audioID }
        for track in player.subtitleTracks {
            player.selectSubtitle(track.id)
            try await waitUntil("select embedded subtitle") { self.player.selectedSubtitleID == track.id }
        }
        player.selectSubtitle(nil)
        try await waitUntil("disable embedded subtitles") { self.player.selectedSubtitleID == nil }
        XCTAssertGreaterThanOrEqual(player.chapters.count, 2)
        XCTAssertEqual(player.chapters[1].time ?? 0, 6, accuracy: 0.1)
        player.selectChapter(player.chapters[1].id)
        try await waitUntil("jump to second chapter") { self.player.position >= 5.5 }
        player.addSubtitle(try fixture("external.srt"))
        try await waitUntil("register and select external SRT") { self.player.subtitleTracks.count >= 3 && self.player.selectedSubtitleID != nil }
        let srtID = player.selectedSubtitleID
        player.addSubtitle(try fixture("external.ass"))
        try await waitUntil("register and select external ASS") {
            self.player.subtitleTracks.count >= 4 && self.player.selectedSubtitleID != nil && self.player.selectedSubtitleID != srtID
        }
        let assID = player.selectedSubtitleID
        player.addSubtitle(try fixture("external.vtt"))
        try await waitUntil("register and select external WebVTT") {
            self.player.subtitleTracks.count >= 5 && self.player.selectedSubtitleID != nil && self.player.selectedSubtitleID != assID
        }
        player.setSubtitleDelay(0.5)
        player.setSubtitleScale(1.4)
        XCTAssertEqual(player.subtitleDelay, 0.5)
        XCTAssertEqual(player.subtitleScale, 1.4)
        player.seek(6)
        try await waitUntil("seek with external subtitles") { self.player.position >= 5.5 }
        player.play()
        try await waitUntil("real playback after chapter and subtitle seeks") { self.player.position >= 6.4 }
        XCTAssertEqual(player.backendChapterID, player.chapters[1].id)
        XCTAssertNil(player.errorMessage)
        XCTAssertNil(player.subtitleErrorMessage)
    }

    func testBrokenMediaFailsWithoutFinishingAndRapidSwitchIgnoresOldSession() async throws {
        var ended = false
        player.onEnded = { ended = true }
        player.load(url: try fixture("broken.mkv"))
        try await waitUntil("report malformed media error") { self.player.errorMessage != nil }
        XCTAssertFalse(ended)
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isLoading)
        player.load(url: try fixture("broken.mkv"))
        player.load(url: try fixture("clip-h264.mp4"))
        try await waitUntil("rapid switch to valid video") { self.player.position > 0.8 && self.player.displayedVideoFrames > 0 }
        XCTAssertNil(player.errorMessage)
        XCTAssertFalse(ended)
        player.stop()
        let stopped = player.position
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isLoading)
        XCTAssertEqual(player.position, stopped, accuracy: 0.05)
        XCTAssertFalse(ended)
    }

    func testUnavailableSubtitleFailsWithoutStoppingVideoAndCanRetry() async throws {
        let video = try fixture("clip-h264.mp4")
        player.load(url: video)
        try await waitUntil("subtitle failure initial video output") { self.player.position > 0.8 && self.player.displayedVideoFrames > 0 }
        let missing = video.deletingLastPathComponent().appendingPathComponent("missing-subtitle.srt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
        player.addSubtitle(missing)
        try await waitUntil("asynchronous subtitle failure reports a recoverable error", timeout: 7) { self.player.subtitleErrorMessage != nil }
        XCTAssertNil(player.errorMessage, "A subtitle failure must not cover the video with a playback error.")
        XCTAssertTrue(player.isPlaying)
        let before = player.position
        let displayed = player.displayedVideoFrames
        let played = player.playedAudioBuffers
        try await waitUntil("video and audio continue after unavailable subtitle") {
            self.player.position > before + 0.3 && self.player.displayedVideoFrames > displayed && self.player.playedAudioBuffers > played
        }
        player.addSubtitle(try fixture("external.srt"))
        try await waitUntil("retry adds and selects a real subtitle") { self.player.selectedSubtitleID != nil }
        XCTAssertNil(player.subtitleErrorMessage, "A successful retry clears the recoverable subtitle error.")
        XCTAssertNil(player.errorMessage)
        player.addSubtitle(video.deletingLastPathComponent().appendingPathComponent("unsupported.txt"))
        XCTAssertNotNil(player.subtitleErrorMessage)
        XCTAssertNil(player.errorMessage)
        XCTAssertTrue(player.isPlaying)
        var ended = false
        player.onEnded = { ended = true }
        player.seek(11)
        try await waitUntil("subtitle failure does not prevent natural video completion", timeout: 6) { ended }
        player.onEnded = nil
        player.load(url: video)
        XCTAssertNil(player.subtitleErrorMessage, "Opening another video clears the subtitle error.")
        try await waitUntil("new video after subtitle error produces output") { self.player.position > 0.8 }
        XCTAssertNil(player.errorMessage)
        player.addSubtitle(missing)
        player.load(url: video)
        try await waitUntil("new video ignores the previous subtitle loader") { self.player.position > 0.8 }
        XCTAssertNil(player.subtitleErrorMessage)
        XCTAssertNil(player.errorMessage)
    }

    func testRealSMBStreamRepeatedSeekAndReopenReleasesReads() async throws {
        let configuration = try await SMBPlaybackFixture.configuration()
        let connection = SMBConnection(name: "Playback fixture", host: "127.0.0.1", port: configuration.port,
                                       share: configuration.share, rootPath: configuration.mediaPath)
        let credentials = SMBCredentials(username: configuration.username, password: configuration.password)
        let provider = CountingSMBProvider()
        let path = try SMBPath.joining(configuration.mediaPath, "clip-smb-long.mp4")
        let size = try await provider.fileSize(connection, credentials: credentials, path: path)
        XCTAssertGreaterThan(size, 20 * 1_024 * 1_024, "Use the generated long SMB fixture to verify streaming.")

        for cycle in 0..<2 {
            let server = SMBStreamingServer(provider: provider, connection: connection, credentials: credentials,
                                            path: path, size: size)
            do {
                let previousBytes = await provider.bytesRead
                player.load(url: try await server.start())
                try await waitUntil("SMB cycle \(cycle): actual video and audio output", timeout: 20) {
                    self.player.position > 0.8 && self.player.displayedVideoFrames > 0 && self.player.playedAudioBuffers > 0
                }
                let initialBytes = await provider.bytesRead - previousBytes
                XCTAssertLessThan(initialBytes, size, "Playback should begin before reading the entire NAS video.")
                XCTAssertTrue(player.isSeekable)
                player.pause()
                for target: Double in [62, 3, 55, 8, 68, 2, 45, 12, 60, 4] {
                    let displayed = player.displayedVideoFrames
                    player.seek(target)
                    player.play()
                    try await waitUntil("SMB cycle \(cycle): seek to \(Int(target)) seconds") {
                        self.player.position > target + 0.2 && self.player.position < target + 2
                            && self.player.displayedVideoFrames > displayed
                    }
                    player.pause()
                }
                player.play()
                let position = player.position
                try await waitUntil("SMB cycle \(cycle): resume after repeated seeks") { self.player.position > position + 0.5 }
                player.stop()
                await server.stop()
                let stoppedBytes = await provider.bytesRead
                try await Task.sleep(for: .milliseconds(600))
                let settledBytes = await provider.bytesRead
                XCTAssertEqual(settledBytes, stoppedBytes, "Closing the stream must stop NAS reads.")
                XCTAssertFalse(player.isPlaying)
                XCTAssertNil(player.errorMessage)
            } catch {
                player.stop()
                await server.stop()
                throw error
            }
        }
        await provider.close()
    }

    private func fixture(_ filename: String) throws -> URL {
        let bundle = Bundle(for: Self.self)
        let folders = [
            bundle.resourceURL?.appendingPathComponent("PlaybackFixtures"),
            bundle.resourceURL,
            ProcessInfo.processInfo.environment["AETHERFILM_FIXTURES"].map { URL(fileURLWithPath: $0) }
        ].compactMap { $0 }
        let file = folders.map { $0.appendingPathComponent(filename) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
        return try XCTUnwrap(file, "Missing \(filename). Run PlaybackTests/generate_fixtures.py before building the test bundle.")
    }

    private func waitUntil(_ label: String, timeout: Double = 12, _ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var nextDiagnostic = Date().addingTimeInterval(0.5)
        while !condition() && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
            if Date() >= nextDiagnostic {
                // This suite only opens generated media. Never log video URLs
                // or fixture credentials; names here are synthetic subtitles.
                print("Playback check=\(label), position=\(player.position), "
                      + "audioTracks=\(player.audioTracks.count), subtitles=\(player.subtitleTracks.map(\.name)), "
                      + "backendSubtitles=\(player.backendSubtitleTracks.map(\.name)), "
                      + "subtitleIDLengths=\(player.subtitleTracks.map { $0.id.count }), "
                      + "selectedSubtitle=\(player.selectedSubtitleID != nil), chapters=\(player.chapters.count)")
                nextDiagnostic = Date().addingTimeInterval(0.5)
            }
        }
        XCTAssertTrue(condition(), "\(label) timed out; error=\(player.errorMessage ?? "none"), "
                      + "subtitleError=\(player.subtitleErrorMessage ?? "none"), "
                      + "position=\(player.position), duration=\(player.duration), playing=\(player.isPlaying), "
                      + "audioTracks=\(player.audioTracks.count), subtitleTracks=\(player.subtitleTracks.count), "
                      + "selectedSubtitle=\(player.selectedSubtitleID != nil), chapters=\(player.chapters.count), "
                      + "videoDecoded=\(player.decodedVideoFrames), videoDisplayed=\(player.displayedVideoFrames), "
                      + "audioPlayed=\(player.playedAudioBuffers)")
        if !condition() { throw PlaybackTestError.timeout }
    }
}

private enum PlaybackTestError: Error { case timeout }

private struct SMBPlaybackFixture: Decodable {
    let port: Int
    let username: String
    let password: String
    let share: String
    let mediaPath: String

    static func configuration() async throws -> Self {
        let environment = ProcessInfo.processInfo.environment
        if let address = environment["AETHERFILM_SMB_BOOTSTRAP_URL"],
           let url = URL(string: address), url.scheme == "http", url.host == "127.0.0.1" {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw PlaybackTestError.timeout }
            return try JSONDecoder().decode(Self.self, from: data)
        }
        guard let value = environment["AETHERFILM_SMB_TEST_PORT"], let port = Int(value),
              let password = environment["AETHERFILM_SMB_TEST_PASSWORD"] else {
            throw XCTSkip("Run the SMB fixture launcher and pass AETHERFILM_SMB_BOOTSTRAP_URL to the test runner.")
        }
        return Self(port: port, username: "aetherfilm-fixture", password: password, share: "FILMS",
                    mediaPath: environment["AETHERFILM_SMB_MEDIA_PATH"] ?? "media")
    }
}

/// Uses the real SMB adapter. The small delay keeps reads in flight so seeks
/// and teardown exercise cancellation rather than only the decoder's cache.
private actor CountingSMBProvider: SMBFileProviding {
    private let provider = SMBProvider()
    private(set) var bytesRead: Int64 = 0

    func testConnection(_ connection: SMBConnection, credentials: SMBCredentials) async throws {
        try await provider.testConnection(connection, credentials: credentials)
    }

    func listDirectory(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> [MediaItem] {
        try await provider.listDirectory(connection, credentials: credentials, path: path)
    }

    func fileSize(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> Int64 {
        try await provider.fileSize(connection, credentials: credentials, path: path)
    }

    func readFile(_ connection: SMBConnection, credentials: SMBCredentials, path: String, range: Range<Int64>) async throws -> Data {
        try await Task.sleep(for: .milliseconds(100))
        let data = try await provider.readFile(connection, credentials: credentials, path: path, range: range)
        bytesRead += Int64(data.count)
        return data
    }

    func close() async { await provider.close() }
}
