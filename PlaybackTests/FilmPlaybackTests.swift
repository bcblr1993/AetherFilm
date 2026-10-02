import XCTest
import VLCKit
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

    func testTracksEmbeddedAndExternalSubtitlesAndChapters() async throws {
        player.load(url: try fixture("clip-multitrack.mkv"))
        try await waitUntil("discover embedded audio and subtitle tracks") { self.player.audioTracks.count >= 2 && self.player.subtitleTracks.count >= 2 }
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
        player.addSubtitle(try fixture("external.ass"))
        try await waitUntil("register external ASS") { self.player.subtitleTracks.count >= 4 }
        player.setSubtitleDelay(0.5)
        player.setSubtitleScale(1.4)
        XCTAssertEqual(player.subtitleDelay, 0.5)
        XCTAssertEqual(player.subtitleScale, 1.4)
        player.seek(6)
        try await waitUntil("seek with external subtitles") { self.player.position >= 5.5 }
        XCTAssertNil(player.errorMessage)
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
        while !condition() && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(condition(), "\(label) timed out; error=\(player.errorMessage ?? "none"), "
                      + "position=\(player.position), duration=\(player.duration), playing=\(player.isPlaying), "
                      + "audioTracks=\(player.audioTracks.count), subtitleTracks=\(player.subtitleTracks.count), "
                      + "selectedSubtitle=\(player.selectedSubtitleID != nil), chapters=\(player.chapters.count), "
                      + "videoDecoded=\(player.decodedVideoFrames), videoDisplayed=\(player.displayedVideoFrames), "
                      + "audioPlayed=\(player.playedAudioBuffers)")
        if !condition() { throw PlaybackTestError.timeout }
    }
}

private enum PlaybackTestError: Error { case timeout }
