import XCTest
import VLCKit
import AetherVLCBridge
@testable import AetherFilm

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Isolated runtime candidate only. Read actual public callback state, existing
/// paired normal/input trace and decoder output; never inject any of those.
@MainActor
final class SeekUIStatusPlaybackTests: XCTestCase {
    private var player: FilmPlayer!
    private var origin = ContinuousClock.now
    private var observations: [SeekUIRuntimeObservation] = []
    private var ended = 0
    #if os(macOS)
    private var window: NSWindow!
    private var surface: VLCVideoView!
    #else
    private var window: UIWindow!
    private var surface: UIView!
    private weak var previousKeyWindow: UIWindow?
    #endif

    override func setUp() async throws {
        origin = .now
        observations = []
        ended = 0
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
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(window.isVisible)
        XCTAssertTrue(surface.window === window)
        XCTAssertGreaterThan(surface.bounds.width, 0)
        XCTAssertGreaterThan(surface.bounds.height, 0)
        #else
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first)
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
        player.debugEnableLifecycleTrace(origin: origin)
        player.onEnded = { [weak self] in self?.ended += 1 }
    }

    override func tearDown() async throws {
        record("teardown-before-stop")
        if let data = try? JSONEncoder().encode(observations) {
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "Actual seek UI and readonly engine observations"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        if let data = player?.debugLifecycleTraceData() {
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "Actual paired normal and input callbacks"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        player?.stop()
        player?.detachDrawable(surface)
        #if os(macOS)
        window?.close()
        #else
        window?.isHidden = true
        previousKeyWindow?.makeKeyAndVisible()
        previousKeyWindow = nil
        #endif
        player = nil
        window = nil
        surface = nil
    }

    func testHealthySeekAndSubmitPauseRateChangeUseActualOutput() async throws {
        player.load(url: try fixture("clip-short-gop.mp4"), startAt: 2)
        try await wait("actual local start2 warm-up", timeout: 12) {
            self.player.duration > 11 && (self.player.backendClockTime ?? 0) > 2.8
                && self.player.backendClockIsRunning && self.player.displayedVideoFrames > 0
                && self.player.playedAudioBuffers > 0
        }
        let engine = try XCTUnwrap(player.backendEngineForTesting)
        let identity = ObjectIdentifier(engine)
        let previousClock = try XCTUnwrap(player.backendClockTime)
        let previousInput = try XCTUnwrap(player.backendInputTime)
        let callbackBaseline = engine.seekCallbackSequence
        let video = player.displayedVideoFrames
        let audio = player.playedAudioBuffers
        player.seek(0)
        XCTAssertEqual(player.seekStatus, .seeking)
        XCTAssertNil(player.backendClockTime)
        XCTAssertNil(player.backendInputTime)
        let marker = try currentMarker(target: 0)
        record("healthy-zero-submitted")
        try await wait("actual local zero rewind and UI settled", timeout: 6, pending: {
            if self.player.seekStatus == nil {
                XCTAssertTrue(self.hasActualClockAndInput(after: marker, paused: false))
                XCTAssertTrue(self.player.displayedVideoFrames > video || self.player.playedAudioBuffers > audio)
                XCTAssertGreaterThan(engine.seekCallbackSequence, callbackBaseline)
                XCTAssertFalse(engine.isSeeking)
            }
        }) {
            self.player.seekStatus == nil && engine.seekCallbackSequence > callbackBaseline && !engine.isSeeking
                && self.hasActualClockAndInput(after: marker, paused: false)
                && (self.player.backendClockTime ?? 99) < previousClock
                && (self.player.backendInputTime ?? 99) < previousInput
                && (self.player.backendClockTime ?? 0) > 0.8
                && self.player.displayedVideoFrames > video + 5 && self.player.playedAudioBuffers > audio + 5
        }
        XCTAssertEqual(player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
        XCTAssertEqual(ended, 0)

        // These are real public commands after submission, with no fake time,
        // rate or paused callback. The later lower rate must not leave UI stuck.
        let previewBaseline = player.displayedVideoFrames
        let pauseCallbackBaseline = engine.seekCallbackSequence
        player.seek(4)
        XCTAssertEqual(player.seekStatus, .seeking)
        let pauseMarker = try currentMarker(target: 4)
        player.setRate(3)
        player.pause()
        player.setRate(0.5)
        record("seek-then-real-rate3-pause-rate05")
        try await wait("real submitted seek reaches paused preview", timeout: 6, pending: {
            if self.player.seekStatus == nil {
                XCTAssertTrue(self.hasActualClockAndInput(after: pauseMarker, paused: true))
                XCTAssertGreaterThan(self.player.displayedVideoFrames, previewBaseline)
            }
        }) {
            self.player.seekStatus == nil && engine.seekCallbackSequence > pauseCallbackBaseline && !engine.isSeeking
                && self.player.backendState == "paused" && self.player.backendIsPlaying == false
                && !self.player.isPlaying && !self.player.backendClockIsRunning
                && self.hasActualClockAndInput(after: pauseMarker, paused: true)
                && abs((self.player.backendClockTime ?? -99) - 4) < 1
                && abs((self.player.backendInputTime ?? -99) - 4) < 1
                && self.player.displayedVideoFrames > previewBaseline
        }
        try await assertRemainsPausedWithoutStatus(seconds: 1)
        XCTAssertEqual(player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
        XCTAssertNil(player.errorMessage)
        XCTAssertEqual(ended, 0)
    }

    func testPausedSeekClearsOnlyAfterNewActualPreviewAndStaysPaused() async throws {
        try await loadLongFixture()
        player.pause()
        try await wait("actual backend pause before preview request", timeout: 6) {
            self.player.backendState == "paused" && self.player.backendIsPlaying == false && !self.player.isPlaying
        }
        let engine = try XCTUnwrap(player.backendEngineForTesting)
        let identity = ObjectIdentifier(engine)
        let callbackBaseline = engine.seekCallbackSequence
        let displayed = player.displayedVideoFrames
        player.seek(8)
        XCTAssertEqual(player.seekStatus, .seeking)
        XCTAssertNil(player.backendClockTime)
        XCTAssertFalse(player.backendClockIsRunning)
        let marker = try currentMarker(target: 8)
        record("genuinely-paused-seek-eight")
        try await wait("actual paused new preview and UI cleared", timeout: 6, pending: {
            XCTAssertFalse(self.player.isPlaying, "A preview request must not resume user playback.")
            if self.player.seekStatus == nil {
                XCTAssertTrue(self.hasActualClockAndInput(after: marker, paused: true))
                XCTAssertGreaterThan(self.player.displayedVideoFrames, displayed)
            }
        }) {
            self.player.seekStatus == nil && engine.seekCallbackSequence > callbackBaseline && !engine.isSeeking
                && self.player.backendState == "paused" && self.player.backendIsPlaying == false
                && !self.player.backendClockIsRunning && self.hasActualClockAndInput(after: marker, paused: true)
                && abs((self.player.backendClockTime ?? -99) - 8) < 1
                && abs((self.player.backendInputTime ?? -99) - 8) < 1
                && self.player.displayedVideoFrames > displayed
        }
        try await assertRemainsPausedWithoutStatus(seconds: 3.4)
        XCTAssertEqual(player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
        XCTAssertEqual(ended, 0)
        XCTAssertNil(player.errorMessage)
    }

    func testRapidSameAndDifferentTargetsKeepFinalActualOutputAndStatus() async throws {
        try await loadLongFixture()
        let engine = try XCTUnwrap(player.backendEngineForTesting)
        let identity = ObjectIdentifier(engine)
        let callbackBaseline = engine.seekCallbackSequence
        let displayed = player.displayedVideoFrames
        let played = player.playedAudioBuffers
        // No MainActor yield between requests. Genuine callbacks may be queued
        // while later commands are submitted. The core may coalesce controls.
        player.seek(4)
        XCTAssertEqual(player.seekStatus, .seeking)
        record("rapid-first-four")
        player.seek(4)
        XCTAssertEqual(player.seekStatus, .seeking)
        record("rapid-second-same-four")
        player.seek(12)
        XCTAssertEqual(player.seekStatus, .seeking)
        record("rapid-final-twelve")
        let marker = try currentMarker(target: 12)
        try await wait("last actual twelve-second request and UI cleared", timeout: 6, pending: {
            if self.player.seekStatus == nil {
                XCTAssertTrue(self.hasActualClockAndInput(after: marker, paused: false))
                XCTAssertGreaterThan(engine.seekCallbackSequence, callbackBaseline)
                XCTAssertFalse(engine.isSeeking)
                XCTAssertGreaterThanOrEqual(self.player.backendClockTime ?? -1, 11)
                XCTAssertGreaterThanOrEqual(self.player.backendInputTime ?? -1, 11)
                XCTAssertTrue(self.player.displayedVideoFrames > displayed || self.player.playedAudioBuffers > played)
            }
        }) {
            self.player.seekStatus == nil && engine.seekCallbackSequence > callbackBaseline && !engine.isSeeking
                && self.hasActualClockAndInput(after: marker, paused: false)
                && (self.player.backendClockTime ?? -1) > 12.2 && (self.player.backendClockTime ?? 99) < 18
                && (self.player.backendInputTime ?? -1) >= 11
                && self.player.displayedVideoFrames > displayed + 5 && self.player.playedAudioBuffers > played + 5
        }
        try await assertNoSeekStatus(seconds: 3.4)
        XCTAssertEqual(player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
        XCTAssertEqual(ended, 0)
        XCTAssertNil(player.errorMessage)
        // No injected late callback is used. Observations report whether the
        // actual core emitted/coalesced requests; sequence count is not forced.
    }

    func testStopAndChangeFilmCancelOldRealSeekCallbacksAndTimers() async throws {
        try await loadLongFixture()
        attachCrashPhase("warm-up-before-stop-seek")
        player.seek(20)
        XCTAssertEqual(player.seekStatus, .seeking)
        record("seek-before-real-stop")
        attachCrashPhase("submitted-seek-before-stop")
        player.stop()
        XCTAssertNil(player.seekStatus)
        try await assertNoSeekStatus(seconds: 3.4)
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(ended, 0)

        try await loadLongFixture()
        let oldIdentity = ObjectIdentifier(try XCTUnwrap(player.backendEngineForTesting))
        attachCrashPhase("warm-up-before-change-seek")
        player.seek(30)
        XCTAssertEqual(player.seekStatus, .seeking)
        record("old-session-seek-before-change")
        attachCrashPhase("submitted-seek-before-film-change")
        player.load(url: try fixture("clip-h264.mp4"))
        XCTAssertNil(player.seekStatus)
        record("real-new-film-load-clears-old-presentation")
        try await wait("new film actual video and audio", timeout: 12, pending: {
            XCTAssertNil(self.player.seekStatus, "The old session must not give the new film a pending seek.")
        }) {
            (self.player.backendClockTime ?? 0) > 0.8 && self.player.backendClockIsRunning
                && self.player.displayedVideoFrames > 0 && self.player.playedAudioBuffers > 0
        }
        XCTAssertNotEqual(player.backendEngineForTesting.map(ObjectIdentifier.init), oldIdentity)
        try await assertNoSeekStatus(seconds: 3.4)
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(ended, 0)
        XCTAssertNil(player.errorMessage)
    }

    private func loadLongFixture() async throws {
        player.load(url: try fixture("clip-smb-long.mp4"))
        try await wait("real long local video and audio warm-up", timeout: 12) {
            self.player.duration > 70 && (self.player.backendClockTime ?? 0) > 0.8
                && self.player.backendClockIsRunning && self.player.displayedVideoFrames > 0
                && self.player.playedAudioBuffers > 0
        }
    }

    private func fixture(_ name: String) throws -> URL {
        let resource = try XCTUnwrap(Bundle(for: Self.self).resourceURL)
        let url = resource.appendingPathComponent("PlaybackFixtures").appendingPathComponent(name)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        return url
    }

    private func currentMarker(target: Double) throws -> TailPhaseTrace.Record {
        let trace = try JSONDecoder().decode(TailPhaseTrace.self, from: XCTUnwrap(player.debugLifecycleTraceData()))
        XCTAssertEqual(trace.evictedEvents, 0)
        let marker = try XCTUnwrap(trace.latestSeekMarker())
        XCTAssertEqual(marker.targetSeconds, target)
        return marker
    }

    private func hasActualClockAndInput(after marker: TailPhaseTrace.Record, paused: Bool) -> Bool {
        guard let data = player.debugLifecycleTraceData(),
              let trace = try? JSONDecoder().decode(TailPhaseTrace.self, from: data), trace.evictedEvents == 0,
              trace.latestSeekMarker()?.sequence == marker.sequence,
              let clock = player.backendClockTime, clock.isFinite,
              let input = player.backendInputTime, input.isFinite,
              let normal = trace.records.last(where: { record in
                  guard record.eventCode == 31, record.generation == marker.generation,
                        let callback = trace.pairedCallback(for: record, callbackCode: 30),
                        callback.sequence > marker.sequence, let time = record.timeMicroseconds,
                        let date = record.systemDateMicroseconds else { return false }
                  return abs(clock - Double(time) / 1_000_000) < 0.000002
                      && (paused ? date == Int64.max : date > 0 && date != Int64.max)
              }),
              trace.records.contains(where: { record in
                  guard record.eventCode == 41, record.generation == marker.generation,
                        let callback = trace.pairedCallback(for: record, callbackCode: 40),
                        callback.sequence > marker.sequence, let time = record.timeMicroseconds else { return false }
                  return abs(input - Double(time) / 1_000_000) < 0.000002
              }) else { return false }
        return normal.sourceSequence != nil && (paused ? !player.backendClockIsRunning : player.backendClockIsRunning)
    }

    private func record(_ phase: String) {
        if let player { observations.append(.capture(player: player, origin: origin, phase: phase)) }
    }

    // A native process crash bypasses tearDown. Export the existing readonly
    // observations before the commands under investigation, without URLs or logs.
    private func attachCrashPhase(_ phase: String) {
        record(phase)
        for (label, data) in [
            ("observations", try? JSONEncoder().encode(observations)),
            ("native clock", player.debugLifecycleTraceData())
        ] {
            guard let data else { continue }
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "Actual stop/change \(phase) \(label)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func wait(_ label: String, timeout: Double,
                      pending: @MainActor () -> Void = {},
                      condition: @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        while true {
            record(label)
            pending()
            if condition() { return }
            if .now >= deadline { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail(label + " exceeded its declared actual playback deadline.")
        throw SeekUIRuntimeError.timeout
    }

    private func assertNoSeekStatus(seconds: Double) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(seconds))
        repeat {
            record("old-timer-observation")
            XCTAssertNil(player.seekStatus)
            XCTAssertEqual(ended, 0)
            XCTAssertNil(player.errorMessage)
            try await Task.sleep(for: .milliseconds(100))
        } while .now < deadline
        XCTAssertNil(player.seekStatus)
    }

    private func assertRemainsPausedWithoutStatus(seconds: Double) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(seconds))
        repeat {
            record("paused-preview-settled")
            XCTAssertNil(player.seekStatus)
            XCTAssertEqual(player.backendState, "paused")
            XCTAssertEqual(player.backendIsPlaying, false)
            XCTAssertFalse(player.isPlaying)
            XCTAssertFalse(player.backendClockIsRunning)
            XCTAssertEqual(ended, 0)
            try await Task.sleep(for: .milliseconds(100))
        } while .now < deadline
        XCTAssertNil(player.seekStatus)
    }
}

/// Actual readonly snapshots shared by the isolated local and SMB UI tests.
/// Callback sequence is identity only. A false seeking flag is not recovery.
struct SeekUIRuntimeObservation: Codable {
    let elapsedSeconds: Double
    let phase: String
    let status: String
    let actualSeekCallbackSequence: UInt64?
    let actualRequestSeeking: Bool?
    let backendState: String
    let actualClock: Double?
    let actualInput: Double?
    let rawCoreTimeMicroseconds: Int64?
    let rawCoreTimeMilliseconds: Double?
    let actualClockRunning: Bool
    let displayedVideoFrames: UInt64
    let playedAudioBuffers: UInt64

    @MainActor
    static func capture(player: FilmPlayer, origin: ContinuousClock.Instant, phase: String) -> Self {
        let elapsed = origin.duration(to: .now).components
        let status: String
        switch player.seekStatus {
        case .seeking: status = "seeking"
        case .waitingForSource: status = "waitingForSource"
        case nil: status = "none"
        }
        let rawCoreTime = player.backendEngineForTesting?.diagnosticCoreTimeMicroseconds
        return .init(elapsedSeconds: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18,
                     phase: phase, status: status,
                     actualSeekCallbackSequence: player.backendEngineForTesting?.seekCallbackSequence,
                     actualRequestSeeking: player.backendEngineForTesting?.isSeeking,
                     backendState: player.backendState, actualClock: player.backendClockTime,
                     actualInput: player.backendInputTime,
                     rawCoreTimeMicroseconds: rawCoreTime,
                     rawCoreTimeMilliseconds: rawCoreTime.map { Double($0) / 1000 },
                     actualClockRunning: player.backendClockIsRunning,
                     displayedVideoFrames: player.displayedVideoFrames, playedAudioBuffers: player.playedAudioBuffers)
    }
}

private enum SeekUIRuntimeError: Error { case timeout }
