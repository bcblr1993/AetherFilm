import XCTest
import VLCKit
import AetherVLCBridge
import FilmDomain
@testable import FilmSources
import FilmLibrary
import Synchronization
import Darwin
import CryptoKit
@testable import AetherFilm

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Actual decoder and output tests. Credentials exist only in fixture memory;
/// the bootstrap URL contains no password and attachments print only numbers.
@MainActor
final class EOFPlaybackTests: XCTestCase {
    private var player: FilmPlayer!
    #if os(macOS)
    private var window: NSWindow!
    private var surface: VLCVideoView!
    #else
    private var window: UIWindow!
    private var surface: UIView!
    private var previousKeyWindow: UIWindow?
    #endif
    private var store: AppStore!
    private var storageURL: URL!
    private var storageDirectory: URL!
    private var item = MediaItem(name: "fixture.mp4", path: "fixture-only")
    private var ended = 0
    private var progressCalls = 0
    private var maximumProgressFraction = 0.0
    private var origin = ContinuousClock.now

    override func setUp() async throws {
        origin = .now
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
        storageDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("AetherFilmEOFFixture-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        storageURL = storageDirectory.appendingPathComponent("library.json")
        store = AppStore(library: LibraryStore(url: storageURL))
        await store.load()
        player = FilmPlayer()
        player.attachDrawable(surface)
        player.onEnded = { [weak self] in self?.ended += 1 }
        player.onPlaybackSessionStarted = { [weak self] in
            guard let self else { return }
            self.store.playingItem = self.item
            let sessionID = self.store.beginPlaybackSession(for: self.item)
            self.player.onProgress = { [weak self] position, duration, confirmed in
                guard let self else { return }
                self.progressCalls += 1
                if duration > 0 { self.maximumProgressFraction = max(self.maximumProgressFraction, position / duration) }
                self.store.recordProgress(self.item, position: position, duration: duration,
                    allowsAutomaticWatched: confirmed, sessionID: sessionID)
            }
            self.player.onPlaybackFailure = { [weak self] in
                guard let self else { return }
                self.store.rejectAutomaticWatched(self.item, sessionID: sessionID)
            }
        }
    }

    override func tearDown() async throws {
        player?.stop()
        if let surface { player?.detachDrawable(surface) }
        #if os(macOS)
        window?.close()
        #else
        window?.isHidden = true
        previousKeyWindow?.makeKeyAndVisible()
        previousKeyWindow = nil
        #endif
        window = nil; surface = nil; player = nil
        await store?.flushProgress()
        store = nil
        if let storageDirectory { try? FileManager.default.removeItem(at: storageDirectory) }
    }

    func testHalfSpeedNaturalCompletionDoesNotDoubleDrainTime() async throws {
        let directory = try XCTUnwrap(Bundle(for: Self.self).resourceURL?.appendingPathComponent("PlaybackFixtures"))
        let url = directory.appendingPathComponent("clip-short-gop.mp4")
        XCTAssertEqual(SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined(),
                       "33e46b39e57f4e6cd56713f013dc573df8cd3b0d9debda10c4bf2a445c16bd75")
        player.debugEnableLifecycleTrace(origin: origin)
        var observations = [[String: Any]]()
        func observe(_ phase: String) {
            let elapsed = origin.duration(to: .now).components
            var sample: [String: Any] = ["phase": phase,
                "elapsedSeconds": Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18,
                "position": player.position, "duration": player.duration, "rate": player.rate,
                "isPlaying": player.isPlaying, "backendState": player.backendState,
                "clockRunning": player.backendClockIsRunning, "ended": ended,
                "displayedVideoFrames": player.displayedVideoFrames, "playedAudioBuffers": player.playedAudioBuffers,
                "hasError": player.errorMessage != nil]
            if let value = player.backendClockTime { sample["normalTime"] = value }
            if let value = player.backendInputTime { sample["inputTime"] = value }
            if let value = player.backendStoppingReason { sample["stoppingReason"] = value }
            observations.append(sample)
        }
        defer {
            observe("final-before-teardown")
            if let data = player.debugLifecycleTraceData() {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "Half-speed natural completion actual lifecycle including failure"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            if let data = try? JSONSerialization.data(withJSONObject: observations, options: [.sortedKeys]) {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "Half-speed natural completion readonly observations including failure"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        player.setRate(0.5)
        player.load(url: url, startAt: 0)
        let identity = ObjectIdentifier(try XCTUnwrap(player.backendEngineForTesting))
        try await outputReady("half-speed natural completion early actual output")
        let ready = ContinuousClock.now
        let firstNormal = try XCTUnwrap(player.backendClockTime)
        let firstInput = try XCTUnwrap(player.backendInputTime)
        XCTAssertGreaterThan(firstNormal, 0.8)
        XCTAssertGreaterThanOrEqual(firstInput, 0)
        XCTAssertLessThanOrEqual(firstNormal, 1.5, "The control must begin with early real normal time.")
        XCTAssertLessThanOrEqual(firstInput, 1.5, "The control must begin with early real input time.")
        XCTAssertEqual(player.duration, 12, accuracy: 0.05)
        XCTAssertEqual(player.rate, 0.5)
        XCTAssertEqual(ended, 0)
        XCTAssertNil(player.errorMessage)
        let displayed = player.displayedVideoFrames
        let played = player.playedAudioBuffers
        let minimumRemaining = max(0, (player.duration - firstInput) / 0.5 - 1)
        observe("early-actual-ready")
        // This is an independent 30-second functional gate, starting at real
        // output readiness. The existing acceptance deadlines stay unchanged.
        try await wait("half-speed natural EOS within thirty seconds", timeout: 30, failIf: {
            observe("awaiting-natural-eos")
        }) { self.ended > 0 }
        let elapsed = ready.duration(to: .now).components
        let completedAfter = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        observations.append(["phase": "completion-timing", "completedAfterReadySeconds": completedAfter,
                             "minimumRemainingSeconds": minimumRemaining, "firstNormal": firstNormal, "firstInput": firstInput])
        XCTAssertGreaterThanOrEqual(completedAfter, minimumRemaining, "EOS must not truncate unplayed half-speed media.")
        XCTAssertLessThanOrEqual(completedAfter, 30)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(player.backendClockTime), 11.9)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(player.backendInputTime), 11.9)
        XCTAssertGreaterThan(player.displayedVideoFrames, displayed + 5)
        XCTAssertGreaterThan(player.playedAudioBuffers, played + 5)
        XCTAssertEqual(player.backendStoppingReason, Int(AetherVLCMediaStoppingReason.endOfStream.rawValue))
        XCTAssertEqual(player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
        XCTAssertEqual(ended, 1)
        XCTAssertFalse(player.isPlaying)
        XCTAssertNil(player.errorMessage)
        try await Task.sleep(for: .milliseconds(300))
        observe("completion-remains-single")
        XCTAssertEqual(ended, 1)
        XCTAssertEqual(player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
    }

    func testNaturalHealthy95PercentConfirmsWatchedBeforeEOS() async throws {
        let directory = try XCTUnwrap(Bundle(for: Self.self).resourceURL?.appendingPathComponent("PlaybackFixtures"))
        player.debugEnableLifecycleTrace(origin: origin)
        // Real half-speed playback gives the public one-second normal cadence
        // room to confirm 95% and pause before EOS. No seek or clock is injected.
        player.setRate(0.5)
        player.load(url: directory.appendingPathComponent("clip-short-gop.mp4"))
        try await outputReady("natural healthy zero-start actual output")
        let identity = ObjectIdentifier(try XCTUnwrap(player.backendEngineForTesting))
        let displayed = player.displayedVideoFrames
        let played = player.playedAudioBuffers
        var checkpoint: [String: Any]?
        var naturalObservations = [[String: Any]]()
        defer {
            if let data = player.debugLifecycleTraceData() {
                let trace = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                trace.name = "Actual natural healthy full timeline including failed qualification"
                trace.lifetime = .keepAlways
                add(trace)
            }
            if let data = try? JSONSerialization.data(withJSONObject: naturalObservations, options: [.sortedKeys]) {
                let trace = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                trace.name = "Actual natural healthy readonly observations including failed qualification"
                trace.lifetime = .keepAlways
                add(trace)
            }
        }
        try await wait("natural healthy actual 95% playing confirmation", timeout: 30) {
            let elapsed = self.origin.duration(to: .now).components
            var sample: [String: Any] = ["elapsedSeconds": Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18,
                "position": self.player.position, "duration": self.player.duration,
                "clockRunning": self.player.backendClockIsRunning, "isPlaying": self.player.isPlaying,
                "backendState": self.player.backendState, "isWatched": self.store.progress(for: self.item)?.isWatched == true,
                "ended": self.ended, "displayedVideoFrames": self.player.displayedVideoFrames,
                "playedAudioBuffers": self.player.playedAudioBuffers]
            if let value = self.player.backendClockTime { sample["normalTime"] = value }
            if let value = self.player.backendInputTime { sample["inputTime"] = value }
            if let value = self.player.backendTime { sample["cachedTime"] = value }
            naturalObservations.append(sample)
            guard self.ended == 0, self.player.isPlaying, self.player.backendClockIsRunning,
                  let engine = self.player.backendEngineForTesting, engine.state == .playing,
                  let clock = self.player.backendClockTime, let input = self.player.backendInputTime,
                  clock >= 11.4, input >= 11.4, clock < self.player.duration, input < self.player.duration,
                  self.player.displayedVideoFrames > displayed + 5, self.player.playedAudioBuffers > played + 5,
                  let data = self.player.debugLifecycleTraceData(),
                  let trace = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (trace["evictedEvents"] as? Int) == 0,
                  let rows = trace["records"] as? [[String: Any]],
                  let point = rows.last(where: { row in
                      (row["eventCode"] as? Int) == 70 && (row["accepted"] as? Bool) == true
                          && (row["state"] as? Int) == Int(engine.state.rawValue)
                          && (row["clockRunning"] as? Bool) == true
                          && (row["targetSeconds"] as? Double).map {
                              $0 >= self.player.duration * 0.95 && $0 < self.player.duration
                          } == true
                          && ((row["displayedVideoFrames"] as? NSNumber)?.uint64Value ?? 0) > displayed + 5
                          && ((row["playedAudioBuffers"] as? NSNumber)?.uint64Value ?? 0) > played + 5
                  }), self.store.progress(for: self.item)?.isWatched == true else { return false }
            checkpoint = point
            return true
        }
        XCTAssertEqual(ended, 0, "Natural healthy progress must confirm watched before any EOS callback.")
        XCTAssertNil(player.errorMessage)
        XCTAssertNil(player.backendStoppingReason)
        let point = try XCTUnwrap(checkpoint)
        let proof = XCTAttachment(data: try JSONSerialization.data(withJSONObject: point, options: [.sortedKeys]),
                                  uniformTypeIdentifier: "public.json")
        proof.name = "Actual healthy playing 95 percent accepted progress checkpoint"
        proof.lifetime = .keepAlways
        add(proof)
        player.pause()
        try await wait("natural healthy confirmed paused before EOS", timeout: 6) {
            self.player.backendEngineForTesting?.state == .paused && !self.player.isPlaying
        }
        XCTAssertEqual(player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
        XCTAssertEqual(ended, 0)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(player.backendClockTime), 11.4)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(player.backendInputTime), 11.4)
        let saved = try await persistedProgress()
        XCTAssertTrue(try XCTUnwrap(saved).isWatched)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(saved).position / player.duration, 0.95)
        XCTAssertLessThan(try XCTUnwrap(saved).position, player.duration)
        let trace = XCTAttachment(data: try XCTUnwrap(player.debugLifecycleTraceData()), uniformTypeIdentifier: "public.json")
        trace.name = "Actual natural healthy 95 percent paused before EOS timeline"
        trace.lifetime = .keepAlways
        add(trace)
    }

    func testAutomatic95WatchedRetractsAfterRealTailReadFailure() async throws {
        XCTAssertFalse(store.progress(for: item)?.isWatched ?? false)
        try await withTailFixture { session in
            var validatorCalls = 0
            var rejected = false
            var checkpoint: [String: Any]?
            var matchedNormal: TailPhaseTrace.Record?
            var matchedInput: TailPhaseTrace.Record?
            var observations = [[String: Any]]()
            defer {
                if let data = self.player.debugLifecycleTraceData() {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "Actual SMB automatic 95 percent source failure full lifecycle"
                    attachment.lifetime = .keepAlways
                    self.add(attachment)
                }
                if let data = try? JSONSerialization.data(withJSONObject: observations, options: [.sortedKeys]) {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "Actual SMB automatic 95 percent readonly observations"
                    attachment.lifetime = .keepAlways
                    self.add(attachment)
                }
            }
            self.player.completionValidator = {
                validatorCalls += 1
                let failure = await session.stream.readFailure()
                rejected = failure != nil
                return failure == nil
            }
            // Actual output normal points confirm 95%; input reports demux progress,
            // so fresh paired input proves this same source remains active.
            self.player.setRate(0.5)
            self.player.load(url: session.url)
            try await self.outputReady("SMB automatic watched natural initial output")
            let identity = ObjectIdentifier(try XCTUnwrap(self.player.backendEngineForTesting))
            let displayed = self.player.displayedVideoFrames
            let played = self.player.playedAudioBuffers
            let initialInput = try XCTUnwrap(self.player.backendInputTime)
            let initialTrace = try JSONDecoder().decode(TailPhaseTrace.self,
                from: XCTUnwrap(self.player.debugLifecycleTraceData()))
            XCTAssertEqual(initialTrace.evictedEvents, 0)
            let baseline = try XCTUnwrap(initialTrace.records.last)
            try await self.wait("SMB output confirmed automatic 95 percent", timeout: 30, failIf: {
                if self.ended != 0 || self.player.errorMessage != nil { throw EOFPlaybackError.timeout }
            }) {
                let elapsed = self.origin.duration(to: .now).components
                var sample: [String: Any] = ["elapsedSeconds": Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18,
                    "position": self.player.position, "duration": self.player.duration,
                    "clockRunning": self.player.backendClockIsRunning, "isPlaying": self.player.isPlaying,
                    "isWatched": self.store.progress(for: self.item)?.isWatched == true,
                    "ended": self.ended, "validatorCalls": validatorCalls,
                    "displayedVideoFrames": self.player.displayedVideoFrames,
                    "playedAudioBuffers": self.player.playedAudioBuffers]
                if let value = self.player.backendClockTime { sample["normalTime"] = value }
                if let value = self.player.backendInputTime { sample["inputTime"] = value }
                observations.append(sample)
                guard self.ended == 0, validatorCalls == 0, self.player.isPlaying, self.player.backendClockIsRunning,
                      let engine = self.player.backendEngineForTesting, engine.state == .playing,
                      ObjectIdentifier(engine) == identity,
                      let clock = self.player.backendClockTime, let input = self.player.backendInputTime,
                      clock >= self.player.duration * 0.95, input > initialInput,
                      clock < self.player.duration, input < self.player.duration,
                      self.player.displayedVideoFrames > displayed + 5, self.player.playedAudioBuffers > played + 5,
                      let data = self.player.debugLifecycleTraceData(),
                      let trace = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      (trace["evictedEvents"] as? Int) == 0,
                      let rows = trace["records"] as? [[String: Any]],
                      let point = rows.last(where: { row in
                          (row["eventCode"] as? Int) == 70 && (row["accepted"] as? Bool) == true
                              && (row["clockRunning"] as? Bool) == true
                              && (row["state"] as? Int) == Int(engine.state.rawValue)
                              && (row["targetSeconds"] as? Double).map {
                                  $0 >= self.player.duration * 0.95 && $0 < self.player.duration
                              } == true
                              && ((row["displayedVideoFrames"] as? NSNumber)?.uint64Value ?? 0) > displayed + 5
                              && ((row["playedAudioBuffers"] as? NSNumber)?.uint64Value ?? 0) > played + 5
                      }), self.store.progress(for: self.item)?.isWatched == true else { return false }
                guard let paired = try? JSONDecoder().decode(TailPhaseTrace.self, from: data),
                      paired.records.last?.generation == baseline.generation,
                      let pointSequence = point["sequence"] as? Int,
                      let pointDate = (point["systemDateMicroseconds"] as? NSNumber)?.int64Value,
                      let pointTime = point["targetSeconds"] as? Double,
                      let normal = paired.records.last(where: { row in
                          guard row.eventCode == 31, row.generation == baseline.generation,
                                row.sequence <= pointSequence,
                                let callback = paired.pairedCallback(for: row, callbackCode: 30),
                                callback.sequence > baseline.sequence,
                                row.systemDateMicroseconds == pointDate, pointDate > 0, pointDate != Int64.max,
                                let time = row.timeMicroseconds else { return false }
                          return Double(time) / 1_000_000 >= pointTime - 0.000002
                              && Double(time) / 1_000_000 < self.player.duration
                      }), let normalSource = normal.sourceSequence,
                      let inputPoint = paired.records.last(where: { row in
                          guard row.eventCode == 41, row.generation == baseline.generation,
                                let callback = paired.pairedCallback(for: row, callbackCode: 40),
                                callback.sequence > baseline.sequence, callback.sequence <= normalSource,
                                let time = row.timeMicroseconds else { return false }
                          return Double(time) / 1_000_000 > initialInput
                              && Double(time) / 1_000_000 < self.player.duration
                      }) else { return false }
                checkpoint = point
                matchedNormal = normal
                matchedInput = inputPoint
                return true
            }
            let beforeProgress = try await self.persistedProgress()
            let before = try XCTUnwrap(beforeProgress)
            XCTAssertTrue(before.isWatched, "Automatic watched must really be flushed and reloaded before the source fault.")
            XCTAssertGreaterThanOrEqual(before.fraction, 0.95)
            XCTAssertLessThan(before.position, before.duration)
            let pending = await session.provider.pendingSnapshot()
            let httpData = await session.stream.debugTraceData()
            let http = try JSONDecoder().decode(TailHTTPTrace.self, from: XCTUnwrap(httpData))
            let active = http.activeTailRequests(holdAt: session.metadata.tailHoldAt)
            let matching = pending.reads.filter { read in
                read.lowerBound == session.metadata.tailHoldAt && read.upperBound == session.metadata.fileBytes
                    && read.httpRequestID.map(active.contains) == true
            }
            XCTAssertTrue(pending.unresolved)
            XCTAssertEqual(http.omittedEvents, 0)
            XCTAssertFalse(matching.isEmpty, "An unresolved real provider UUID must match an active HTTP request over the original complete 391-byte tail.")
            XCTAssertEqual(self.player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
            XCTAssertEqual(self.ended, 0)
            XCTAssertEqual(validatorCalls, 0)
            XCTAssertNil(self.player.errorMessage)
            XCTAssertNil(self.player.backendStoppingReason)
            let beforeFailure = await session.stream.readFailure()
            XCTAssertNil(beforeFailure)
            guard before.isWatched, pending.unresolved, !matching.isEmpty,
                  self.ended == 0, validatorCalls == 0, self.player.errorMessage == nil,
                  beforeFailure == nil else { throw EOFPlaybackError.timeout }
            let proof: [String: Any] = ["acceptedCheckpoint": try XCTUnwrap(checkpoint),
                "actualPostWarmupBoundary": try JSONSerialization.jsonObject(with: JSONEncoder().encode(baseline)),
                "actualInitialInputTime": initialInput,
                "pairedFreshOutputNormal": try JSONSerialization.jsonObject(with: JSONEncoder().encode(XCTUnwrap(matchedNormal))),
                "pairedFreshSourceInput": try JSONSerialization.jsonObject(with: JSONEncoder().encode(XCTUnwrap(matchedInput))),
                "reloadedBeforeFault": try JSONSerialization.jsonObject(with: JSONEncoder().encode(before)),
                "pendingUnresolved": pending.unresolved,
                "allPendingReads": try JSONSerialization.jsonObject(with: JSONEncoder().encode(pending.reads)),
                "activeHTTPRequests": active.sorted(), "tailHoldAt": session.metadata.tailHoldAt,
                "fileBytes": session.metadata.fileBytes, "ended": self.ended, "validatorCalls": validatorCalls]
            let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: proof, options: [.sortedKeys]),
                                          uniformTypeIdentifier: "public.json")
            attachment.name = "Actual automatic watched disk true before matched real tail fault"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            try await session.provider.resolveIfActive(fails: true, matchingHTTPRequests: active)
            try await self.wait("SMB automatic watched actual source failure", timeout: 6) {
                rejected && self.player.errorMessage != nil
            }
            XCTAssertEqual(validatorCalls, 1)
            XCTAssertEqual(self.ended, 0)
            let sourceFailure = await session.stream.readFailure()
            XCTAssertEqual(sourceFailure, SMBError.connectionFailed)
            XCTAssertEqual(self.player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
            let afterProgress = try await self.persistedProgress()
            let after = try XCTUnwrap(afterProgress)
            XCTAssertFalse(after.isWatched, "This session's automatic watched transition must be revoked on disk after its real source failure.")
            XCTAssertGreaterThanOrEqual(after.position, before.position)
            XCTAssertLessThan(after.position, after.duration)
            XCTAssertEqual(after.resumePosition, after.position)
            let saved = XCTAttachment(data: try JSONEncoder().encode(after), uniformTypeIdentifier: "public.json")
            saved.name = "Actual automatic watched disk false after real source failure"
            saved.lifetime = .keepAlways
            self.add(saved)
            await self.attachSMBFailureDiagnostics(session.stream)
        }
    }

    func testPriorWatchedStateSurvivesRealTailReadFailure() async throws {
        try await realTailFailurePreservesWatched(markDuringSession: false)
    }

    func testManualWatchedDuringPlaybackSurvivesRealTailReadFailure() async throws {
        try await realTailFailurePreservesWatched(markDuringSession: true)
    }

    private func realTailFailurePreservesWatched(markDuringSession: Bool) async throws {
        let audioTiming = TailAudioTimingEvents(origin: origin)
        defer {
            if let data = audioTiming.data() {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "Actual watched-retention held tail bounded numeric audio timing"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        if !markDuringSession {
            await store.markWatched(item)
            let prior = try await persistedProgress()
            XCTAssertTrue(try XCTUnwrap(prior).isWatched)
            store = AppStore(library: LibraryStore(url: storageURL))
            await store.load()
            XCTAssertTrue(try XCTUnwrap(store.progress(for: item)).isWatched,
                          "Prior watched state must be loaded into the actual reopened AppStore before playback.")
        }
        try await withTailFixture { session in
            var validatorCalls = 0
            var rejected = false
            self.player.completionValidator = {
                validatorCalls += 1
                let failure = await session.stream.readFailure()
                rejected = failure != nil
                return failure == nil
            }
            self.player.load(url: session.url)
            if let library = self.player.backendEngineForTesting?.libraryInstance {
                library.loggers = (library.loggers ?? []) + [audioTiming]
            }
            try await self.outputReady("watched retention real held-source initial output")
            if markDuringSession { await self.store.markWatched(self.item) }
            let beforeTail = try await self.persistedProgress()
            XCTAssertTrue(try XCTUnwrap(beforeTail).isWatched)
            let displayed = self.player.displayedVideoFrames
            let played = self.player.playedAudioBuffers
            let identity = ObjectIdentifier(try XCTUnwrap(self.player.backendEngineForTesting))
            self.player.seek(10)
            XCTAssertNil(self.player.backendClockTime)
            XCTAssertNil(self.player.backendInputTime)
            XCTAssertFalse(self.player.backendClockIsRunning)
            let oracle = try self.phaseOracle(displayed: displayed, played: played)
            let phase = try await self.tailPhase(oracle: oracle, provider: session.provider,
                stream: session.stream, metadata: session.metadata, engineIdentity: identity,
                validatorCalls: { validatorCalls })
            XCTAssertTrue(phase.ready, "The original real six-second held-tail phase must qualify before failure.")
            if !phase.ready { throw EOFPlaybackError.timeout }
            XCTAssertEqual(self.ended, 0)
            XCTAssertEqual(validatorCalls, 0)
            XCTAssertNil(self.player.errorMessage)
            XCTAssertNil(self.player.backendStoppingReason)
            try await session.provider.resolveIfActive(fails: true, matchingHTTPRequests: phase.activeHTTPRequests)
            try await self.wait("watched retention actual source failure blocks EOS", timeout: 6) {
                rejected && self.player.errorMessage != nil
            }
            XCTAssertEqual(self.ended, 0)
            XCTAssertEqual(validatorCalls, 1)
            let failure = await session.stream.readFailure()
            XCTAssertEqual(failure, SMBError.connectionFailed)
            XCTAssertEqual(self.player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
            let saved = try await self.persistedProgress()
            XCTAssertTrue(try XCTUnwrap(saved).isWatched, "A real source failure must preserve existing or explicitly marked watched state.")
            XCTAssertLessThan(try XCTUnwrap(saved).position, self.player.duration)
            try await Task.sleep(for: .milliseconds(300))
            XCTAssertEqual(self.ended, 0)
            XCTAssertEqual(validatorCalls, 1)
            let retained = try await self.persistedProgress()
            XCTAssertTrue(try XCTUnwrap(retained).isWatched)
            await self.attachSMBFailureDiagnostics(session.stream)
        }
    }

    func testReplayUsesFreshEngineAndRetainsSubtitles() async throws {
        let bundle = Bundle(for: Self.self)
        let directory = try XCTUnwrap(bundle.resourceURL?.appendingPathComponent("PlaybackFixtures"))
        player.setRate(1.5)
        player.setVolume(0.4)
        player.setSubtitleDelay(0.5)
        player.setSubtitleScale(1.2)
        player.setVideoFill(true)
        player.load(url: directory.appendingPathComponent("clip-h264.mp4"))
        try await outputReady("replay initial")
        player.addSubtitle(directory.appendingPathComponent("external.srt"))
        try await wait("replay imported subtitle", timeout: 6) { self.player.selectedSubtitleID != nil }
        player.debugHoldNextPausedCallback()
        player.pause()
        try await wait("replay retain real paused event", timeout: 6) { self.player.debugHasHeldPausedCallback }
        let releaseOldPause = player.debugRetainHeldPausedRelease()
        player.play()
        player.seek(11)
        try await wait("replay first EOS", timeout: 6) { self.ended == 1 }
        let previousEngine = try XCTUnwrap(player.backendEngineForTesting)
        let previousMedia = previousEngine.media
        player.play()
        XCTAssertFalse(player.backendEngineForTesting === previousEngine)
        XCTAssertNil(previousEngine.delegate)
        XCTAssertTrue(player.backendEngineForTesting?.media === previousMedia)
        releaseOldPause()
        try await wait("replay fresh real output", timeout: 6) {
            self.player.isPlaying && (self.player.backendClockTime ?? 0) > 0.4
                && (self.player.backendClockTime ?? 20) < 5
                && self.player.displayedVideoFrames > 3 && self.player.playedAudioBuffers > 3
                && self.player.subtitleTracks.count > 0
        }
        XCTAssertEqual(ended, 1)
        XCTAssertEqual(player.rate, 1.5)
        XCTAssertEqual(player.volume, 0.4)
        XCTAssertEqual(player.subtitleDelay, 0.5)
        XCTAssertEqual(player.subtitleScale, 1.2)
        XCTAssertTrue(player.fillsScreen)
        snapshot("fresh replay after old real pause callback")
        player.seek(11)
        try await wait("replay second EOS once", timeout: 6) { self.ended == 2 }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(ended, 2)
        XCTAssertNil(player.errorMessage)
    }

    func testPendingValidatorOldSessionCannotFinishNewFilm() async throws {
        #if DEBUG
        player.debugEnableLifecycleTrace(origin: origin)
        defer {
            if let data = player.debugLifecycleTraceData() {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "Old validator and new session actual lifecycle including failure"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        #endif
        let directory = try XCTUnwrap(Bundle(for: Self.self).resourceURL?.appendingPathComponent("PlaybackFixtures"))
        var validationEntered = false
        var continuation: CheckedContinuation<Bool, Never>?
        defer { continuation?.resume(returning: false) }
        player.completionValidator = {
            validationEntered = true
            return await withCheckedContinuation { continuation = $0 }
        }
        player.load(url: directory.appendingPathComponent("clip-h264.mp4"))
        try await outputReady("validator old initial")
        player.seek(11)
        try await wait("validator actually pending", timeout: 6) { validationEntered }
        XCTAssertEqual(ended, 0)
        player.load(url: directory.appendingPathComponent("clip-smb-long.mp4"), startAt: 10)
        continuation?.resume(returning: true)
        continuation = nil
        try await wait("validator new real output", timeout: 6) {
            self.player.duration > 74 && self.player.displayedVideoFrames > 3
                && self.player.playedAudioBuffers > 3 && (self.player.backendClockTime ?? 0) > 10.1
        }
        XCTAssertEqual(ended, 0)
        XCTAssertNil(player.errorMessage)
        snapshot("old validation allowed after new session")
    }

    func testRealSMBNearTailReadFailureRejectsCompletion() async throws {
        try await realSMBTail(fails: true)
    }

    func testRealSMBNearTailHealthyReleaseCompletes() async throws {
        try await realSMBTail(fails: false)
    }

    func testRealSMBColdResumeHasOutputAndCompletes() async throws {
        #if DEBUG
        player.debugEnableLifecycleTrace(origin: origin)
        #endif
        let fixture = try await EOFSMBFixture.configuration()
        let credentials = SMBCredentials(username: fixture.username, password: fixture.password)
        let connection = SMBConnection(name: "fixture", host: fixture.host ?? "127.0.0.1", port: fixture.port, share: fixture.share, rootPath: fixture.mediaPath)
        let path = fixture.mediaPath + "/clip-short-gop.mp4"
        let provider = SMBProvider()
        let size = try await provider.fileSize(connection, credentials: credentials, path: path)
        let stream = SMBStreamingServer(provider: provider, connection: connection, credentials: credentials, path: path, size: size)
        #if DEBUG
        await stream.debugEnableTrace(origin: origin)
        #endif
        var validatorCalls = 0
        player.completionValidator = {
            validatorCalls += 1
            return await stream.readFailure() == nil
        }
        let url = try await stream.start()
        player.load(url: url, startAt: 10)
        do {
            var firstOutputClock: Double?
            var firstOutputInput: Double?
            try await wait("SMB initial resume real output", failIf: {
                guard firstOutputClock == nil, self.player.backendClockIsRunning,
                      let clock = self.player.backendClockTime, clock > 0.8,
                      self.player.displayedVideoFrames > 0, self.player.playedAudioBuffers > 0 else { return }
                firstOutputClock = clock
                firstOutputInput = self.player.backendInputTime
                print("EOF SMB first resume output clock=\(clock) input=\(firstOutputInput ?? -1) requested=10")
                XCTAssertGreaterThanOrEqual(clock, 9.95, "The first actual output must honor the requested initial resume position.")
                if clock < 9.95 { throw EOFPlaybackError.invalidResumePoint }
            }) {
                self.player.backendClockIsRunning && (self.player.backendClockTime ?? 0) > 10.06
                    && (self.player.backendClockTime ?? 99) < self.player.duration
                    && (self.player.backendInputTime ?? 0) > 10.06 && (self.player.backendInputTime ?? 99) < self.player.duration
                    && self.player.isPlaying && self.player.displayedVideoFrames > 0 && self.player.playedAudioBuffers > 0
            }
            try await wait("SMB initial resume real EOS", timeout: 6) { self.ended == 1 }
            XCTAssertEqual(validatorCalls, 1)
            XCTAssertNil(player.errorMessage)
            let failure = await stream.readFailure()
            XCTAssertNil(failure)
            snapshot("SMB initial resume completed once")
            player.stop()
            await stream.stop()
            await provider.close()
        } catch {
            #if DEBUG
            await attachSMBFailureDiagnostics(stream)
            #endif
            player.stop()
            await stream.stop()
            await provider.close()
            throw error
        }
    }

    private func realSMBTail(fails: Bool) async throws {
        #if DEBUG
        player.debugEnableLifecycleTrace(origin: origin)
        #endif
        let fixture = try await EOFSMBFixture.configuration()
        let credentials = SMBCredentials(username: fixture.username, password: fixture.password)
        let connection = SMBConnection(name: "fixture", host: fixture.host ?? "127.0.0.1", port: fixture.port, share: fixture.share, rootPath: fixture.mediaPath)
        let path = fixture.mediaPath + "/clip-short-gop.mp4"
        let metadataURL = try XCTUnwrap(Bundle(for: Self.self).resourceURL?
            .appendingPathComponent("PlaybackFixtures/clip-short-gop-tail.json"))
        let metadata = try JSONDecoder().decode(EOFTailMetadata.self, from: Data(contentsOf: metadataURL))
        XCTAssertGreaterThan(metadata.lastVideoPTSBeforeTail, 11.9)
        XCTAssertGreaterThanOrEqual(metadata.firstHeldPTS, 11.966)
        XCTAssertGreaterThan(metadata.fileBytes, metadata.tailHoldAt)
        let provider = TailHeldSMBProvider(holdAt: metadata.tailHoldAt, fileBytes: metadata.fileBytes)
        let size = try await provider.fileSize(connection, credentials: credentials, path: path)
        XCTAssertEqual(size, metadata.fileBytes)
        guard size == metadata.fileBytes else { throw EOFPlaybackError.fixtureUnavailable }
        let stream = SMBStreamingServer(provider: provider, connection: connection, credentials: credentials, path: path, size: size)
        #if DEBUG
        await stream.debugEnableTrace(origin: origin)
        #endif
        var validatorCalls = 0
        var rejected = false
        player.completionValidator = {
            validatorCalls += 1
            let failure = await stream.readFailure()
            rejected = failure != nil
            print("EOF SMB validator calls=\(validatorCalls) sourceFailed=\(rejected)")
            return failure == nil
        }
        let url = try await stream.start()
        player.load(url: url)
        do {
            // Cold opening has its existing real-output gate. The six-second
            // tail gate then measures seeking and presentation on that input.
            try await outputReady("SMB held source initial real output")
            let displayedBeforeSeek = player.displayedVideoFrames
            let playedBeforeSeek = player.playedAudioBuffers
            let engineIdentity = ObjectIdentifier(try XCTUnwrap(player.backendEngineForTesting))
            player.seek(10)
            XCTAssertNil(player.backendClockTime, "A seek must clear its previous normal point before any actor yield.")
            XCTAssertFalse(player.backendClockIsRunning, "A cleared normal point cannot inherit the previous running date.")
            XCTAssertNil(player.backendInputTime, "A seek must clear its previous input point before any actor yield.")
            let oracle = try phaseOracle(displayed: displayedBeforeSeek, played: playedBeforeSeek)
            let phase = try await tailPhase(oracle: oracle, provider: provider, stream: stream,
                                            metadata: metadata, engineIdentity: engineIdentity,
                                            validatorCalls: { validatorCalls })
            XCTAssertTrue(phase.ready, "SMB seek output and active held-tail phase")
            if !phase.ready { throw EOFPlaybackError.timeout }
            let held = await provider.heldReadCount()
            XCTAssertGreaterThan(held, 0, "Actual pending NAS tail read must be reached before release/failure.")
            XCTAssertEqual(ended, 0)
            XCTAssertEqual(validatorCalls, 0)
            XCTAssertNil(player.backendStoppingReason)
            XCTAssertNil(player.errorMessage)
            let initialFailure = await stream.readFailure()
            XCTAssertNil(initialFailure)
            snapshot("SMB near-tail before " + (fails ? "source error" : "healthy release"))
            try await provider.resolveIfActive(fails: fails, matchingHTTPRequests: phase.activeHTTPRequests)
            if fails {
                try await wait("SMB source failure blocks EOS", timeout: 6) { rejected && self.player.errorMessage != nil }
                XCTAssertEqual(ended, 0)
                XCTAssertEqual(validatorCalls, 1)
                let sourceFailure = await stream.readFailure()
                XCTAssertEqual(sourceFailure, SMBError.connectionFailed)
                XCTAssertLessThan(player.position, player.duration, "Failed input must not synthesize the final position.")
                let saved = try await persistedProgress()
                XCTAssertLessThan(saved?.position ?? player.duration, player.duration)
                XCTAssertFalse(try XCTUnwrap(saved).isWatched)
            } else {
                try await wait("SMB healthy real EOS", timeout: 6) { self.ended == 1 }
                XCTAssertEqual(validatorCalls, 1)
                XCTAssertNil(player.errorMessage)
                let finalFailure = await stream.readFailure()
                XCTAssertNil(finalFailure)
                XCTAssertEqual(player.backendStoppingReason, Int(AetherVLCMediaStoppingReason.endOfStream.rawValue))
            }
            try await Task.sleep(for: .milliseconds(300))
            XCTAssertEqual(ended, fails ? 0 : 1, "No delayed callback may repeat or synthesize completion.")
            XCTAssertEqual(validatorCalls, 1)
            snapshot("SMB tail result")
            #if DEBUG
            // Preserve the post-resolution timeline even for a nonthrowing assertion.
            await attachSMBFailureDiagnostics(stream)
            #endif
            player.stop()
            await stream.stop()
            await provider.close()
        } catch {
            #if DEBUG
            await attachSMBFailureDiagnostics(stream)
            #endif
            await provider.resolveForCleanup(fails: true)
            player.stop()
            await stream.stop()
            await provider.close()
            throw error
        }
    }

    func testTailPhaseRejectsRealPlaybackFromZero() async throws {
        // Establish an actual later segment before public seek(0), so the
        // wrong-target counterexample must demonstrate a real normal/input rewind.
        let startAt = 2.0
        try await withTailFixture { session in
            var validatorCalls = 0
            self.player.completionValidator = { validatorCalls += 1; return await session.stream.readFailure() == nil }
            self.player.load(url: session.url, startAt: startAt)
            let identity = ObjectIdentifier(try XCTUnwrap(self.player.backendEngineForTesting))
            try await self.wait("negative from-zero start \(startAt) actual warm-up") {
                self.player.duration > 11 && (self.player.backendClockTime ?? 0) > startAt + 0.8
                    && (self.player.backendClockTime ?? 0) < self.player.duration
                    && self.player.displayedVideoFrames > 0 && self.player.playedAudioBuffers > 0
            }
            XCTAssertEqual(self.player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
            let previousClock = try XCTUnwrap(self.player.backendClockTime)
            let previousInput = try XCTUnwrap(self.player.backendInputTime)
            let warmupTrace = try JSONDecoder().decode(TailPhaseTrace.self,
                from: XCTUnwrap(self.player.debugLifecycleTraceData()))
            let initialMarker = try XCTUnwrap(warmupTrace.latestSeekMarker())
            XCTAssertEqual(initialMarker.targetSeconds, startAt)
            let warmupPoint = try XCTUnwrap(warmupTrace.records.last { record in
                guard record.eventCode == 31, record.generation == initialMarker.generation,
                      let callback = warmupTrace.pairedCallback(for: record, callbackCode: 30),
                      callback.sequence > initialMarker.sequence, let time = record.timeMicroseconds else { return false }
                return abs(previousClock - Double(time) / 1_000_000) < 0.000002
            })
            XCTAssertTrue(self.player.isPlaying)
            XCTAssertTrue(self.player.backendClockIsRunning)
            XCTAssertGreaterThan(warmupPoint.displayedVideoFrames ?? 0, 0)
            XCTAssertGreaterThan(warmupPoint.playedAudioBuffers ?? 0, 0)
            let beforeHTTPData = await session.stream.debugTraceData()
            let beforeHTTP = try JSONDecoder().decode(TailHTTPTrace.self,
                from: XCTUnwrap(beforeHTTPData))
            let displayed = self.player.displayedVideoFrames
            let played = self.player.playedAudioBuffers
            // Real playback restarts at zero. The oracle still expects target
            // ten, modeling a requested seek that was not effectively honored.
            self.player.seek(0)
            XCTAssertNil(self.player.backendClockTime)
            XCTAssertFalse(self.player.backendClockIsRunning, "A cleared normal point cannot inherit the previous running date.")
            XCTAssertNil(self.player.backendInputTime)
            let oracle = try self.phaseOracle(displayed: displayed, played: played, markerTarget: 0)
            XCTAssertGreaterThan(oracle.context.markerSequence, initialMarker.sequence)
            let phase = try await self.tailPhase(oracle: oracle, provider: session.provider,
                stream: session.stream, metadata: session.metadata, engineIdentity: identity,
                validatorCalls: { validatorCalls })
            XCTAssertFalse(phase.ready, "Real from-zero output must not satisfy a seek-to-ten phase.")
            XCTAssertGreaterThan(self.player.displayedVideoFrames, displayed + 5)
            XCTAssertGreaterThan(self.player.playedAudioBuffers, played + 5)
            XCTAssertGreaterThan(try XCTUnwrap(self.player.backendClockTime), 0.8)
            XCTAssertLessThan(try XCTUnwrap(self.player.backendClockTime), 9.95)
            let actualTrace = try JSONDecoder().decode(TailPhaseTrace.self,
                from: XCTUnwrap(self.player.debugLifecycleTraceData()))
            let marker = try XCTUnwrap(actualTrace.latestSeekMarker())
            XCTAssertEqual(marker.sequence, oracle.context.markerSequence)
            XCTAssertEqual(marker.targetSeconds, 0)
            XCTAssertEqual(marker.generation, initialMarker.generation)
            XCTAssertEqual(actualTrace.evictedEvents, 0)
            XCTAssertEqual(self.player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
            XCTAssertTrue(self.player.isPlaying)
            XCTAssertTrue(self.player.backendClockIsRunning)
            let currentRaw = try XCTUnwrap(self.player.backendClockTime)
            let running = try XCTUnwrap(actualTrace.records.last { record in
                guard record.eventCode == 31, record.generation == marker.generation,
                      let callback = actualTrace.pairedCallback(for: record, callbackCode: 30),
                      callback.sequence > marker.sequence, let time = record.timeMicroseconds,
                      let date = record.systemDateMicroseconds, date > 0, date != Int64.max else { return false }
                return abs(currentRaw - Double(time) / 1_000_000) < 0.000002
            })
            let runningSource = try XCTUnwrap(running.sourceSequence)
            let rewoundNormals = actualTrace.records.filter { record in
                guard record.eventCode == 31, record.generation == marker.generation,
                      let callback = actualTrace.pairedCallback(for: record, callbackCode: 30),
                      callback.sequence > marker.sequence, callback.sequence <= runningSource,
                      let time = record.timeMicroseconds else { return false }
                return time >= 0 && Double(time) / 1_000_000 < previousClock
            }
            let rewoundInputs = actualTrace.records.filter { record in
                guard record.eventCode == 41, record.generation == marker.generation,
                      let callback = actualTrace.pairedCallback(for: record, callbackCode: 40),
                      callback.sequence > marker.sequence, callback.sequence <= runningSource,
                      let time = record.timeMicroseconds else { return false }
                return time >= 0 && Double(time) / 1_000_000 < previousInput
            }
            XCTAssertFalse(rewoundNormals.isEmpty, "A new paired normal point must demonstrate actual rewind below the pre-seek segment.")
            XCTAssertFalse(rewoundInputs.isEmpty, "A new paired input point must demonstrate actual rewind below the pre-seek input.")
            let pending = await session.provider.pendingSnapshot()
            XCTAssertGreaterThan(pending.reads.count, 0)
            XCTAssertTrue(pending.unresolved)
            XCTAssertFalse(phase.activeHTTPRequests.isEmpty, "The held input must still match a nonterminal actual HTTP request.")
            XCTAssertEqual(self.ended, 0)
            XCTAssertEqual(validatorCalls, 0)
            XCTAssertNil(self.player.errorMessage)
            let sourceFailure = await session.stream.readFailure()
            XCTAssertNil(sourceFailure)
            XCTAssertNil(self.player.backendStoppingReason)
            struct RewindProof: Encodable {
                let diagnosticStartAt: Double
                let previousClock: Double
                let previousInput: Double
                let initialMarker: TailPhaseTrace.Record
                let initialNormalPoint: TailPhaseTrace.Record
                let actualZeroMarker: TailPhaseTrace.Record
                let currentRunningPoint: TailPhaseTrace.Record
                let rewoundNormals: [TailPhaseTrace.Record]
                let rewoundInputs: [TailPhaseTrace.Record]
                let HTTPSequenceBeforeZeroSeek: UInt64
                let HTTPRequestIDsBeforeZeroSeek: [UInt64]
                let newHTTPEvents: [TailHTTPTrace.Event]
                let lowerRangeIsNotAssumed = true
            }
            let afterHTTPData = await session.stream.debugTraceData()
            let afterHTTP = try JSONDecoder().decode(TailHTTPTrace.self,
                from: XCTUnwrap(afterHTTPData))
            XCTAssertEqual(beforeHTTP.omittedEvents, 0)
            XCTAssertEqual(afterHTTP.omittedEvents, 0)
            let lastHTTPSequence = beforeHTTP.events.last?.sequence ?? 0
            let rewindProof = RewindProof(diagnosticStartAt: startAt,
                previousClock: previousClock, previousInput: previousInput, initialMarker: initialMarker,
                initialNormalPoint: warmupPoint, actualZeroMarker: marker, currentRunningPoint: running,
                rewoundNormals: rewoundNormals, rewoundInputs: rewoundInputs,
                HTTPSequenceBeforeZeroSeek: lastHTTPSequence,
                HTTPRequestIDsBeforeZeroSeek: Set(beforeHTTP.events.map(\.requestID)).sorted(),
                newHTTPEvents: afterHTTP.events.filter { $0.sequence > lastHTTPSequence })
            let attachment = XCTAttachment(data: try JSONEncoder().encode(rewindProof), uniformTypeIdentifier: "public.json")
            attachment.name = "Generated held-source actual seek-zero rewind and HTTP diagnostic"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            await self.attachSMBFailureDiagnostics(session.stream)
        }
    }

    func testCompleteSMBSourceActiveSeekZeroContinues() async throws {
        // Separate complete-source control alongside the held-source negative
        // test. Both exercise a public seek to zero on an active player.
        player.debugEnableLifecycleTrace(origin: origin)
        let fixture = try await EOFSMBFixture.configuration()
        let credentials = SMBCredentials(username: fixture.username, password: fixture.password)
        let connection = SMBConnection(name: "fixture", host: fixture.host ?? "127.0.0.1", port: fixture.port,
                                       share: fixture.share, rootPath: fixture.mediaPath)
        let path = fixture.mediaPath + "/clip-short-gop.mp4"
        let resource = try XCTUnwrap(Bundle(for: Self.self).resourceURL?.appendingPathComponent("PlaybackFixtures"))
        let metadataData = try Data(contentsOf: resource.appendingPathComponent("clip-short-gop-tail.json"))
        let metadata = try JSONDecoder().decode(EOFTailMetadata.self, from: metadataData)
        let metadataJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: metadataData) as? [String: Any])
        let expectedSHA = try XCTUnwrap(metadataJSON["sha256"] as? String)
        let bundleData = try Data(contentsOf: resource.appendingPathComponent("clip-short-gop.mp4"))
        func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        XCTAssertEqual(sha(bundleData), expectedSHA)
        XCTAssertEqual(Int64(bundleData.count), metadata.fileBytes)
        let provider = SMBProvider()
        let size = try await provider.fileSize(connection, credentials: credentials, path: path)
        XCTAssertEqual(size, metadata.fileBytes)
        guard size == metadata.fileBytes else { throw EOFPlaybackError.fixtureUnavailable }
        let actualSMBData = try await provider.readFile(connection, credentials: credentials, path: path, range: 0..<size)
        XCTAssertEqual(Int64(actualSMBData.count), size)
        XCTAssertEqual(sha(actualSMBData), expectedSHA, "The complete-source control must read the same real SMB fixture.")
        let stream = SMBStreamingServer(provider: provider, connection: connection, credentials: credentials, path: path, size: size)
        await stream.debugEnableTrace(origin: origin)
        var validatorCalls = 0
        player.completionValidator = { validatorCalls += 1; return await stream.readFailure() == nil }
        do {
            let url = try await stream.start()
            player.load(url: url)
            try await outputReady("complete SMB active seek-zero warm-up")
            let previousClock = try XCTUnwrap(player.backendClockTime)
            let previousInput = player.backendInputTime
            let displayed = player.displayedVideoFrames
            let played = player.playedAudioBuffers
            let identity = ObjectIdentifier(try XCTUnwrap(player.backendEngineForTesting))
            XCTAssertGreaterThan(previousClock, 0.8)
            XCTAssertLessThan(previousClock, player.duration)
            XCTAssertTrue(player.isPlaying)
            player.seek(0)
            XCTAssertNil(player.backendClockTime)
            XCTAssertFalse(player.backendClockIsRunning)
            XCTAssertNil(player.backendInputTime)
            let initialTrace = try JSONDecoder().decode(TailPhaseTrace.self, from: XCTUnwrap(player.debugLifecycleTraceData()))
            let marker = try XCTUnwrap(initialTrace.latestSeekMarker())
            XCTAssertEqual(marker.targetSeconds, 0)
            let began = ContinuousClock.now
            let deadline = began.advanced(by: .seconds(6))
            var samples: [TailPhaseSample] = []
            var matchedRunning: TailPhaseTrace.Record?
            var matchedInputs: [TailPhaseTrace.Record] = []
            var rewindObserved = false
            var ready = false
            while true {
                let sourceFailed = await stream.readFailure() != nil
                let trace = try JSONDecoder().decode(TailPhaseTrace.self, from: XCTUnwrap(player.debugLifecycleTraceData()))
                let normals = trace.records.filter { record in
                    guard record.eventCode == 31, record.generation == marker.generation,
                          let callback = trace.pairedCallback(for: record, callbackCode: 30),
                          callback.sequence > marker.sequence, let time = record.timeMicroseconds else { return false }
                    return time >= 0 && Double(time) / 1_000_000 < 9.95
                }
                matchedRunning = normals.last { record in
                    guard let time = record.timeMicroseconds, let date = record.systemDateMicroseconds,
                          date > 0, date != Int64.max, let raw = player.backendClockTime else { return false }
                    return abs(raw - Double(time) / 1_000_000) < 0.000002
                }
                let runningSource = matchedRunning?.sourceSequence ?? -1
                let runningTime = matchedRunning?.timeMicroseconds ?? -1
                let advancing = normals.contains {
                    ($0.sourceSequence ?? Int.max) < runningSource && ($0.timeMicroseconds ?? Int64.max) < runningTime
                }
                matchedInputs = trace.records.filter { record in
                    guard record.eventCode == 41, record.generation == marker.generation,
                          let callback = trace.pairedCallback(for: record, callbackCode: 40),
                          callback.sequence > marker.sequence, callback.sequence <= runningSource,
                          let time = record.timeMicroseconds else { return false }
                    return time >= 0 && Double(time) / 1_000_000 < 9.95
                }
                let clockRewound = normals.contains {
                    ($0.sourceSequence ?? Int.max) <= runningSource && Double($0.timeMicroseconds ?? Int64.max) / 1_000_000 < previousClock
                }
                let inputRewound = previousInput.map { previous in
                    matchedInputs.contains { Double($0.timeMicroseconds ?? Int64.max) / 1_000_000 < previous }
                } ?? false
                rewindObserved = rewindObserved || clockRewound || inputRewound
                let sample = TailPhaseObservation(
                    engineIdentityMatches: player.backendEngineForTesting.map(ObjectIdentifier.init) == identity,
                    currentGeneration: trace.records.map(\.generation).max() ?? -1,
                    rawClock: player.backendClockTime, rawClockIsRunning: player.backendClockIsRunning,
                    displayed: player.displayedVideoFrames, played: player.playedAudioBuffers,
                    cache: player.backendTime, isPlaying: player.isPlaying, activeTailPending: false,
                    ended: ended, validatorCalls: validatorCalls, hasPlayerError: player.errorMessage != nil,
                    hasSourceFailure: sourceFailed, stoppingReason: player.backendStoppingReason)
                ready = trace.evictedEvents == 0 && trace.latestSeekMarker()?.sequence == marker.sequence
                    && sample.engineIdentityMatches && sample.currentGeneration == marker.generation
                    && advancing && !matchedInputs.isEmpty && rewindObserved
                    && sample.isPlaying && sample.rawClockIsRunning
                    && (sample.rawClock ?? -1) > 0.8 && (sample.rawClock ?? 99) < 9.95
                    && sample.displayed > displayed && sample.displayed - displayed > 5
                    && sample.played > played && sample.played - played > 5
                    && sample.ended == 0 && sample.validatorCalls == 0
                    && !sample.hasPlayerError && !sample.hasSourceFailure && sample.stoppingReason == nil
                let tick = began.duration(to: .now).components
                samples.append(.init(elapsedSeconds: Double(tick.seconds) + Double(tick.attoseconds) / 1e18,
                                     observation: sample))
                if ready || .now >= deadline { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            struct ControlProof: Encodable {
                let actualSMBSHA256: String
                let previousClock: Double
                let previousInput: Double?
                let displayedBeforeSeek: UInt64
                let playedBeforeSeek: UInt64
                let actualSeekMarker: TailPhaseTrace.Record
                let matchedRunning: TailPhaseTrace.Record?
                let matchedInputs: [TailPhaseTrace.Record]
                let rewindObserved: Bool
                let ready: Bool
                let samples: [TailPhaseSample]
            }
            let proof = ControlProof(actualSMBSHA256: sha(actualSMBData), previousClock: previousClock,
                previousInput: previousInput, displayedBeforeSeek: displayed, playedBeforeSeek: played,
                actualSeekMarker: marker, matchedRunning: matchedRunning, matchedInputs: matchedInputs,
                rewindObserved: rewindObserved, ready: ready, samples: samples)
            let attachment = XCTAttachment(data: try JSONEncoder().encode(proof), uniformTypeIdentifier: "public.json")
            attachment.name = "Generated complete SMB active seek-zero control proof"
            attachment.lifetime = .keepAlways
            add(attachment)
            await attachSMBFailureDiagnostics(stream)
            snapshot("complete SMB active seek-zero control " + (ready ? "ready" : "rejected"))
            XCTAssertTrue(ready, "Complete real SMB input must demonstrate actual active seek-zero rewind and new output within the same six seconds.")
            if !ready { throw EOFPlaybackError.timeout }
        } catch {
            await attachSMBFailureDiagnostics(stream)
            player.stop()
            await stream.stop()
            await provider.close()
            throw error
        }
        player.stop()
        await stream.stop()
        await provider.close()
    }

    func testTailPhaseRejectsActualPausedNearEndSeek() async throws {
        try await withTailFixture { session in
            var validatorCalls = 0
            self.player.completionValidator = { validatorCalls += 1; return await session.stream.readFailure() == nil }
            self.player.load(url: session.url)
            try await self.outputReady("negative paused-seek actual warm-up")
            self.player.pause()
            try await self.wait("negative actual paused", timeout: 6) { self.player.backendState == "paused" }
            let displayed = self.player.displayedVideoFrames
            let played = self.player.playedAudioBuffers
            let identity = ObjectIdentifier(try XCTUnwrap(self.player.backendEngineForTesting))
            // Generate a real optimistic late cached estimate through the
            // supported seek path; do not inject clocks or output counters.
            self.player.seek(11.9)
            XCTAssertNil(self.player.backendClockTime)
            XCTAssertFalse(self.player.backendClockIsRunning, "A cleared normal point cannot inherit the previous running date.")
            XCTAssertNil(self.player.backendInputTime)
            let oracle = try self.phaseOracle(displayed: displayed, played: played, markerTarget: 11.9)
            let phase = try await self.tailPhase(oracle: oracle, provider: session.provider,
                stream: session.stream, metadata: session.metadata, engineIdentity: identity,
                validatorCalls: { validatorCalls })
            XCTAssertFalse(phase.ready, "A real paused near-end estimate is not running output.")
            XCTAssertFalse(self.player.isPlaying)
            XCTAssertFalse(self.player.backendClockIsRunning)
            XCTAssertGreaterThan(self.player.backendTime ?? 0, 11.85)
            XCTAssertLessThan(self.player.backendTime ?? 99, 12.05)
            XCTAssertEqual(self.player.backendState, "paused")
            // Pausing may finish audio already queued before its acknowledgement.
            // Require a stable final second inside the same six-second phase,
            // rather than assuming the output queue vanishes immediately.
            let finalTick = try XCTUnwrap(phase.samples.last).elapsedSeconds
            let stableStart = try XCTUnwrap(phase.samples.last {
                $0.elapsedSeconds <= finalTick - 1
            }).elapsedSeconds
            let stable = phase.samples.filter { $0.elapsedSeconds >= stableStart }
            let first = try XCTUnwrap(stable.first)
            let last = try XCTUnwrap(stable.last)
            XCTAssertGreaterThanOrEqual(last.elapsedSeconds - first.elapsedSeconds, 1)
            XCTAssertTrue(stable.allSatisfy {
                !$0.observation.isPlaying && !$0.observation.rawClockIsRunning
                    && $0.observation.displayed == first.observation.displayed
                    && $0.observation.played == first.observation.played
                    && $0.observation.rawClock == first.observation.rawClock
            }, "Actual paused output and normal clock must remain stable in the final observation interval.")
            XCTAssertEqual(self.ended, 0)
            XCTAssertEqual(validatorCalls, 0)
            let saved = try await self.persistedProgress()
            XCTAssertFalse(try XCTUnwrap(saved).isWatched)
            XCTAssertLessThan(try XCTUnwrap(saved).position, self.player.duration)
        }
    }

    func testTailPhaseRejectsCancelledHistoricalHTTPRead() async throws {
        try await withTailFixture { session in
            // Independently verify the length-probe exception over actual HTTP
            // and the real SMB provider before testing a still-held full tail.
            let localURL = try XCTUnwrap(Bundle(for: Self.self).resourceURL?
                .appendingPathComponent("PlaybackFixtures/clip-short-gop.mp4"))
            let localFixture = try Data(contentsOf: localURL)
            guard Int64(localFixture.count) == session.metadata.fileBytes else { throw EOFPlaybackError.fixtureUnavailable }
            let offset = session.metadata.fileBytes - 1
            var probe = URLRequest(url: session.url, cachePolicy: .reloadIgnoringLocalCacheData)
            probe.timeoutInterval = 6
            probe.setValue("bytes=\(offset)-\(offset)", forHTTPHeaderField: "Range")
            let (probeData, probeResponse) = try await URLSession.shared.data(for: probe)
            let response = try XCTUnwrap(probeResponse as? HTTPURLResponse)
            XCTAssertEqual(response.statusCode, 206)
            XCTAssertEqual(response.value(forHTTPHeaderField: "Content-Range"),
                           "bytes \(offset)-\(offset)/\(session.metadata.fileBytes)")
            XCTAssertEqual(probeData.count, 1)
            let expectedProbe = Data(localFixture.suffix(1))
            XCTAssertEqual(probeData, expectedProbe, "The exception must return the real generated file's last byte.")
            func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
            let probeSHA = digest(probeData)
            XCTAssertEqual(probeSHA, digest(expectedProbe))
            let afterProbe = await session.provider.pendingSnapshot()
            XCTAssertEqual(afterProbe.reads.count, 0)
            XCTAssertEqual(afterProbe.historicalHeldReads, 0)
            XCTAssertEqual(afterProbe.finalByteProbes.count, 1)
            XCTAssertEqual(afterProbe.finalByteProbes.first?.offset, offset)
            XCTAssertEqual(afterProbe.finalByteProbes.first?.count, 1)
            let probeTraceData = await session.stream.debugTraceData()
            let probeTrace = try JSONDecoder().decode(TailHTTPTrace.self, from: XCTUnwrap(probeTraceData))
            let probeRead = try XCTUnwrap(probeTrace.events.last {
                $0.phase == "readerSubmit" && $0.offset == offset && $0.count == 1
            })
            XCTAssertTrue(probeTrace.events.contains {
                $0.requestID == probeRead.requestID && $0.phase == "readerComplete"
                    && $0.offset == offset && $0.count == 1
            })
            XCTAssertTrue(probeTrace.activeTailRequests(holdAt: session.metadata.tailHoldAt).isEmpty)
            let socket = try await TailTCPResetClient.sendRequest(to: session.url,
                range: "bytes=\(session.metadata.tailHoldAt)-\(session.metadata.fileBytes - 1)")
            var ownedSocket: Int32? = socket
            defer { if let ownedSocket { Darwin.close(ownedSocket) } }
            do {
                let enteredDeadline = ContinuousClock.now.advanced(by: .seconds(6))
                while await session.provider.pendingSnapshot().reads.isEmpty && .now < enteredDeadline {
                    try await Task.sleep(for: .milliseconds(100))
                }
                let entered = await session.provider.pendingSnapshot()
                XCTAssertEqual(entered.reads.count, 1, "The one owned HTTP consumer must enter the fixture wait.")
                let enteredRead = try XCTUnwrap(entered.reads.first)
                XCTAssertEqual(enteredRead.lowerBound, session.metadata.tailHoldAt)
                XCTAssertEqual(enteredRead.upperBound, session.metadata.fileBytes)
                let requestID = try XCTUnwrap(enteredRead.httpRequestID)
                XCTAssertNotEqual(requestID, probeRead.requestID)
                // Encoder versions produce different final packet lengths.
                // The bounds above prove the entire metadata-defined tail;
                // it must remain distinct from the one-byte length probe.
                XCTAssertGreaterThan(enteredRead.upperBound - enteredRead.lowerBound, 1)
                // A FIN permits valid HTTP half-close. Use an actual TCP reset
                // of this owned socket to exercise the server's cancel contract.
                ownedSocket = nil
                try await TailTCPResetClient.closeWithReset(socket)
                let cancelledDeadline = ContinuousClock.now.advanced(by: .seconds(6))
                while .now < cancelledDeadline {
                    let pending = await session.provider.pendingSnapshot()
                    let traceData = await session.stream.debugTraceData()
                    let trace = try JSONDecoder().decode(TailHTTPTrace.self,
                        from: XCTUnwrap(traceData))
                    if pending.reads.isEmpty && trace.events.contains(where: {
                        $0.requestID == requestID && $0.phase == "readerCancelled"
                    }) { break }
                    try await Task.sleep(for: .milliseconds(100))
                }
                let cancelled = await session.provider.pendingSnapshot()
                XCTAssertTrue(cancelled.unresolved)
                XCTAssertEqual(cancelled.reads.count, 0)
                XCTAssertGreaterThan(cancelled.historicalHeldReads, 0)
                let traceData = await session.stream.debugTraceData()
                let trace = try JSONDecoder().decode(TailHTTPTrace.self, from: XCTUnwrap(traceData))
                XCTAssertTrue(trace.activeTailRequests(holdAt: session.metadata.tailHoldAt).isEmpty)
                XCTAssertTrue(trace.events.contains { $0.requestID == requestID && $0.phase == "readerCancelled" })
                let failure = await session.stream.readFailure()
                XCTAssertNil(failure, "Deliberate consumer cancellation is not a NAS source error.")
                do {
                    try await session.provider.resolveIfActive(fails: false, matchingHTTPRequests: [])
                    XCTFail("A historical cancelled hold must not be accepted as an active release phase.")
                } catch TailFixtureError.noActiveMatchingRead { }
                XCTAssertEqual(self.ended, 0)
                struct CancellationProof: Encodable {
                    let entered: TailHeldSMBProvider.PendingRead
                    let currentPendingReads: Int
                    let historicalHeldReads: Int
                    let activeHTTPRequests: [UInt64]
                    let probeRequestID: UInt64
                    let probeOffset: Int64
                    let probeCount: Int
                    let probeHTTPStatus: Int
                    let probeSHA256: String
                    let expectedProbeSHA256: String
                    let pendingAfterProbe: Int
                    let heldCountAfterProbe: Int
                    let deliberateOwnedTCPReset = true
                }
                let proof = CancellationProof(entered: enteredRead, currentPendingReads: cancelled.reads.count,
                    historicalHeldReads: cancelled.historicalHeldReads,
                    activeHTTPRequests: trace.activeTailRequests(holdAt: session.metadata.tailHoldAt).sorted(),
                    probeRequestID: probeRead.requestID, probeOffset: offset, probeCount: probeData.count,
                    probeHTTPStatus: response.statusCode, probeSHA256: probeSHA,
                    expectedProbeSHA256: digest(expectedProbe), pendingAfterProbe: afterProbe.reads.count,
                    heldCountAfterProbe: afterProbe.historicalHeldReads)
                let attachment = XCTAttachment(data: try JSONEncoder().encode(proof), uniformTypeIdentifier: "public.json")
                attachment.name = "Generated SMB owned TCP reset and cancelled tail UUID proof"
                attachment.lifetime = .keepAlways
                self.add(attachment)
                await self.attachSMBFailureDiagnostics(session.stream)
            } catch {
                throw error
            }
        }
    }

    private func phaseOracle(displayed: UInt64, played: UInt64, markerTarget: Double = 10) throws -> TailPhaseOracle {
        let data = try XCTUnwrap(player.debugLifecycleTraceData())
        let trace = try JSONDecoder().decode(TailPhaseTrace.self, from: data)
        let marker = try XCTUnwrap(trace.latestSeekMarker())
        XCTAssertEqual(marker.targetSeconds, markerTarget)
        let prior = trace.records.filter { $0.eventCode == 30 && $0.generation == marker.generation && $0.sequence < marker.sequence }
        let largestPrior = prior.compactMap(\.timeMicroseconds).max().map { Double($0) / 1_000_000 }
        XCTAssertLessThan(try XCTUnwrap(largestPrior), 9.95, "This fixture must establish a seek from an actually early normal clock.")
        return TailPhaseOracle(context: .init(markerSequence: marker.sequence, generation: marker.generation,
            target: 10, duration: player.duration, displayedBeforeSeek: displayed, playedBeforeSeek: played))
    }

    private struct TailPhaseResult {
        let ready: Bool
        let activeHTTPRequests: Set<UInt64>
        let elapsedSeconds: Double
        let samples: [TailPhaseSample]
    }

    private struct TailPhaseSample: Encodable {
        let elapsedSeconds: Double
        let observation: TailPhaseObservation
    }

    private struct TailPhaseProof: Encodable {
        let context: TailPhaseOracle.Context
        let boundary: TailPhaseTrace.Record?
        let runningPoint: TailPhaseTrace.Record?
        let finalObservation: TailPhaseObservation
        let ready: Bool
        let elapsedSeconds: Double
        let activeHTTPRequests: [UInt64]
        let historicalHeldReads: Int
        let currentPendingReads: Int
        let currentPendingReadDetails: [TailHeldSMBProvider.PendingRead]
        let finalByteProbes: [TailHeldSMBProvider.FinalByteProbe]
        let samples: [TailPhaseSample]
        let sourceWasResolved: Bool
        let cacheIsOnlyLatePositionEstimate = true
        let exactLastFramePTSPresentedIsNotProven = true
    }

    private func tailPhase(oracle initial: TailPhaseOracle, provider: TailHeldSMBProvider,
                           stream: SMBStreamingServer, metadata: EOFTailMetadata,
                           engineIdentity: ObjectIdentifier,
                           validatorCalls: @MainActor () -> Int) async throws -> TailPhaseResult {
        var oracle = initial
        let began = ContinuousClock.now
        let deadline = began.advanced(by: .seconds(6))
        var ready = false
        var matchingRequests: Set<UInt64> = []
        var finalPending = await provider.pendingSnapshot()
        var finalSample: TailPhaseObservation!
        var samples: [TailPhaseSample] = []
        snapshot("SMB compound seek/output/held-tail phase begin")
        while true {
            let pending = await provider.pendingSnapshot()
            let httpData = await stream.debugTraceData()
            let http = try JSONDecoder().decode(TailHTTPTrace.self, from: XCTUnwrap(httpData))
            let sourceFailed = await stream.readFailure() != nil
            let trace = try JSONDecoder().decode(TailPhaseTrace.self,
                from: XCTUnwrap(player.debugLifecycleTraceData()))
            let activeHTTP = http.activeTailRequests(holdAt: metadata.tailHoldAt)
            matchingRequests = Set(pending.reads.compactMap { read in
                guard pending.unresolved, read.lowerBound >= metadata.tailHoldAt,
                      read.upperBound <= metadata.fileBytes, read.upperBound > read.lowerBound,
                      let id = read.httpRequestID, activeHTTP.contains(id) else { return nil }
                return id
            })
            let sample = TailPhaseObservation(
                engineIdentityMatches: player.backendEngineForTesting.map(ObjectIdentifier.init) == engineIdentity,
                currentGeneration: trace.records.map(\.generation).max() ?? -1,
                rawClock: player.backendClockTime, rawClockIsRunning: player.backendClockIsRunning,
                displayed: player.displayedVideoFrames, played: player.playedAudioBuffers,
                cache: player.backendTime, isPlaying: player.isPlaying,
                activeTailPending: pending.unresolved && !matchingRequests.isEmpty,
                ended: ended, validatorCalls: validatorCalls(), hasPlayerError: player.errorMessage != nil,
                hasSourceFailure: sourceFailed, stoppingReason: player.backendStoppingReason)
            ready = oracle.observe(trace, sample)
            let tick = began.duration(to: .now).components
            samples.append(.init(elapsedSeconds: Double(tick.seconds) + Double(tick.attoseconds) / 1e18,
                                 observation: sample))
            finalPending = pending
            finalSample = sample
            if ready || .now >= deadline { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let elapsed = began.duration(to: .now).components
        let proof = TailPhaseProof(context: oracle.context, boundary: oracle.boundary, runningPoint: oracle.runningPoint,
            finalObservation: finalSample, ready: ready,
            elapsedSeconds: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18,
            activeHTTPRequests: matchingRequests.sorted(), historicalHeldReads: finalPending.historicalHeldReads,
            currentPendingReads: finalPending.reads.count, currentPendingReadDetails: finalPending.reads,
            finalByteProbes: finalPending.finalByteProbes, samples: samples,
            sourceWasResolved: !finalPending.unresolved)
        let attachment = XCTAttachment(data: try JSONEncoder().encode(proof), uniformTypeIdentifier: "public.json")
        attachment.name = "Generated SMB compound held-tail phase proof"
        attachment.lifetime = .keepAlways
        add(attachment)
        await attachSMBFailureDiagnostics(stream)
        snapshot("SMB compound seek/output/held-tail phase " + (ready ? "ready" : "rejected"))
        return TailPhaseResult(ready: ready, activeHTTPRequests: matchingRequests,
                               elapsedSeconds: proof.elapsedSeconds, samples: samples)
    }

    private struct TailFixtureSession {
        let provider: TailHeldSMBProvider
        let stream: SMBStreamingServer
        let metadata: EOFTailMetadata
        let url: URL
    }

    private func withTailFixture(holdAtOverride: Int64? = nil,
                                 _ operation: @MainActor (TailFixtureSession) async throws -> Void) async throws {
        player.debugEnableLifecycleTrace(origin: origin)
        let fixture = try await EOFSMBFixture.configuration()
        let credentials = SMBCredentials(username: fixture.username, password: fixture.password)
        let connection = SMBConnection(name: "fixture", host: fixture.host ?? "127.0.0.1", port: fixture.port,
                                       share: fixture.share, rootPath: fixture.mediaPath)
        let path = fixture.mediaPath + "/clip-short-gop.mp4"
        let metadataURL = try XCTUnwrap(Bundle(for: Self.self).resourceURL?
            .appendingPathComponent("PlaybackFixtures/clip-short-gop-tail.json"))
        let metadata = try JSONDecoder().decode(EOFTailMetadata.self, from: Data(contentsOf: metadataURL))
        XCTAssertGreaterThan(metadata.lastVideoPTSBeforeTail, 11.9)
        XCTAssertGreaterThanOrEqual(metadata.firstHeldPTS, 11.966)
        XCTAssertGreaterThan(metadata.fileBytes, metadata.tailHoldAt)
        let provider = TailHeldSMBProvider(holdAt: holdAtOverride ?? metadata.tailHoldAt, fileBytes: metadata.fileBytes)
        let size = try await provider.fileSize(connection, credentials: credentials, path: path)
        XCTAssertEqual(size, metadata.fileBytes)
        guard size == metadata.fileBytes else { throw EOFPlaybackError.fixtureUnavailable }
        let stream = SMBStreamingServer(provider: provider, connection: connection, credentials: credentials, path: path, size: size)
        await stream.debugEnableTrace(origin: origin)
        let url = try await stream.start()
        do {
            try await operation(.init(provider: provider, stream: stream, metadata: metadata, url: url))
        } catch {
            await attachSMBFailureDiagnostics(stream)
            player.stop()
            await provider.resolveForCleanup(fails: true)
            await stream.stop()
            await provider.close()
            throw error
        }
        player.stop()
        await provider.resolveForCleanup(fails: true)
        await stream.stop()
        await provider.close()
    }

    #if DEBUG
    private func attachSMBFailureDiagnostics(_ stream: SMBStreamingServer) async {
        var snapshot: [String: Any] = ["schemaVersion": 1]
        let traces = ["playerLifecycle": player.debugLifecycleTraceData(), "streamingHTTP": await stream.debugTraceData()]
        for (key, data) in traces {
            if let data, let object = try? JSONSerialization.jsonObject(with: data) { snapshot[key] = object }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: snapshot, options: [.sortedKeys]) else { return }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "Generated SMB fixture EOF failure timeline"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    #endif

    func testUICompleteSMBSourceMatchedStart2SeekZeroContinues() async throws {
        // Diagnostic matched to the held-source start2 failure: same generated
        // fixture, initial resume at two, then an actual public seek to zero.
        // Complete SMB availability is the only source-mode difference.
        let startAt = 2.0
        player.debugEnableLifecycleTrace(origin: origin)
        let fixture = try await EOFSMBFixture.configuration()
        let credentials = SMBCredentials(username: fixture.username, password: fixture.password)
        let connection = SMBConnection(name: "fixture", host: fixture.host ?? "127.0.0.1", port: fixture.port,
                                       share: fixture.share, rootPath: fixture.mediaPath)
        let path = fixture.mediaPath + "/clip-short-gop.mp4"
        let resource = try XCTUnwrap(Bundle(for: Self.self).resourceURL?.appendingPathComponent("PlaybackFixtures"))
        let metadataData = try Data(contentsOf: resource.appendingPathComponent("clip-short-gop-tail.json"))
        let metadata = try JSONDecoder().decode(EOFTailMetadata.self, from: metadataData)
        let metadataJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: metadataData) as? [String: Any])
        let expectedSHA = try XCTUnwrap(metadataJSON["sha256"] as? String)
        let bundleData = try Data(contentsOf: resource.appendingPathComponent("clip-short-gop.mp4"))
        func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        XCTAssertEqual(sha(bundleData), expectedSHA)
        XCTAssertEqual(Int64(bundleData.count), metadata.fileBytes)
        let provider = SMBProvider()
        let size = try await provider.fileSize(connection, credentials: credentials, path: path)
        XCTAssertEqual(size, metadata.fileBytes)
        guard size == metadata.fileBytes else { throw EOFPlaybackError.fixtureUnavailable }
        let actualSMBData = try await provider.readFile(connection, credentials: credentials, path: path, range: 0..<size)
        XCTAssertEqual(Int64(actualSMBData.count), size)
        XCTAssertEqual(sha(actualSMBData), expectedSHA, "The complete-source control must read the same real SMB fixture.")
        let stream = SMBStreamingServer(provider: provider, connection: connection, credentials: credentials, path: path, size: size)
        await stream.debugEnableTrace(origin: origin)
        var validatorCalls = 0
        player.completionValidator = { validatorCalls += 1; return await stream.readFailure() == nil }
        do {
            let url = try await stream.start()
            player.load(url: url, startAt: startAt)
            let identity = ObjectIdentifier(try XCTUnwrap(player.backendEngineForTesting))
            try await wait("complete SMB matched start2 actual warm-up") {
                self.player.duration > 11 && (self.player.backendClockTime ?? 0) > startAt + 0.8
                    && (self.player.backendClockTime ?? 0) < self.player.duration
                    && self.player.displayedVideoFrames > 0 && self.player.playedAudioBuffers > 0
            }
            XCTAssertEqual(player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
            let previousClock = try XCTUnwrap(player.backendClockTime)
            let previousInput = try XCTUnwrap(player.backendInputTime)
            let warmupTrace = try JSONDecoder().decode(TailPhaseTrace.self,
                from: XCTUnwrap(player.debugLifecycleTraceData()))
            let initialMarker = try XCTUnwrap(warmupTrace.latestSeekMarker())
            XCTAssertEqual(initialMarker.targetSeconds, startAt)
            XCTAssertEqual(warmupTrace.evictedEvents, 0)
            let warmupPoint = try XCTUnwrap(warmupTrace.records.last { record in
                guard record.eventCode == 31, record.generation == initialMarker.generation,
                      let callback = warmupTrace.pairedCallback(for: record, callbackCode: 30),
                      callback.sequence > initialMarker.sequence, let time = record.timeMicroseconds else { return false }
                return abs(previousClock - Double(time) / 1_000_000) < 0.000002
            })
            XCTAssertGreaterThan(previousClock, startAt + 0.8)
            XCTAssertLessThan(previousClock, player.duration)
            XCTAssertTrue(player.isPlaying)
            XCTAssertTrue(player.backendClockIsRunning)
            XCTAssertGreaterThan(warmupPoint.displayedVideoFrames ?? 0, 0)
            XCTAssertGreaterThan(warmupPoint.playedAudioBuffers ?? 0, 0)
            let beforeHTTPData = await stream.debugTraceData()
            let beforeHTTP = try JSONDecoder().decode(TailHTTPTrace.self, from: XCTUnwrap(beforeHTTPData))
            XCTAssertEqual(beforeHTTP.omittedEvents, 0)
            func byteCoverage(_ phase: String) -> Int64 {
                let chunks = beforeHTTP.events.filter {
                    $0.phase == phase && $0.offset >= 0 && $0.offset < size
                        && $0.count > 0 && $0.count <= size - $0.offset
                }.sorted { $0.offset < $1.offset }
                var covered: Int64 = 0
                var lower: Int64 = 0
                var upper: Int64 = 0
                for chunk in chunks {
                    if chunk.offset > upper {
                        covered += upper - lower
                        lower = chunk.offset
                        upper = chunk.offset + chunk.count
                    } else {
                        upper = max(upper, chunk.offset + chunk.count)
                    }
                }
                return covered + upper - lower
            }
            let readCoverageBeforeZero = byteCoverage("readerComplete")
            let sentCoverageBeforeZero = byteCoverage("chunkSendComplete")
            let displayed = player.displayedVideoFrames
            let played = player.playedAudioBuffers
            let uiCallbackBaseline = try XCTUnwrap(player.backendEngineForTesting).seekCallbackSequence
            player.seek(0)
            XCTAssertEqual(player.seekStatus, .seeking)
            var uiObservations = [SeekUIRuntimeObservation.capture(player: player, origin: origin, phase: "matched-start2-zero-submitted")]
            XCTAssertNil(player.backendClockTime)
            XCTAssertFalse(player.backendClockIsRunning)
            XCTAssertNil(player.backendInputTime)
            let initialTrace = try JSONDecoder().decode(TailPhaseTrace.self, from: XCTUnwrap(player.debugLifecycleTraceData()))
            let marker = try XCTUnwrap(initialTrace.latestSeekMarker())
            XCTAssertEqual(marker.targetSeconds, 0)
            XCTAssertGreaterThan(marker.sequence, initialMarker.sequence)
            XCTAssertEqual(marker.generation, initialMarker.generation)
            let began = ContinuousClock.now
            let deadline = began.advanced(by: .seconds(6))
            var samples: [TailPhaseSample] = []
            var matchedRunning: TailPhaseTrace.Record?
            var matchedInputs: [TailPhaseTrace.Record] = []
            var rewoundNormals: [TailPhaseTrace.Record] = []
            var rewoundInputs: [TailPhaseTrace.Record] = []
            var rewindObserved = false
            var ready = false
            while true {
                let sourceFailed = await stream.readFailure() != nil
                let trace = try JSONDecoder().decode(TailPhaseTrace.self, from: XCTUnwrap(player.debugLifecycleTraceData()))
                let normals = trace.records.filter { record in
                    guard record.eventCode == 31, record.generation == marker.generation,
                          let callback = trace.pairedCallback(for: record, callbackCode: 30),
                          callback.sequence > marker.sequence, let time = record.timeMicroseconds else { return false }
                    return time >= 0 && Double(time) / 1_000_000 < 9.95
                }
                matchedRunning = normals.last { record in
                    guard let time = record.timeMicroseconds, let date = record.systemDateMicroseconds,
                          date > 0, date != Int64.max, let raw = player.backendClockTime else { return false }
                    return abs(raw - Double(time) / 1_000_000) < 0.000002
                }
                let runningSource = matchedRunning?.sourceSequence ?? -1
                let runningTime = matchedRunning?.timeMicroseconds ?? -1
                let advancing = normals.contains {
                    ($0.sourceSequence ?? Int.max) < runningSource && ($0.timeMicroseconds ?? Int64.max) < runningTime
                }
                matchedInputs = trace.records.filter { record in
                    guard record.eventCode == 41, record.generation == marker.generation,
                          let callback = trace.pairedCallback(for: record, callbackCode: 40),
                          callback.sequence > marker.sequence, callback.sequence <= runningSource,
                          let time = record.timeMicroseconds else { return false }
                    return time >= 0 && Double(time) / 1_000_000 < 9.95
                }
                rewoundNormals = normals.filter {
                    ($0.sourceSequence ?? Int.max) <= runningSource
                        && Double($0.timeMicroseconds ?? Int64.max) / 1_000_000 < previousClock
                }
                rewoundInputs = matchedInputs.filter {
                    Double($0.timeMicroseconds ?? Int64.max) / 1_000_000 < previousInput
                }
                // Both actual clocks must rewind below their own actual pre-seek
                // values; continuing the old start2 segment cannot pass.
                rewindObserved = !rewoundNormals.isEmpty && !rewoundInputs.isEmpty
                let sample = TailPhaseObservation(
                    engineIdentityMatches: player.backendEngineForTesting.map(ObjectIdentifier.init) == identity,
                    currentGeneration: trace.records.map(\.generation).max() ?? -1,
                    rawClock: player.backendClockTime, rawClockIsRunning: player.backendClockIsRunning,
                    displayed: player.displayedVideoFrames, played: player.playedAudioBuffers,
                    cache: player.backendTime, isPlaying: player.isPlaying, activeTailPending: false,
                    ended: ended, validatorCalls: validatorCalls, hasPlayerError: player.errorMessage != nil,
                    hasSourceFailure: sourceFailed, stoppingReason: player.backendStoppingReason)
                ready = trace.evictedEvents == 0 && trace.latestSeekMarker()?.sequence == marker.sequence
                    && sample.engineIdentityMatches && sample.currentGeneration == marker.generation
                    && advancing && !matchedInputs.isEmpty && rewindObserved
                    && sample.isPlaying && sample.rawClockIsRunning
                    && (sample.rawClock ?? -1) > 0.8 && (sample.rawClock ?? 99) < 9.95
                    && sample.displayed > displayed && sample.displayed - displayed > 5
                    && sample.played > played && sample.played - played > 5
                    && sample.ended == 0 && sample.validatorCalls == 0
                    && !sample.hasPlayerError && !sample.hasSourceFailure && sample.stoppingReason == nil
                uiObservations.append(.capture(player: player, origin: origin, phase: "matched-start2-real-output-loop"))
                if player.seekStatus == nil {
                    let actualEngine = try XCTUnwrap(player.backendEngineForTesting)
                    XCTAssertGreaterThan(actualEngine.seekCallbackSequence, uiCallbackBaseline)
                    XCTAssertFalse(actualEngine.isSeeking)
                    XCTAssertNotNil(matchedRunning)
                    XCTAssertFalse(matchedInputs.isEmpty)
                    XCTAssertTrue(player.displayedVideoFrames > displayed || player.playedAudioBuffers > played)
                }
                let tick = began.duration(to: .now).components
                samples.append(.init(elapsedSeconds: Double(tick.seconds) + Double(tick.attoseconds) / 1e18,
                                     observation: sample))
                if ready || .now >= deadline { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            struct ControlProof: Encodable {
                let actualSMBSHA256: String
                let previousClock: Double
                let previousInput: Double
                let diagnosticStartAt: Double
                let initialMarker: TailPhaseTrace.Record
                let warmupNormalPoint: TailPhaseTrace.Record
                let fileBytes: Int64
                let HTTPReadCoverageBeforeZeroSeek: Int64
                let HTTPSentCoverageBeforeZeroSeek: Int64
                let HTTPAllFileBytesReadBeforeZeroSeek: Bool
                let HTTPAllFileBytesSentBeforeZeroSeek: Bool
                let allHTTPBytesSentDoesNotProveEngineConsumedThem: Bool
                let HTTPSequenceBeforeZeroSeek: UInt64
                let actualHTTPEventsBeforeZeroSeek: [TailHTTPTrace.Event]
                let actualHTTPEventsAfterZeroSeek: [TailHTTPTrace.Event]
                let completeProviderHasNoHeldTail: Bool
                let rewoundNormals: [TailPhaseTrace.Record]
                let rewoundInputs: [TailPhaseTrace.Record]
                let displayedBeforeSeek: UInt64
                let playedBeforeSeek: UInt64
                let actualSeekMarker: TailPhaseTrace.Record
                let matchedRunning: TailPhaseTrace.Record?
                let matchedInputs: [TailPhaseTrace.Record]
                let rewindObserved: Bool
                let ready: Bool
                let samples: [TailPhaseSample]
            }
            let afterHTTPData = await stream.debugTraceData()
            let afterHTTP = try JSONDecoder().decode(TailHTTPTrace.self, from: XCTUnwrap(afterHTTPData))
            XCTAssertEqual(afterHTTP.omittedEvents, 0)
            let HTTPSequenceBeforeZero = beforeHTTP.events.last?.sequence ?? 0
            let proof = ControlProof(actualSMBSHA256: sha(actualSMBData), previousClock: previousClock,
                previousInput: previousInput, diagnosticStartAt: startAt, initialMarker: initialMarker,
                warmupNormalPoint: warmupPoint, fileBytes: size,
                HTTPReadCoverageBeforeZeroSeek: readCoverageBeforeZero,
                HTTPSentCoverageBeforeZeroSeek: sentCoverageBeforeZero,
                HTTPAllFileBytesReadBeforeZeroSeek: readCoverageBeforeZero == size,
                HTTPAllFileBytesSentBeforeZeroSeek: sentCoverageBeforeZero == size,
                allHTTPBytesSentDoesNotProveEngineConsumedThem: true,
                HTTPSequenceBeforeZeroSeek: HTTPSequenceBeforeZero,
                actualHTTPEventsBeforeZeroSeek: beforeHTTP.events,
                actualHTTPEventsAfterZeroSeek: afterHTTP.events.filter { $0.sequence > HTTPSequenceBeforeZero },
                completeProviderHasNoHeldTail: true, rewoundNormals: rewoundNormals, rewoundInputs: rewoundInputs,
                displayedBeforeSeek: displayed, playedBeforeSeek: played,
                actualSeekMarker: marker, matchedRunning: matchedRunning, matchedInputs: matchedInputs,
                rewindObserved: rewindObserved, ready: ready, samples: samples)
            let attachment = XCTAttachment(data: try JSONEncoder().encode(proof), uniformTypeIdentifier: "public.json")
            attachment.name = "Generated complete SMB matched start2 active seek-zero control proof"
            attachment.lifetime = .keepAlways
            add(attachment)
            await attachSMBFailureDiagnostics(stream)
            snapshot("complete SMB active seek-zero control " + (ready ? "ready" : "rejected"))
            XCTAssertTrue(ready, "Complete real SMB input must demonstrate actual active seek-zero rewind and new output within the same six seconds.")
            if !ready { throw EOFPlaybackError.timeout }
            XCTAssertNil(player.seekStatus, "The unchanged real six-second playback criterion must also settle the UI.")
            let uiEngine = try XCTUnwrap(player.backendEngineForTesting)
            XCTAssertGreaterThan(uiEngine.seekCallbackSequence, uiCallbackBaseline)
            XCTAssertFalse(uiEngine.isSeeking)
            let uiAttachment = XCTAttachment(data: try JSONEncoder().encode(uiObservations), uniformTypeIdentifier: "public.json")
            uiAttachment.name = "Actual complete SMB matched start2 seek UI observations"
            uiAttachment.lifetime = .keepAlways
            add(uiAttachment)
            XCTAssertEqual(player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
            XCTAssertGreaterThan(player.displayedVideoFrames, displayed + 5)
            XCTAssertGreaterThan(player.playedAudioBuffers, played + 5)
            XCTAssertGreaterThan(try XCTUnwrap(player.backendClockTime), 0.8)
            XCTAssertLessThan(try XCTUnwrap(player.backendClockTime), 9.95)
            XCTAssertTrue(player.isPlaying)
            XCTAssertTrue(player.backendClockIsRunning)
            XCTAssertFalse(rewoundNormals.isEmpty)
            XCTAssertFalse(rewoundInputs.isEmpty)
            XCTAssertEqual(ended, 0)
            XCTAssertEqual(validatorCalls, 0)
            XCTAssertNil(player.errorMessage)
            XCTAssertNil(player.backendStoppingReason)
            let sourceFailure = await stream.readFailure()
            XCTAssertNil(sourceFailure)
        } catch {
            await attachSMBFailureDiagnostics(stream)
            player.stop()
            await stream.stop()
            await provider.close()
            throw error
        }
        player.stop()
        await stream.stop()
        await provider.close()
    }

    func testUIInfiniteHeldSourceWaitsWithoutEOSAndCloseClearsStatus() async throws {
        let held = UIHeldRangePlan()
        let sampleURL = try XCTUnwrap(Bundle(for: Self.self).resourceURL?
            .appendingPathComponent("PlaybackFixtures/clip-short-gop.mp4"))
        let sampleSHA = SHA256.hash(data: try Data(contentsOf: sampleURL)).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(sampleSHA, held.sampleSHA256, "The packet offsets must belong to the unchanged real MP4 fixture.")
        guard sampleSHA == held.sampleSHA256 else { throw EOFPlaybackError.fixtureUnavailable }
        try await withTailFixture(holdAtOverride: held.holdAt) { session in
            var validatorCalls = 0
            self.player.completionValidator = { validatorCalls += 1; return await session.stream.readFailure() == nil }
            self.player.load(url: session.url, startAt: 2)
            let identity = ObjectIdentifier(try XCTUnwrap(self.player.backendEngineForTesting))
            try await self.wait("UI held prefix start2 actual warm-up") {
                self.player.duration > 11 && (self.player.backendClockTime ?? 0) > 2.8
                    && self.player.backendClockIsRunning && self.player.displayedVideoFrames > 0
                    && self.player.playedAudioBuffers > 0
            }
            let pendingDeadline = ContinuousClock.now.advanced(by: .seconds(6))
            while await session.provider.pendingSnapshot().reads.isEmpty && .now < pendingDeadline {
                try await Task.sleep(for: .milliseconds(100))
            }
            let beforePending = await session.provider.pendingSnapshot()
            XCTAssertTrue(beforePending.unresolved)
            XCTAssertGreaterThan(beforePending.reads.count, 0)
            let beforeHTTPData = await session.stream.debugTraceData()
            let beforeHTTP = try JSONDecoder().decode(TailHTTPTrace.self,
                from: XCTUnwrap(beforeHTTPData))
            XCTAssertEqual(beforeHTTP.omittedEvents, 0)
            XCTAssertFalse(beforeHTTP.activeTailRequests(holdAt: held.holdAt).isEmpty)
            let beforeSequence = beforeHTTP.events.last?.sequence ?? 0
            let beforeTrace = try JSONDecoder().decode(TailPhaseTrace.self,
                from: XCTUnwrap(self.player.debugLifecycleTraceData()))
            let initialMarker = try XCTUnwrap(beforeTrace.latestSeekMarker())
            XCTAssertEqual(initialMarker.targetSeconds, 2)
            XCTAssertFalse(beforeHTTP.events.contains { event in
                ["readerComplete", "chunkSendComplete"].contains(event.phase)
                    && held.overlapsTarget(offset: event.offset, count: event.count)
            }, "The requested random-access picture must never have been read or sent during warm-up.")
            let callbackBaseline = try XCTUnwrap(self.player.backendEngineForTesting).seekCallbackSequence
            let uiBegan = ContinuousClock.now
            let displayed = self.player.displayedVideoFrames
            let played = self.player.playedAudioBuffers
            self.player.seek(held.target)
            XCTAssertEqual(self.player.seekStatus, .seeking)
            XCTAssertNil(self.player.backendClockTime)
            XCTAssertNil(self.player.backendInputTime)
            XCTAssertFalse(self.player.backendClockIsRunning)
            var observations = [SeekUIRuntimeObservation.capture(player: self.player, origin: uiBegan,
                                                                 phase: "held-seek-submitted")]
            let waitingDeadline = uiBegan.advanced(by: .milliseconds(3500))
            while .now < waitingDeadline {
                observations.append(.capture(player: self.player, origin: uiBegan, phase: "held-still-pending"))
                XCTAssertNotNil(self.player.seekStatus, "The original held input has not produced a completed real seek.")
                if .now < uiBegan.advanced(by: .milliseconds(2800)) {
                    XCTAssertEqual(self.player.seekStatus, .seeking)
                }
                XCTAssertEqual(self.ended, 0)
                XCTAssertEqual(validatorCalls, 0)
                XCTAssertNil(self.player.errorMessage)
                XCTAssertNil(self.player.backendStoppingReason)
                try await Task.sleep(for: .milliseconds(100))
            }
            XCTAssertEqual(self.player.seekStatus, .waitingForSource,
                           "After the real three-second UI delay, the still-held source must remain visibly pending.")
            XCTAssertEqual(self.player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
            let pending = await session.provider.pendingSnapshot()
            XCTAssertTrue(pending.unresolved)
            XCTAssertGreaterThan(pending.reads.count, 0)
            let currentHTTPData = await session.stream.debugTraceData()
            let currentHTTP = try JSONDecoder().decode(TailHTTPTrace.self,
                from: XCTUnwrap(currentHTTPData))
            XCTAssertEqual(currentHTTP.omittedEvents, 0)
            let active = currentHTTP.activeTailRequests(holdAt: held.holdAt)
            XCTAssertFalse(active.isEmpty)
            XCTAssertTrue(pending.reads.contains { $0.httpRequestID.map(active.contains) == true })
            let actualTrace = try JSONDecoder().decode(TailPhaseTrace.self,
                from: XCTUnwrap(self.player.debugLifecycleTraceData()))
            let marker = try XCTUnwrap(actualTrace.latestSeekMarker())
            XCTAssertEqual(marker.targetSeconds, held.target)
            XCTAssertEqual(marker.generation, initialMarker.generation)
            XCTAssertGreaterThan(marker.sequence, initialMarker.sequence)
            XCTAssertEqual(actualTrace.evictedEvents, 0)
            let applied = actualTrace.records.contains {
                $0.eventCode == 5 && $0.sequence > marker.sequence
                    && $0.generation == marker.generation && $0.targetSeconds == held.target
            }
            XCTAssertTrue(applied, "The public seek must really be submitted to this same engine.")
            let actualCallbackSequence = try XCTUnwrap(self.player.backendEngineForTesting).seekCallbackSequence
            XCTAssertGreaterThan(actualCallbackSequence, callbackBaseline, "The sole real seek watcher must observe the new request.")
            // A seek may reuse a still-active Range covering the unread target.
            // Its provider read must remain unresolved and contain every target byte.
            let coveringRanges = currentHTTP.events.filter { event in
                event.phase == "rangeReceived" && active.contains(event.requestID)
                    && held.coversTarget(offset: event.offset, count: event.count)
            }
            let existingCoveringRanges = coveringRanges.filter { $0.sequence <= beforeSequence }
            let freshCoveringRanges = coveringRanges.filter { $0.sequence > beforeSequence }
            let matchingReads = pending.reads.filter { read in
                read.httpRequestID.map(active.contains) == true && read.lowerBound >= held.holdAt
                    && held.coversTarget(offset: read.lowerBound, count: read.upperBound - read.lowerBound)
                    && coveringRanges.contains {
                        $0.requestID == read.httpRequestID && $0.offset <= read.lowerBound
                            && $0.count >= read.upperBound - $0.offset
                    }
            }
            let targetBytesNeverReadOrSent = !currentHTTP.events.contains { event in
                ["readerComplete", "chunkSendComplete"].contains(event.phase)
                    && held.overlapsTarget(offset: event.offset, count: event.count)
            }
            let targetPoints = actualTrace.records.filter { record in
                [30, 31, 40, 41].contains(record.eventCode) && record.sequence > marker.sequence
                    && record.generation == marker.generation
                    && record.timeMicroseconds.map { Double($0) / 1_000_000 >= held.target - 1 } == true
            }
            XCTAssertFalse(coveringRanges.isEmpty, "An actual active HTTP range must cover every unread target-picture byte; it may precede this seek.")
            XCTAssertFalse(matchingReads.isEmpty, "The current unresolved provider read UUID must belong to that same active request and cover the complete target picture.")
            XCTAssertTrue(targetBytesNeverReadOrSent, "The target picture cannot be available through previously delivered bytes.")
            XCTAssertTrue(targetPoints.isEmpty, "Actual normal/input must not have reached the unavailable target region.")
            struct Qualification: Encodable {
                let plan: UIHeldRangePlan
                let marker: TailPhaseTrace.Record
                let seekApplied: Bool
                let callbackBaseline: UInt64
                let actualCallbackSequence: UInt64
                let beforeHTTPSequence: UInt64
                let activeHTTPRequests: [UInt64]
                let existingCoveringRanges: [TailHTTPTrace.Event]
                let freshCoveringRanges: [TailHTTPTrace.Event]
                let providerUnresolved: Bool
                let historicalHeldReads: Int
                let allPendingReads: [TailHeldSMBProvider.PendingRead]
                let finalByteProbes: [TailHeldSMBProvider.FinalByteProbe]
                let matchingReads: [TailHeldSMBProvider.PendingRead]
                let targetBytesNeverReadOrSent: Bool
                let targetPoints: [TailPhaseTrace.Record]
            }
            let qualification = Qualification(plan: held, marker: marker, seekApplied: applied,
                callbackBaseline: callbackBaseline, actualCallbackSequence: actualCallbackSequence,
                beforeHTTPSequence: beforeSequence, activeHTTPRequests: active.sorted(),
                existingCoveringRanges: existingCoveringRanges, freshCoveringRanges: freshCoveringRanges,
                providerUnresolved: pending.unresolved, historicalHeldReads: pending.historicalHeldReads,
                allPendingReads: pending.reads, finalByteProbes: pending.finalByteProbes, matchingReads: matchingReads,
                targetBytesNeverReadOrSent: targetBytesNeverReadOrSent, targetPoints: targetPoints)
            let proof = XCTAttachment(data: try JSONEncoder().encode(qualification), uniformTypeIdentifier: "public.json")
            proof.name = "Actual unread target UI held-range qualification"
            proof.lifetime = .keepAlways
            self.add(proof)
            let sourceFailureBeforeClose = await session.stream.readFailure()
            XCTAssertNil(sourceFailureBeforeClose)
            // Readonly output baselines are diagnostic. This UI case does not
            // replace the unchanged formal test's actual-output requirements.
            XCTAssertGreaterThanOrEqual(self.player.displayedVideoFrames, displayed)
            XCTAssertGreaterThanOrEqual(self.player.playedAudioBuffers, played)
            observations.append(.capture(player: self.player, origin: uiBegan, phase: "held-waiting-confirmed"))
            self.player.stop()
            XCTAssertNil(self.player.seekStatus)
            await session.stream.stop()
            // Consumer shutdown must cancel its real pending read. Do not
            // resolve the fixture to manufacture recovery or new output.
            let cancelDeadline = ContinuousClock.now.advanced(by: .seconds(6))
            while !(await session.provider.pendingSnapshot().reads.isEmpty) && .now < cancelDeadline {
                try await Task.sleep(for: .milliseconds(100))
            }
            let closed = await session.provider.pendingSnapshot()
            XCTAssertTrue(closed.unresolved)
            XCTAssertEqual(closed.reads.count, 0)
            let noResurrectionDeadline = ContinuousClock.now.advanced(by: .milliseconds(3400))
            repeat {
                observations.append(.capture(player: self.player, origin: uiBegan, phase: "closed-old-timer-observation"))
                XCTAssertNil(self.player.seekStatus)
                XCTAssertFalse(self.player.isPlaying)
                XCTAssertEqual(self.ended, 0)
                XCTAssertEqual(validatorCalls, 0)
                XCTAssertNil(self.player.errorMessage)
                try await Task.sleep(for: .milliseconds(100))
            } while .now < noResurrectionDeadline
            XCTAssertNil(self.player.seekStatus)
            let attachment = XCTAttachment(data: try JSONEncoder().encode(observations),
                                           uniformTypeIdentifier: "public.json")
            attachment.name = "Actual infinite-held UI waiting and close observations"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            await self.attachSMBFailureDiagnostics(session.stream)
            // withTailFixture's existing cleanup resolves only after all
            // pending/close/EOS assertions above; it is not a seek fix.
        }
    }


    func testActiveOneAndHalfSpeedForwardTailSeekConsumesRealOutputOnce() async throws {
        try await assertActiveForwardTailSeekConsumesRealOutputOnce(rate: 1.5)
    }

    func testActiveDoubleSpeedForwardTailSeekConsumesRealOutputOnce() async throws {
        try await assertActiveForwardTailSeekConsumesRealOutputOnce(rate: 2)
    }

    func testActiveOneAndHalfSpeedLongGOPForwardTailSeekConsumesRealOutputOnce() async throws {
        try await assertActiveForwardTailSeekConsumesRealOutputOnce(rate: 1.5,
            fixtureName: "clip-tail-long-gop.mp4", fixtureSHA256: "41ba7c5011ee990d43e079d687533d2f01f276112dd9002e8b53346792af858b")
    }

    func testActiveDoubleSpeedLongGOPForwardTailSeekConsumesRealOutputOnce() async throws {
        try await assertActiveForwardTailSeekConsumesRealOutputOnce(rate: 2,
            fixtureName: "clip-tail-long-gop.mp4", fixtureSHA256: "41ba7c5011ee990d43e079d687533d2f01f276112dd9002e8b53346792af858b")
    }

    func testTailAudioTimingDiagnosticsRejectPrivateAndMalformedMessages() throws {
        XCTAssertEqual(TailAudioTimingEvents.parse("using audio output module \"avsamplebuffer\"", source: nil), [1, 1])
        XCTAssertEqual(TailAudioTimingEvents.parse("deferring start (4966667 us)", source: 1), [3, 4966667])
        XCTAssertEqual(TailAudioTimingEvents.parse("starting late (-12 us)", source: 1), [2, -12])
        XCTAssertNil(TailAudioTimingEvents.parse("deferring start (12 us) smb://private-user:private-secret/private-film", source: 1))
        XCTAssertNil(TailAudioTimingEvents.parse("deferring start (12 us)", source: 2))
        XCTAssertNil(TailAudioTimingEvents.parse("using audio output module \"private-film\"", source: nil))
        let logger = TailAudioTimingEvents()
        for _ in 0..<300 { logger.handleMessage("using audio output module \"avsamplebuffer\"", logLevel: .debug, context: nil) }
        logger.handleMessage("private-secret", logLevel: .debug, context: nil)
        let data = try XCTUnwrap(logger.data())
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(document["totalEvents"] as? Int, 300)
        XCTAssertEqual(document["omittedEvents"] as? Int, 44)
        XCTAssertEqual((document["records"] as? [[Int64]])?.count, 256)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("private"))
    }

    private func assertActiveForwardTailSeekConsumesRealOutputOnce(rate: Float,
        fixtureName: String = "clip-short-gop.mp4",
        fixtureSHA256: String = "33e46b39e57f4e6cd56713f013dc573df8cd3b0d9debda10c4bf2a445c16bd75") async throws {
        let directory = try XCTUnwrap(Bundle(for: Self.self).resourceURL?.appendingPathComponent("PlaybackFixtures"))
        let url = directory.appendingPathComponent(fixtureName)
        XCTAssertEqual(SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined(),
                       fixtureSHA256)
        player.debugEnableLifecycleTrace(origin: origin)
        let audioTiming = TailAudioTimingEvents(origin: origin)
        var observations = [[String: Any]]()
        let target = 11.0
        // Both pinned fixtures end in real audio/video samples at 12.0 seconds.
        // ShortGOP has a keyframe at11; longGOP has only keyframe0 and
        // requires11 seconds of actual preroll before the same target.
        let actualPacketTailSeconds = 1.0
        let minimumSeekToEOSSeconds = actualPacketTailSeconds / Double(rate) - 0.15
        // A normal point is a sampled clock, not a measurement at EOS. The
        // timer's refresh period is a minimum dispatch interval, not a maximum
        // sampling delay. Check clock continuity at the native EOS callback
        // using both callbacks' original ContinuousClock timestamps below.
        let minimumClockAtEOS = 12.0 - 1.0 / 15.0
        // The independent upper uses only Swift ContinuousClock elapsed
        // seconds since this seek request and the unchanged requested rate.
        // VLC systemDate is used for real callback pairing, never subtracted
        // from a Swift clock or wall Date. The actual observer samples at100ms.
        let actualClockObserverIntervalSeconds = 0.1
        var seekOrigin: ContinuousClock.Instant?
        func observe(_ phase: String) {
            var sample: [String: Any] = ["phase": phase, "rate": player.rate,
                "displayedVideoFrames": player.displayedVideoFrames,
                "playedAudioBuffers": player.playedAudioBuffers,
                "isPlaying": player.isPlaying, "backendState": player.backendState,
                "clockRunning": player.backendClockIsRunning, "ended": ended,
                "hasError": player.errorMessage != nil]
            if let seekOrigin {
                let elapsed = seekOrigin.duration(to: .now).components
                sample["afterSeekSeconds"] = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
            }
            if let value = player.backendClockTime { sample["actualNormalTime"] = value }
            if let value = player.backendInputTime { sample["actualInputTime"] = value }
            if let value = player.backendStoppingReason { sample["actualStoppingReason"] = value }
            observations.append(sample)
        }
        defer {
            if let data = audioTiming.data() {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "Active forward tail bounded numeric audio timing"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            observe("final-before-teardown")
            if let data = player.debugLifecycleTraceData() {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "Active forward tail actual native lifecycle including failure"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            if let data = try? JSONSerialization.data(withJSONObject: observations, options: [.sortedKeys]) {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "Active forward tail actual output and wall observations including failure"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        player.setRate(rate)
        player.load(url: url, startAt: 0)
        let identity = ObjectIdentifier(try XCTUnwrap(player.backendEngineForTesting))
        if let library = player.backendEngineForTesting?.libraryInstance {
            library.loggers = (library.loggers ?? []) + [audioTiming]
        }
        try await outputReady("active forward tail early actual output")
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(player.backendState, "playing")
        XCTAssertEqual(player.backendIsPlaying, true)
        XCTAssertEqual(player.rate, rate)
        XCTAssertEqual(ended, 0)
        XCTAssertNil(player.errorMessage)
        let previousNormal = try XCTUnwrap(player.backendClockTime)
        XCTAssertLessThan(previousNormal, 3, "Warmup must precede the pinned target and tail.")
        let displayed = player.displayedVideoFrames
        let played = player.playedAudioBuffers
        observe("before-active-seek")
        seekOrigin = .now
        player.seek(target)
        XCTAssertNil(player.backendClockTime, "The seek must clear the previous native normal point synchronously.")
        XCTAssertFalse(player.backendClockIsRunning)
        XCTAssertNil(player.backendInputTime)
        try await wait("active forward tail fresh target actual native output", timeout: 6, failIf: {
            observe("awaiting-fresh-target-output")
        }) {
            guard let normal = self.player.backendClockTime,
                  let input = self.player.backendInputTime,
                  let trace = TailPhaseTrace.capture(self.player),
                  trace.evictedEvents == 0, let marker = trace.latestSeekMarker(),
                  marker.targetSeconds == target,
                  input >= target - 0.05, input < 12.2 else { return false }
            let hasPairedNormal = trace.records.contains { record in
                guard record.eventCode == 31, record.generation == marker.generation,
                      let callback = trace.pairedCallback(for: record, callbackCode: 30),
                      callback.sequence > marker.sequence, let time = record.timeMicroseconds,
                      let date = record.systemDateMicroseconds, date > 0, date != Int64.max else { return false }
                return abs(normal - Double(time) / 1_000_000) < 0.000002
                    && Double(time) / 1_000_000 > target + 0.05 && Double(time) / 1_000_000 < 11.95
                    && (record.displayedVideoFrames ?? 0) > displayed + 5
                    && (record.playedAudioBuffers ?? 0) > played + 5
            }
            let hasPairedInput = trace.records.contains { record in
                guard record.eventCode == 41, record.generation == marker.generation,
                      let callback = trace.pairedCallback(for: record, callbackCode: 40),
                      callback.sequence > marker.sequence, let time = record.timeMicroseconds else { return false }
                return abs(input - Double(time) / 1_000_000) < 0.000002
                    && Double(time) / 1_000_000 >= target - 0.05 && Double(time) / 1_000_000 < 12.2
            }
            return hasPairedNormal && hasPairedInput && self.player.backendClockIsRunning && normal > target + 0.05 && normal < 11.95
                && self.player.isPlaying && self.player.backendState == "playing"
                && self.player.backendIsPlaying == true && self.ended == 0
                && self.player.displayedVideoFrames > displayed + 5
                && self.player.playedAudioBuffers > played + 5
        }
        observe("fresh-target-output")
        let nativeTrace = try JSONDecoder().decode(TailPhaseTrace.self,
            from: XCTUnwrap(player.debugLifecycleTraceData()))
        let marker = try XCTUnwrap(nativeTrace.latestSeekMarker())
        XCTAssertEqual(marker.targetSeconds, target)
        XCTAssertEqual(nativeTrace.evictedEvents, 0)
        let currentNormal = try XCTUnwrap(player.backendClockTime)
        let currentInput = try XCTUnwrap(player.backendInputTime)
        let pairedNormal = try XCTUnwrap(nativeTrace.records.last { record in
            guard record.eventCode == 31, record.generation == marker.generation,
                  let callback = nativeTrace.pairedCallback(for: record, callbackCode: 30),
                  callback.sequence > marker.sequence, let time = record.timeMicroseconds,
                  let date = record.systemDateMicroseconds, date > 0, date != Int64.max else { return false }
            return abs(currentNormal - Double(time) / 1_000_000) < 0.000002
                && Double(time) / 1_000_000 > target + 0.05 && Double(time) / 1_000_000 < 11.95
                && (record.displayedVideoFrames ?? 0) > displayed + 5
                && (record.playedAudioBuffers ?? 0) > played + 5
        })
        let normalCallback = try XCTUnwrap(nativeTrace.pairedCallback(for: pairedNormal, callbackCode: 30))
        let pairedInput = try XCTUnwrap(nativeTrace.records.last { record in
            guard record.eventCode == 41, record.generation == marker.generation,
                  let callback = nativeTrace.pairedCallback(for: record, callbackCode: 40),
                  callback.sequence > marker.sequence, let time = record.timeMicroseconds else { return false }
            return abs(currentInput - Double(time) / 1_000_000) < 0.000002
                && Double(time) / 1_000_000 >= target - 0.05 && Double(time) / 1_000_000 < 12.2
        })
        let inputCallback = try XCTUnwrap(nativeTrace.pairedCallback(for: pairedInput, callbackCode: 40))
        struct ActualPostSeekPairs: Encodable {
            let fixtureName: String
            let fixtureSHA256: String
            let marker: TailPhaseTrace.Record
            let normalDelivery: TailPhaseTrace.Record
            let normalCallback: TailPhaseTrace.Record
            let inputDelivery: TailPhaseTrace.Record
            let inputCallback: TailPhaseTrace.Record
        }
        let pairs = ActualPostSeekPairs(fixtureName: fixtureName, fixtureSHA256: fixtureSHA256,
            marker: marker, normalDelivery: pairedNormal, normalCallback: normalCallback,
            inputDelivery: pairedInput, inputCallback: inputCallback)
        let actualPairs = XCTAttachment(data: try JSONEncoder().encode(pairs), uniformTypeIdentifier: "public.json")
        actualPairs.name = "Actual post-seek native31-to30 and41-to40 pairs"
        actualPairs.lifetime = .keepAlways
        add(actualPairs)
        XCTAssertEqual(ended, 0, "Real fresh output must be observed before EOS.")
        XCTAssertEqual(player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
        try await wait("active forward tail actual single EOS", timeout: 6, failIf: {
            observe("awaiting-real-eos")
        }) { self.ended > 0 }
        let elapsed = try XCTUnwrap(seekOrigin).duration(to: .now).components
        let seekToEOS = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        let maximumFinalNormal = target + Double(rate)
            * (seekToEOS + actualClockObserverIntervalSeconds)
        let finalNormal = try XCTUnwrap(player.backendClockTime)
        let finalTrace = try JSONDecoder().decode(TailPhaseTrace.self,
            from: XCTUnwrap(player.debugLifecycleTraceData()))
        let finalMarker = try XCTUnwrap(finalTrace.latestSeekMarker())
        XCTAssertEqual(finalMarker, marker)
        XCTAssertEqual(finalTrace.evictedEvents, 0)
        let finalNormalDelivery = try XCTUnwrap(finalTrace.records.last { record in
            guard record.eventCode == 31, record.generation == finalMarker.generation,
                  let callback = finalTrace.pairedCallback(for: record, callbackCode: 30),
                  callback.sequence > finalMarker.sequence, let time = record.timeMicroseconds,
                  let date = record.systemDateMicroseconds, date > 0, date != Int64.max else { return false }
            return abs(finalNormal - Double(time) / 1_000_000) < 0.000002
        })
        let finalNormalCallback = try XCTUnwrap(finalTrace.pairedCallback(for: finalNormalDelivery, callbackCode: 30))
        struct TimedCallbacks: Decodable {
            struct Record: Decodable {
                let sequence: Int
                let eventCode: Int
                let generation: Int
                let elapsedSeconds: Double
                let state: Int?
                let sourceSequence: Int?
                let accepted: Bool?
            }
            let records: [Record]
        }
        let timedCallbacks = try JSONDecoder().decode(TimedCallbacks.self,
            from: XCTUnwrap(player.debugLifecycleTraceData()))
        let clockCallback = try XCTUnwrap(timedCallbacks.records.first {
            $0.sequence == finalNormalCallback.sequence && $0.eventCode == 30
                && $0.generation == marker.generation
        })
        let eosCallback = try XCTUnwrap(timedCallbacks.records.first {
            $0.eventCode == 50 && $0.generation == marker.generation
                && $0.sequence > clockCallback.sequence
                && $0.state == Int(AetherVLCMediaStoppingReason.endOfStream.rawValue)
                && $0.accepted == true
        })
        XCTAssertTrue(timedCallbacks.records.contains {
            $0.eventCode == 51 && $0.generation == marker.generation
                && $0.sourceSequence == eosCallback.sequence && $0.accepted == true
        })
        let callbackToEOSSeconds = eosCallback.elapsedSeconds - clockCallback.elapsedSeconds
        XCTAssertTrue(callbackToEOSSeconds.isFinite && callbackToEOSSeconds >= 0)
        XCTAssertLessThanOrEqual(callbackToEOSSeconds, 6)
        let projectedClockAtNativeEOS = finalNormal + Double(rate) * callbackToEOSSeconds
        // This is explicitly an oracle projection, never a replacement for
        // the raw backend clock or evidence of rendered audio. Real output,
        // minimum consumption wall time and exactly-once EOS remain required.
        struct ActualFinalNormalPair: Encodable {
            let marker: TailPhaseTrace.Record
            let delivery: TailPhaseTrace.Record
            let callback: TailPhaseTrace.Record
            let actualSeekToObservedEOSSeconds: Double
            let actualClockObserverIntervalSeconds: Double
            let wallClockMaximumFinalNormal: Double
            let originalClockCallbackElapsedSeconds: Double
            let originalEOSCallbackElapsedSeconds: Double
            let callbackToEOSSeconds: Double
            let projectedClockAtNativeEOS: Double
            let minimumClockAtEOS: Double
        }
        let finalPair = ActualFinalNormalPair(marker: finalMarker, delivery: finalNormalDelivery,
            callback: finalNormalCallback, actualSeekToObservedEOSSeconds: seekToEOS,
            actualClockObserverIntervalSeconds: actualClockObserverIntervalSeconds,
            wallClockMaximumFinalNormal: maximumFinalNormal,
            originalClockCallbackElapsedSeconds: clockCallback.elapsedSeconds,
            originalEOSCallbackElapsedSeconds: eosCallback.elapsedSeconds,
            callbackToEOSSeconds: callbackToEOSSeconds,
            projectedClockAtNativeEOS: projectedClockAtNativeEOS,
            minimumClockAtEOS: minimumClockAtEOS)
        let finalPairAttachment = XCTAttachment(data: try JSONEncoder().encode(finalPair), uniformTypeIdentifier: "public.json")
        finalPairAttachment.name = "Actual final live native31-to30 pair and independent ContinuousClock upper"
        finalPairAttachment.lifetime = .keepAlways
        add(finalPairAttachment)
        observations.append(["phase": "actual-tail-completion-timing", "rate": rate,
            "seekToEOSSeconds": seekToEOS, "minimumSeekToEOSSeconds": minimumSeekToEOSSeconds,
            "actualPacketTailSeconds": actualPacketTailSeconds, "minimumClockAtEOS": minimumClockAtEOS,
            "rawFinalNormal": finalNormal, "projectedClockAtNativeEOS": projectedClockAtNativeEOS,
            "callbackToEOSSeconds": callbackToEOSSeconds,
            "maximumFinalNormal": maximumFinalNormal,
            "actualClockObserverIntervalSeconds": actualClockObserverIntervalSeconds,
            "clockUpperDomain": "Swift ContinuousClock elapsed seconds since seek; no VLC date mixing"])
        XCTAssertGreaterThanOrEqual(seekToEOS, minimumSeekToEOSSeconds,
                                    "EOS must consume the pinned actual tail; the old 70–220 ms stop is insufficient.")
        XCTAssertLessThanOrEqual(seekToEOS, 6)
        XCTAssertGreaterThanOrEqual(projectedClockAtNativeEOS, minimumClockAtEOS,
                                    "The sampled normal clock must continue through the pinned final video PTS at native EOS.")
        XCTAssertLessThanOrEqual(try XCTUnwrap(player.backendClockTime), maximumFinalNormal)
        XCTAssertGreaterThan(player.displayedVideoFrames, displayed + 5)
        XCTAssertGreaterThan(player.playedAudioBuffers, played + 5)
        XCTAssertEqual(player.backendStoppingReason, Int(AetherVLCMediaStoppingReason.endOfStream.rawValue))
        XCTAssertEqual(player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
        XCTAssertEqual(ended, 1)
        XCTAssertFalse(player.isPlaying)
        XCTAssertNil(player.errorMessage)
        try await Task.sleep(for: .milliseconds(300))
        observe("completion-remains-single")
        XCTAssertEqual(ended, 1)
        XCTAssertEqual(player.backendEngineForTesting.map(ObjectIdentifier.init), identity)
    }

    private func outputReady(_ label: String) async throws {
        try await wait(label) {
            self.player.duration > 11 && (self.player.backendClockTime ?? 0) > 0.8
                && (self.player.backendClockTime ?? 0) < self.player.duration
                && self.player.displayedVideoFrames > 0 && self.player.playedAudioBuffers > 0
        }
    }

    private func wait(_ label: String, timeout: Double = 12, failIf: (() throws -> Void)? = nil, condition: () -> Bool) async throws {
        snapshot(label + " begin")
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        while !condition() && .now < deadline {
            try failIf?()
            try await Task.sleep(for: .milliseconds(100))
        }
        try failIf?()
        snapshot(label + (condition() ? " ready" : " timeout"))
        XCTAssertTrue(condition(), label)
        if !condition() { throw EOFPlaybackError.timeout }
    }

    private func snapshot(_ label: String) {
        let components = origin.duration(to: .now).components
        let elapsed = Double(components.seconds) + Double(components.attoseconds) / 1e18
        print("EOF t=\(elapsed) phase=\(label) state=\(player.backendState) UI=\(player.position) cache=\(player.backendTime ?? -1) input=\(player.backendInputTime ?? -1) clock=\(player.backendClockTime ?? -1) reason=\(player.backendStoppingReason ?? -1) ended=\(ended) video=\(player.decodedVideoFrames)/\(player.displayedVideoFrames) audio=\(player.decodedAudioBuffers)/\(player.playedAudioBuffers) error=\(player.errorMessage != nil)")
    }

    private func persistedProgress() async throws -> PlaybackProgress? {
        await store.flushProgress()
        return try await LibraryStore(url: storageURL).load().progress[item.id]
    }
}

/// Packet offsets are bound to the existing fixture by its SHA256 and the
/// candidate's raw ffprobe output. This changes only the UI case's transport.
private struct UIHeldRangePlan: Encodable {
    let sampleSHA256 = "33e46b39e57f4e6cd56713f013dc573df8cd3b0d9debda10c4bf2a445c16bd75"
    let holdAt: Int64 = 267381 // Video keyframe at PTS/DTS 4.000000.
    let target = 8.0
    let targetPictureLowerBound: Int64 = 539857
    let targetPictureUpperBound: Int64 = 548853 // 8996-byte keyframe, PTS/DTS 8.000000.

    func overlapsTarget(offset: Int64, count: Int64) -> Bool {
        offset >= 0 && count > 0 && offset < targetPictureUpperBound && count > targetPictureLowerBound - offset
    }

    func coversTarget(offset: Int64, count: Int64) -> Bool {
        offset >= 0 && offset <= targetPictureLowerBound && count >= targetPictureUpperBound - offset
    }
}

private actor TailHeldSMBProvider: SMBFileProviding {
    struct FinalByteProbe: Sendable, Encodable {
        let offset: Int64
        let count: Int64
    }
    struct PendingRead: Sendable, Encodable {
        let id: UUID
        let httpRequestID: UInt64?
        let lowerBound: Int64
        let upperBound: Int64
    }
    struct PendingSnapshot: Sendable {
        let unresolved: Bool
        let historicalHeldReads: Int
        let reads: [PendingRead]
        let finalByteProbes: [FinalByteProbe]
    }
    private struct Waiter {
        let continuation: CheckedContinuation<Void, any Error>
        let cancellation: TailReadCancellation
        let read: PendingRead
    }
    private let provider = SMBProvider()
    private let holdAt: Int64
    private let fileBytes: Int64
    private var finalByteProbes: [FinalByteProbe] = []
    private var resolution: Bool?
    private var waiters: [UUID: Waiter] = [:]
    private var armedReads: Set<UUID> = []
    private var cancelledBeforeRegistration: Set<UUID> = []
    private var heldReads = 0
    init(holdAt: Int64, fileBytes: Int64) { self.holdAt = holdAt; self.fileBytes = fileBytes }
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
        if TailReadGate.isFinalByteProbe(range, fileBytes: fileBytes) {
            finalByteProbes.append(.init(offset: range.lowerBound, count: Int64(range.count)))
            print("EOF SMB final-byte probe offset=\(range.lowerBound) count=\(range.count)")
            return try await provider.readFile(connection, credentials: credentials, path: path, range: range)
        }
        if range.lowerBound >= holdAt {
            heldReads += 1
            if resolution == nil {
                let id = UUID()
                let cancellation = TailReadCancellation()
                let read = PendingRead(id: id, httpRequestID: SMBStreamTraceScope.request?.requestID,
                                       lowerBound: range.lowerBound, upperBound: range.upperBound)
                armedReads.insert(id)
                try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                        if cancellation.isCancelled || Task.isCancelled || cancelledBeforeRegistration.remove(id) != nil {
                            armedReads.remove(id)
                            continuation.resume(throwing: CancellationError())
                        } else if let resolution {
                            armedReads.remove(id)
                            if resolution { continuation.resume(throwing: SMBError.connectionFailed) }
                            else { continuation.resume() }
                        } else {
                            waiters[id] = Waiter(continuation: continuation, cancellation: cancellation, read: read)
                        }
                    }
                } onCancel: {
                    // Mark cancellation synchronously; an actor hop cannot
                    // leave a cancelled waiter temporarily eligible for release.
                    cancellation.cancel()
                    Task { await self.cancelRead(id) }
                }
            }
            try Task.checkCancellation()
            if resolution == true { throw SMBError.connectionFailed }
        }
        let upper = resolution == false ? range.upperBound : min(range.upperBound, holdAt)
        let data = try await provider.readFile(connection, credentials: credentials, path: path, range: range.lowerBound..<upper)
        print("EOF SMB bytes offset=\(range.lowerBound) requested=\(range.count) actual=\(data.count)")
        return data
    }
    func heldReadCount() -> Int { heldReads }
    func pendingSnapshot() -> PendingSnapshot {
        PendingSnapshot(unresolved: resolution == nil, historicalHeldReads: heldReads,
                        reads: waiters.values.filter { !$0.cancellation.isCancelled }.map(\.read),
                        finalByteProbes: finalByteProbes)
    }
    private func cancelRead(_ id: UUID) {
        guard armedReads.remove(id) != nil else { return }
        if let waiter = waiters.removeValue(forKey: id) {
            waiter.continuation.resume(throwing: CancellationError())
        } else {
            cancelledBeforeRegistration.insert(id)
        }
    }
    func resolveIfActive(fails: Bool, matchingHTTPRequests: Set<UInt64>) throws {
        guard resolution == nil,
              waiters.values.contains(where: { waiter in
                  !waiter.cancellation.isCancelled && waiter.read.lowerBound >= holdAt
                      && waiter.read.upperBound > waiter.read.lowerBound
                      && waiter.read.httpRequestID.map(matchingHTTPRequests.contains) == true
              }) else { throw TailFixtureError.noActiveMatchingRead }
        resolveForCleanup(fails: fails)
    }
    func resolveForCleanup(fails: Bool) {
        guard resolution == nil else { return }
        resolution = fails
        let pending = Array(waiters.values)
        waiters.removeAll()
        armedReads.removeAll()
        cancelledBeforeRegistration.removeAll()
        for waiter in pending {
            if waiter.cancellation.isCancelled { waiter.continuation.resume(throwing: CancellationError()) }
            else if fails { waiter.continuation.resume(throwing: SMBError.connectionFailed) }
            else { waiter.continuation.resume() }
        }
    }
    func close() async { await provider.close() }
}

private final class TailReadCancellation: Sendable {
    private let cancelled = Mutex(false)
    var isCancelled: Bool { cancelled.withLock { $0 } }
    func cancel() { cancelled.withLock { $0 = true } }
}

private enum TailFixtureError: Error { case noActiveMatchingRead }

/// Owned loopback test transport only. Bounded BSD operations use GCD so they
/// cannot block the cooperative executor needed by the actor-based server.
private enum TailTCPResetClient {
    private static let socketQueue = DispatchQueue(label: "com.aethernative.film.tests.tail-reset", attributes: .concurrent)

    private static func socketOperation<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            socketQueue.async {
                do { continuation.resume(returning: try operation()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    static func sendRequest(to url: URL, range: String) async throws -> Int32 {
        try await socketOperation {
            guard url.scheme == "http", url.host == "127.0.0.1", let port = url.port,
                  port > 0, port <= 65535 else { throw SMBError.invalidResponse }
            let socket = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
            guard socket >= 0 else { throw socketError() }
            do {
                var noSIGPIPE: Int32 = 1
                guard setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &noSIGPIPE,
                                 socklen_t(MemoryLayout.size(ofValue: noSIGPIPE))) == 0 else { throw socketError() }
                var timeout = timeval(tv_sec: 3, tv_usec: 0)
                guard setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &timeout,
                                 socklen_t(MemoryLayout.size(ofValue: timeout))) == 0 else { throw socketError() }
                var address = sockaddr_in()
                address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                address.sin_family = sa_family_t(AF_INET)
                address.sin_port = UInt16(port).bigEndian
                guard inet_pton(AF_INET, "127.0.0.1", &address.sin_addr) == 1 else { throw socketError() }
                let connected = withUnsafePointer(to: &address) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                guard connected == 0 else { throw socketError() }
                let request = Data("GET \(url.path) HTTP/1.1\r\nHost: 127.0.0.1\r\nRange: \(range)\r\nConnection: close\r\n\r\n".utf8)
                try request.withUnsafeBytes { bytes in
                    var sent = 0
                    while sent < bytes.count {
                        let count = Darwin.send(socket, bytes.baseAddress!.advanced(by: sent), bytes.count - sent, 0)
                        if count < 0 && errno == EINTR { continue }
                        guard count > 0 else { throw socketError() }
                        sent += count
                    }
                }
                return socket
            } catch { Darwin.close(socket); throw error }
        }
    }

    static func closeWithReset(_ socket: Int32) async throws {
        try await socketOperation {
            defer { Darwin.close(socket) }
            var reset = linger(l_onoff: 1, l_linger: 0)
            guard setsockopt(socket, SOL_SOCKET, SO_LINGER, &reset,
                             socklen_t(MemoryLayout.size(ofValue: reset))) == 0 else { throw socketError() }
        }
    }

    private static func socketError() -> POSIXError { POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
}

private enum EOFPlaybackError: Error { case timeout, fixtureUnavailable, invalidResumePoint }

private struct EOFSMBFixture: Decodable {
    let host: String?
    let port: Int
    let username: String
    let password: String
    let share: String
    let mediaPath: String

    static func configuration() async throws -> Self {
        let expectedHost = ProcessInfo.processInfo.environment["AETHERFILM_SMB_TEST_HOST"] ?? "127.0.0.1"
        guard let address = ProcessInfo.processInfo.environment["AETHERFILM_SMB_BOOTSTRAP_URL"],
              let url = URL(string: address), url.scheme == "http", url.host == expectedHost else {
            throw XCTSkip("Run the SMB fixture launcher with --bootstrap-only and generated playback fixtures.")
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw EOFPlaybackError.fixtureUnavailable }
            let fixture = try JSONDecoder().decode(Self.self, from: data)
            guard (fixture.host ?? "127.0.0.1") == expectedHost else { throw EOFPlaybackError.fixtureUnavailable }
            return fixture
        } catch { throw EOFPlaybackError.fixtureUnavailable }
    }
}

private struct EOFTailMetadata: Decodable {
    let fileBytes: Int64
    let tailHoldAt: Int64
    let lastVideoPTSBeforeTail: Double
    let firstHeldPTS: Double
}

/// Test-only whitelist. Never retain native messages, paths or object IDs.
/// Records: elapsed microseconds, event code, value. Module event 1 values:
/// 1=avsamplebuffer, 2=auhal, 3=audiounit_ios. Events 2/3/4: late/deferred/started.
/// Missing events do not prove module selection or absence of a timing problem.
final class TailAudioTimingEvents: NSObject, VLCLogging, @unchecked Sendable {
    var level: VLCLogLevel = .debug
    private let lock = NSLock()
    private let origin: ContinuousClock.Instant
    private var first: [[Int64]] = []
    private var tail: [[Int64]] = []
    private var total = 0

    init(origin: ContinuousClock.Instant = .now) {
        self.origin = origin
        super.init()
    }

    static func parse(_ message: String, source: Int?) -> [Int64]? {
        let modules = ["avsamplebuffer", "auhal", "audiounit_ios"]
        if let index = modules.firstIndex(where: { message == "using audio output module \"\($0)\"" }) {
            return [1, Int64(index + 1)]
        }
        guard source == 1 else { return nil }
        if message == "started" { return [4, 0] }
        for (index, prefix) in ["starting late (", "deferring start ("].enumerated() {
            guard message.hasPrefix(prefix), message.hasSuffix(" us)") else { continue }
            let number = message.dropFirst(prefix.count).dropLast(4)
            guard !number.isEmpty, number.utf8.allSatisfy({ (48...57).contains($0) || $0 == 45 }),
                  let value = Int64(number) else { return nil }
            return [Int64(index + 2), value]
        }
        return nil
    }

    func handleMessage(_ message: String, logLevel: VLCLogLevel, context: VLCLogContext?) {
        let avSource = context?.module == "avsamplebuffer"
            || (context?.module == "libvlc"
                && context?.file?.hasSuffix("/modules/audio_output/apple/avsamplebuffer.m") == true)
        let source = avSource && context?.function == "-[VLCAVSample whenDataReady]" ? 1 : nil
        guard let event = Self.parse(message, source: source) else { return }
        let duration = origin.duration(to: .now).components
        let elapsed = duration.seconds * 1_000_000 + duration.attoseconds / 1_000_000_000_000
        lock.withLock {
            total += 1
            let record = [elapsed] + event
            if first.count < 32 { first.append(record) }
            else {
                if tail.count == 224 { tail.removeFirst() }
                tail.append(record)
            }
        }
    }

    func data() -> Data? {
        lock.withLock {
            try? JSONSerialization.data(withJSONObject: ["schema": 1, "totalEvents": total,
                "omittedEvents": total - first.count - tail.count, "records": first + tail], options: [.sortedKeys])
        }
    }
}
