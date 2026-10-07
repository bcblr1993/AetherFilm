import XCTest
import VLCKit
import FilmDomain
import FilmSources
import VideoToolbox
@testable import AetherFilm

/// Raw counters belong to one native engine. Recovery must prove fresh output
/// on its new engine rather than compare against counters from the old one.
private enum SMBSeekOutputGate {
    static func accepts(target: Double, cachedTime: Double, normalTime: Double,
                        freshRunningClock: Bool, originalEngine: Bool, permittedRecovery: Bool,
                        displayedBefore: UInt64, playedBefore: UInt64,
                        displayedNow: UInt64, playedNow: UInt64) -> Bool {
        guard freshRunningClock, originalEngine || permittedRecovery,
              cachedTime > target + 0.2, cachedTime < target + 2,
              normalTime > target + 0.2, normalTime < target + 2 else { return false }
        return displayedNow > (originalEngine ? displayedBefore : 0)
            && playedNow > (originalEngine ? playedBefore : 0)
    }
}

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
    private var diagnosticOrigin = ContinuousClock.now
    #if os(macOS)
    private var window: NSWindow!
    private var surface: VLCVideoView!
    #elseif os(iOS)
    private var window: UIWindow!
    private var surface: UIView!
    private weak var previousKeyWindow: UIWindow?
    #endif

    override func setUp() async throws {
        diagnosticOrigin = .now
        player = FilmPlayer()
        #if os(macOS)
        window = NSWindow(contentRect: NSRect(x: 60, y: 60, width: 640, height: 360),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        surface = VLCVideoView(frame: NSRect(x: 0, y: 0, width: 640, height: 360))
        surface.backColor = .black
        window.contentView = surface
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Isolated host diagnostic: prepare the real AppKit window before load.
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(window.isVisible, "The owned playback window must be visible before media load.")
        print("MAC_WINDOW_PREP policy=\(NSApp.activationPolicy().rawValue) running=\(NSApp.isRunning ? 1 : 0) active=\(NSApp.isActive ? 1 : 0) key=\(window.isKeyWindow ? 1 : 0) visible=\(window.isVisible ? 1 : 0) occlusion=\(window.occlusionState.contains(.visible) ? 1 : 0) attached=\(surface.window === window ? 1 : 0) width=\(surface.bounds.width) height=\(surface.bounds.height)")
        XCTAssertTrue(surface.window === window, "The drawable must be attached to the owned window before media load.")
        XCTAssertGreaterThan(surface.bounds.width, 0)
        XCTAssertGreaterThan(surface.bounds.height, 0)
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

    func testDelayedActualPauseCallbackKeepsToggleConsistentWithPlayback() async throws {
        player.load(url: try fixture("clip-h264.mp4"))
        try await waitUntil("race probe initial real video and audio output") {
            self.player.isPlaying && self.player.backendState == "playing" && self.player.backendIsPlaying == true
                && (self.player.backendTime ?? 0) > 0.8 && self.player.displayedVideoFrames > 0
                && self.player.playedAudioBuffers > 0
        }
        player.debugHoldNextPausedCallback()
        player.pause()
        try await waitUntil("race probe captured actual paused callback") {
            self.player.debugHasHeldPausedCallback && self.player.backendState == "paused"
                && self.player.backendIsPlaying == false
        }
        let pausedTime = try XCTUnwrap(player.backendTime)
        let frames = player.displayedVideoFrames
        let audio = player.playedAudioBuffers
        player.play()
        try await waitUntil("race probe resumed actual output before delayed event") {
            self.player.isPlaying && self.player.backendState == "playing" && self.player.backendIsPlaying == true
                && (self.player.backendTime ?? 0) > pausedTime + 0.3
                && self.player.displayedVideoFrames > frames && self.player.playedAudioBuffers > audio
        }
        let callbacks = player.debugPausedCallbacksReceived
        player.debugReleaseHeldPausedCallback()
        try await waitUntil("race probe released actual paused callback was consumed") {
            self.player.debugPausedCallbacksReceived > callbacks
        }
        printPlaybackDiagnostic("race probe model after late paused event", phase: "snapshot")
        XCTAssertTrue(player.isPlaying, "A late paused event must not show play while real output is playing.")
        XCTAssertEqual(player.backendState, "playing")
        XCTAssertEqual(player.backendIsPlaying, true)
        let lateTime = try XCTUnwrap(player.backendTime)
        let lateFrames = player.displayedVideoFrames
        try await waitUntil("race probe backend still advances after late event") {
            (self.player.backendTime ?? 0) > lateTime + 0.3 && self.player.displayedVideoFrames > lateFrames
        }
        player.toggle()
        // Keep executing after the model assertion so this tests the actual
        // button action. No direct setter or fake engine state is involved.
        let deadline = Date().addingTimeInterval(3)
        while !(player.backendState == "paused" && player.backendIsPlaying == false) && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        printPlaybackDiagnostic("race probe toggle actual outcome", phase: "snapshot")
        XCTAssertEqual(player.backendState, "paused", "Toggle must pause the real backend after the delayed callback.")
        XCTAssertEqual(player.backendIsPlaying, false)
        XCTAssertFalse(player.isPlaying)
        try await Task.sleep(for: .milliseconds(300))
        let stillTime = try XCTUnwrap(player.backendTime)
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertEqual(player.backendTime ?? -1, stillTime, accuracy: 0.35,
                       "The real backend time must remain still after toggle.")
        printPlaybackDiagnostic("race probe toggle stillness", phase: "snapshot")
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
        try await waitUntil("backend confirms pause before measuring stillness") {
            self.player.backendState == "paused" && self.player.backendIsPlaying == false
        }
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
        try await waitUntil("backend confirms the final rapid-control pause") {
            self.player.backendState == "paused" && self.player.backendIsPlaying == false
        }
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
        #if DEBUG
        player.debugEnableLifecycleTrace(origin: diagnosticOrigin)
        #endif
        let configuration = try await SMBPlaybackFixture.configuration()
        let connection = SMBConnection(name: "Playback fixture", host: configuration.host ?? "127.0.0.1", port: configuration.port,
                                       share: configuration.share, rootPath: configuration.mediaPath)
        let credentials = SMBCredentials(username: configuration.username, password: configuration.password)
        let provider = CountingSMBProvider(diagnosticOrigin: diagnosticOrigin)
        let path = try SMBPath.joining(configuration.mediaPath, "clip-smb-long.mp4")
        let size = try await provider.fileSize(connection, credentials: credentials, path: path)
        XCTAssertGreaterThan(size, 20 * 1_024 * 1_024, "Use the generated long SMB fixture to verify streaming.")

        for cycle in 0..<2 {
            let server = SMBStreamingServer(provider: provider, connection: connection, credentials: credentials,
                                            path: path, size: size)
            #if DEBUG
            await server.debugEnableTrace(origin: diagnosticOrigin)
            #endif
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
                    let identity = ObjectIdentifier(try XCTUnwrap(player.backendEngineForTesting))
                    let mediaURL = try XCTUnwrap(player.backendEngineForTesting?.media?.url)
                    let displayed = player.displayedVideoFrames
                    let played = player.playedAudioBuffers
                    player.seek(target)
                    player.play()
                    try await waitUntil("SMB cycle \(cycle): seek to \(Int(target)) seconds", traceInitialSeek: true) {
                        guard let engine = self.player.backendEngineForTesting,
                              let time = self.player.backendTime,
                              let normal = self.player.backendClockTime,
                              let trace = TailPhaseTrace.capture(self.player),
                              let marker = trace.latestSeekMarker(), marker.targetSeconds == target else { return false }
                        let freshClock = trace.records.contains { record in
                            guard record.eventCode == 31, record.generation == marker.generation,
                                  let callback = trace.pairedCallback(for: record, callbackCode: 30),
                                  callback.sequence > marker.sequence,
                                  let microseconds = record.timeMicroseconds,
                                  let date = record.systemDateMicroseconds, date > 0, date != Int64.max else { return false }
                            return abs(normal - Double(microseconds) / 1_000_000) < 0.000002
                        }
                        return SMBSeekOutputGate.accepts(target: target, cachedTime: time, normalTime: normal,
                            freshRunningClock: freshClock && self.player.backendClockIsRunning,
                            originalEngine: ObjectIdentifier(engine) == identity,
                            permittedRecovery: self.player.backendStreamingDemuxWasRetried && engine.media?.url == mediaURL,
                            displayedBefore: displayed, playedBefore: played,
                            displayedNow: self.player.displayedVideoFrames, playedNow: self.player.playedAudioBuffers)
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
                #if DEBUG
                await attachSMBFailureDiagnostics(server: server, provider: provider)
                #else
                await attachSMBReadTimeline(provider)
                #endif
                player.stop()
                await server.stop()
                await provider.close()
                throw error
            }
        }
        await provider.close()
        await attachSMBReadTimeline(provider)
    }

    func testSMBSeekOutputGateRejectsStaleOutputAcrossEngineRecovery() {
        func accepts(original: Bool = false, recovery: Bool = true, fresh: Bool = true,
                     normal: Double = 13.089496, displayed: UInt64 = 41, played: UInt64 = 110) -> Bool {
            SMBSeekOutputGate.accepts(target: 12, cachedTime: 13.089, normalTime: normal,
                freshRunningClock: fresh, originalEngine: original, permittedRecovery: recovery,
                displayedBefore: 164, playedBefore: 637, displayedNow: displayed, playedNow: played)
        }
        // Counts and clock taken from the retained CI failure: genuine new
        // output belongs to the replacement engine, whose counters start at 0.
        XCTAssertTrue(accepts())
        XCTAssertFalse(accepts(original: true), "Same-engine output must still exceed its own pre-seek counters.")
        XCTAssertFalse(accepts(recovery: false), "An unrelated engine must not satisfy the old seek.")
        XCTAssertFalse(accepts(fresh: false), "A cached target without a fresh running normal callback is insufficient.")
        XCTAssertFalse(accepts(normal: 14), "Recovery must keep the original upper time bound.")
        XCTAssertFalse(accepts(displayed: 0), "Old-engine frames cannot stand in for new-engine output.")
        XCTAssertFalse(accepts(played: 0), "The new engine must produce real audio as well as video.")
        XCTAssertTrue(accepts(original: true, displayed: 165, played: 638))
    }

    private func attachSMBReadTimeline(_ provider: CountingSMBProvider) async {
        guard let data = try? await provider.diagnosticData() else { return }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "Generated SMB fixture read timeline"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    #if DEBUG
    private func attachSMBFailureDiagnostics(server: SMBStreamingServer, provider: CountingSMBProvider) async {
        var snapshot: [String: Any] = ["schemaVersion": 1]
        let traces = ["playerLifecycle": player.debugLifecycleTraceData(),
                      "streamingHTTP": await server.debugTraceData(),
                      "countingProvider": try? await provider.diagnosticData()]
        for (key, data) in traces {
            if let data, let object = try? JSONSerialization.jsonObject(with: data) { snapshot[key] = object }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: snapshot, options: [.sortedKeys]) else { return }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "Generated SMB fixture playback failure timeline"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    #endif

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

    private func waitUntil(_ label: String, timeout: Double = 12, traceInitialSeek: Bool = false,
                           _ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        let fastDiagnosticDeadline = traceInitialSeek ? Date().addingTimeInterval(2) : nil
        var nextDiagnostic = Date().addingTimeInterval(traceInitialSeek ? 0.1 : 0.5)
        printPlaybackDiagnostic(label, phase: "begin")
        while !condition() && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
            if Date() >= nextDiagnostic {
                // This suite only opens generated media. Never log video URLs
                // or fixture credentials; names here are synthetic subtitles.
                printPlaybackDiagnostic(label, phase: "pending")
                let interval = fastDiagnosticDeadline.map { Date() < $0 } == true ? 0.1 : 0.5
                nextDiagnostic = Date().addingTimeInterval(interval)
            }
        }
        printPlaybackDiagnostic(label, phase: condition() ? "ready" : "timeout")
        XCTAssertTrue(condition(), "\(label) timed out; error=\(player.errorMessage ?? "none"), "
                      + "subtitleError=\(player.subtitleErrorMessage ?? "none"), "
                      + "position=\(player.position), duration=\(player.duration), playing=\(player.isPlaying), "
                      + "backendState=\(player.backendState), backendPlaying=\(String(describing: player.backendIsPlaying)), "
                      + "backendTime=\(String(describing: player.backendTime)), "
                      + "audioTracks=\(player.audioTracks.count), subtitleTracks=\(player.subtitleTracks.count), "
                      + "selectedSubtitle=\(player.selectedSubtitleID != nil), chapters=\(player.chapters.count), "
                      + "videoDecoded=\(player.decodedVideoFrames), videoDisplayed=\(player.displayedVideoFrames), "
                      + "audioDecoded=\(player.decodedAudioBuffers), "
                      + "audioPlayed=\(player.playedAudioBuffers)")
        if !condition() { throw PlaybackTestError.timeout }
    }

    private func printPlaybackDiagnostic(_ label: String, phase: String) {
        print("Playback t=\(String(format: "%.3f", diagnosticElapsed(since: diagnosticOrigin))) "
              + "check=\(label), phase=\(phase), position=\(player.position), "
              + "backendState=\(player.backendState), backendPlaying=\(String(describing: player.backendIsPlaying)), "
              + "backendTime=\(String(describing: player.backendTime)), "
              + "videoDecoded=\(player.decodedVideoFrames), videoDisplayed=\(player.displayedVideoFrames), "
              + "audioDecoded=\(player.decodedAudioBuffers), audioPlayed=\(player.playedAudioBuffers), "
              + "audioTracks=\(player.audioTracks.count), subtitles=\(player.subtitleTracks.map(\.name)), "
              + "backendSubtitles=\(player.backendSubtitleTracks.map(\.name)), "
              + "subtitleIDLengths=\(player.subtitleTracks.map { $0.id.count }), "
              + "selectedSubtitle=\(player.selectedSubtitleID != nil), chapters=\(player.chapters.count)")
    }
}

private enum PlaybackTestError: Error { case timeout }

private func diagnosticElapsed(since origin: ContinuousClock.Instant) -> Double {
    let components = origin.duration(to: .now).components
    return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
}

private struct SMBPlaybackFixture: Decodable {
    let host: String?
    let port: Int
    let username: String
    let password: String
    let share: String
    let mediaPath: String

    static func configuration() async throws -> Self {
        let environment = ProcessInfo.processInfo.environment
        let expectedHost = environment["AETHERFILM_SMB_TEST_HOST"] ?? "127.0.0.1"
        if let address = environment["AETHERFILM_SMB_BOOTSTRAP_URL"],
           let url = URL(string: address), url.scheme == "http", url.host == expectedHost {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw PlaybackTestError.timeout }
            let fixture = try JSONDecoder().decode(Self.self, from: data)
            guard (fixture.host ?? "127.0.0.1") == expectedHost else { throw PlaybackTestError.timeout }
            return fixture
        }
        guard let value = environment["AETHERFILM_SMB_TEST_PORT"], let port = Int(value),
              let password = environment["AETHERFILM_SMB_TEST_PASSWORD"] else {
            throw XCTSkip("Run the SMB fixture launcher and pass AETHERFILM_SMB_BOOTSTRAP_URL to the test runner.")
        }
        return Self(host: nil, port: port, username: "aetherfilm-fixture", password: password, share: "FILMS",
                    mediaPath: environment["AETHERFILM_SMB_MEDIA_PATH"] ?? "media")
    }
}

/// Uses the real SMB adapter. The small delay keeps reads in flight so seeks
/// and teardown exercise cancellation rather than only the decoder's cache.
private actor CountingSMBProvider: SMBFileProviding {
    private let provider = SMBProvider()
    private let diagnosticOrigin: ContinuousClock.Instant
    private var nextReadID = 0
    private var readEvents: [ReadEvent] = []
    private var omittedEvents = 0
    private(set) var bytesRead: Int64 = 0

    private struct ReadEvent: Encodable {
        let id: Int
        let phase: String
        let elapsed: Double
        let offset: Int64
        let requestedBytes: Int64
        let actualBytes: Int
        let totalBytes: Int64
    }

    init(diagnosticOrigin: ContinuousClock.Instant) {
        self.diagnosticOrigin = diagnosticOrigin
    }

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
        nextReadID += 1
        let id = nextReadID
        recordRead(id: id, phase: "begin", range: range)
        do {
            try await Task.sleep(for: .milliseconds(100))
            let data = try await provider.readFile(connection, credentials: credentials, path: path, range: range)
            bytesRead += Int64(data.count)
            recordRead(id: id, phase: "end", range: range, actualBytes: data.count)
            return data
        } catch {
            // Log only a safe phase. Error descriptions can contain network
            // addresses or paths and are deliberately excluded from fixtures.
            recordRead(id: id, phase: Task.isCancelled || error is CancellationError ? "cancel" : "failure", range: range)
            throw error
        }
    }

    private func recordRead(id: Int, phase: String, range: Range<Int64>, actualBytes: Int = 0) {
        let event = ReadEvent(id: id, phase: phase, elapsed: diagnosticElapsed(since: diagnosticOrigin),
                              offset: range.lowerBound, requestedBytes: range.upperBound - range.lowerBound,
                              actualBytes: actualBytes, totalBytes: bytesRead)
        // Bound console output and the attachment if a stalled client retries
        // excessively. The generated normal scenario fits these limits.
        if readEvents.count < 1_024 { readEvents.append(event) } else { omittedEvents += 1 }
        if id <= 160 {
            print("SMB fixture t=\(String(format: "%.3f", event.elapsed)), read=\(id), phase=\(phase), "
                  + "offset=\(event.offset), requestedBytes=\(event.requestedBytes), "
                  + "actualBytes=\(actualBytes), totalBytes=\(bytesRead)")
        }
    }

    func diagnosticData() throws -> Data {
        struct Timeline: Encodable {
            let events: [ReadEvent]
            let totalReadRequests: Int
            let totalBytes: Int64
            let omittedEvents: Int
            let consoleReadLimit: Int
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Timeline(events: readEvents, totalReadRequests: nextReadID, totalBytes: bytesRead,
                                           omittedEvents: omittedEvents, consoleReadLimit: 160))
    }

    func close() async {
        await provider.close()
        print("SMB fixture summary requests=\(nextReadID), totalBytes=\(bytesRead), "
              + "attachedEvents=\(readEvents.count), omittedEvents=\(omittedEvents), consoleReadLimit=160")
    }
}
