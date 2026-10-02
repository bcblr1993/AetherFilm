#if os(iOS)
import AVFAudio
import Dispatch
import Foundation
import Synchronization
import UIKit
import XCTest
@testable import AetherFilm

/// Holds only the background audio operation. Playback, output counters and
/// native surface attachment use the actual VLC backend and system session.
@MainActor
final class AudioPreparationPlaybackTests: XCTestCase {
    private var driver: GatedSystemAudioSessionDriver!
    private var coordinator: AudioSessionCoordinator!
    private var player: FilmPlayer!
    private var window: UIWindow!
    private var surface: UIView!
    private weak var previousKeyWindow: UIWindow?

    override func setUp() async throws {
        driver = GatedSystemAudioSessionDriver()
        coordinator = AudioSessionCoordinator(driver: driver)
        player = FilmPlayer(audioSessionCoordinator: coordinator)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first,
                                 "Actual playback requires an initialized application scene.")
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = UIViewController()
        surface = makeSurface()
        window.makeKeyAndVisible()
        player.attachDrawable(surface)
    }

    override func tearDown() async throws {
        defer {
            window?.isHidden = true
            previousKeyWindow?.makeKeyAndVisible()
            previousKeyWindow = nil
            window = nil
            surface = nil
            player = nil
            coordinator = nil
            driver = nil
        }
        driver?.releaseAll()
        player?.stop()
        if let surface { player?.detachDrawable(surface) }
        // A temporary lease supplies a FIFO completion barrier after stop.
        // Its real deactivation also prevents cross-test audio-session overlap.
        if let coordinator, let driver {
            let cleanupOwner = UUID()
            let activated = await withCheckedContinuation { continuation in
                coordinator.activate(owner: cleanupOwner) {
                    continuation.resume(returning: $0)
                }
            }
            XCTAssertTrue(activated, "The system audio-session cleanup barrier must activate successfully.")
            let completed = driver.snapshot.completedDeactivations
            coordinator.deactivate(owner: cleanupOwner)
            if activated {
                try await waitUntil("the final real audio lease is released") {
                    let state = driver.snapshot
                    return state.completedDeactivations > completed && !state.active && state.inFlight == 0
                }
            }
            XCTAssertFalse(driver.snapshot.ranOnMainThread)
            XCTAssertEqual(driver.snapshot.failedOperations, 0,
                           "A system operation failure must remain visible in these integration tests.")
        }
    }

    func testPauseDuringInitialAudioPreparationCancelsStartAndCanResume() async throws {
        driver.holdActivation(1)
        player.load(url: try fixture("clip-h264.mp4"))
        try await waitForHeldActivation(1)
        XCTAssertTrue(player.isLoading)
        player.play()
        player.play()
        XCTAssertEqual(driver.snapshot.requestedActivations, 1,
                       "Repeated play shares the in-flight preparation.")

        // This task must execute on MainActor while the actual audio worker is
        // still held. No semaphore wait or synchronous XCTest wait runs here.
        await Task { @MainActor in self.player.pause() }.value
        XCTAssertTrue(driver.snapshot.heldActivations.contains(1))
        XCTAssertFalse(player.isLoading)
        XCTAssertFalse(player.isPlaying)
        driver.releaseActivation(1)
        try await waitUntil("paused preparation releases its real audio lease") {
            self.driver.snapshot.completedDeactivations == 1
        }
        XCTAssertEqual(player.decodedVideoFrames, 0)
        XCTAssertEqual(player.playedAudioBuffers, 0)
        XCTAssertFalse(player.isPlaying)
        XCTAssertNil(player.errorMessage)
        record("initial preparation canceled")

        player.play()
        try await waitForOutput("resume after canceling preparation")
        XCTAssertEqual(driver.snapshot.completedActivations, 2)
        XCTAssertNil(player.errorMessage)
        record("canceled preparation resumed with real output")
    }

    func testStopAndSwitchFilmDuringPreparationIgnoreOldCompletion() async throws {
        driver.holdActivation(1)
        player.load(url: try fixture("clip-h264.mp4"))
        try await waitForHeldActivation(1)
        player.stop()
        XCTAssertEqual(player.backendState, "none")
        XCTAssertFalse(player.isLoading)
        player.load(url: try fixture("clip-smb-long.mp4"), startAt: 10)
        XCTAssertEqual(player.decodedVideoFrames, 0)
        driver.releaseActivation(1)

        try await waitForOutput("the new film starts after the old activation is released", after: 10.2)
        XCTAssertGreaterThan(player.duration, 74,
                             "The old 12-second film must not replace the new 75-second film.")
        XCTAssertEqual(driver.snapshot.completedActivations, 2)
        XCTAssertEqual(driver.snapshot.completedDeactivations, 1)
        XCTAssertEqual(Array(driver.snapshot.events.prefix(5)), [
            .activationBegan(1), .activationFinished(1), .deactivationFinished,
            .activationBegan(2), .activationFinished(2)
        ], "Old cleanup must finish before new playback acquires the system session.")
        XCTAssertNil(player.errorMessage)
        record("new film owns real output after old completion")
    }

    func testInitialPreparationWithoutSurfaceReleasesAudioAndStartsOnReattach() async throws {
        driver.holdActivation(1)
        player.load(url: try fixture("clip-h264.mp4"))
        try await waitForHeldActivation(1)
        player.detachDrawable(surface)
        driver.releaseActivation(1)
        try await waitUntil("surface-free initial completion releases audio") {
            self.driver.snapshot.completedDeactivations == 1
        }
        XCTAssertEqual(player.decodedVideoFrames, 0)
        XCTAssertEqual(player.playedAudioBuffers, 0)
        XCTAssertFalse(player.isPlaying)
        XCTAssertNil(player.errorMessage)
        record("initial preparation completed without a surface")

        replaceAndAttachSurface()
        try await waitForOutput("initial real output after attaching a replacement surface")
        XCTAssertEqual(driver.snapshot.completedActivations, 2)
        XCTAssertTrue(driver.snapshot.active)
        record("initial surface reattachment reacquires real audio")
    }

    func testPlayingSurfaceReattachmentReacquiresReleasedAudioLease() async throws {
        player.load(url: try fixture("clip-smb-long.mp4"))
        try await waitForOutput("initial output before playing surface replacement")
        driver.holdActivation(2)
        player.play()
        try await waitForHeldActivation(2)
        player.detachDrawable(surface)
        driver.releaseActivation(2)
        try await waitUntil("playing surface-free completion releases audio") {
            self.driver.snapshot.completedDeactivations == 1
        }
        XCTAssertFalse(driver.snapshot.active)
        // This reproduces the independent reattachment bug: cached playing
        // alone does not establish that the system audio lease is still held.
        record("playing backend with detached surface and released audio")
        let time = try XCTUnwrap(player.backendTime)
        let displayed = player.displayedVideoFrames
        let audio = player.playedAudioBuffers

        replaceAndAttachSurface()
        try await waitUntil("reattachment performs a new real system activation") {
            self.driver.snapshot.completedActivations == 3 && self.driver.snapshot.active
        }
        try await waitUntil("reattached playing video and audio actually advance") {
            self.player.isPlaying && (self.player.backendTime ?? 0) > time + 0.5
                && self.player.displayedVideoFrames > displayed && self.player.playedAudioBuffers > audio
        }
        XCTAssertNil(player.errorMessage)
        record("playing surface reattachment restores video and audio output")
    }

    private func makeSurface() -> UIView {
        let view = UIView(frame: window.bounds)
        view.backgroundColor = .black
        window.rootViewController?.view.addSubview(view)
        return view
    }

    private func replaceAndAttachSurface() {
        surface.removeFromSuperview()
        surface = makeSurface()
        player.attachDrawable(surface)
    }

    private func waitForHeldActivation(_ index: Int) async throws {
        try await waitUntil("background activation \(index) is held") {
            self.driver.snapshot.heldActivations.contains(index)
        }
        XCTAssertFalse(driver.snapshot.ranOnMainThread)
    }

    private func waitForOutput(_ label: String, after position: Double = 0.8) async throws {
        try await waitUntil(label) {
            self.player.isPlaying && self.player.position > position
                && self.player.displayedVideoFrames > 0 && self.player.playedAudioBuffers > 0
        }
    }

    private func waitUntil(_ label: String, timeout: Double = 12,
                           _ condition: @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        while !condition() && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        guard condition() else {
            record("timeout: \(label)")
            XCTFail("\(label) timed out")
            throw PreparationTestError.timeout
        }
    }

    private func fixture(_ filename: String) throws -> URL {
        let bundle = Bundle(for: Self.self)
        let folders = [bundle.resourceURL?.appendingPathComponent("PlaybackFixtures"), bundle.resourceURL,
                       ProcessInfo.processInfo.environment["AETHERFILM_FIXTURES"].map { URL(fileURLWithPath: $0) }]
            .compactMap { $0 }
        return try XCTUnwrap(folders.map { $0.appendingPathComponent(filename) }
            .first { FileManager.default.fileExists(atPath: $0.path) }, "Missing generated playback fixture: \(filename)")
    }

    private func record(_ phase: String) {
        guard let player, let driver else { return }
        let state = driver.snapshot
        let diagnostic = "phase=\(phase), modelPlaying=\(player.isPlaying), loading=\(player.isLoading), "
            + "backend=\(player.backendState), backendPlaying=\(String(describing: player.backendIsPlaying)), "
            + "time=\(player.backendTime ?? -1), duration=\(player.duration), "
            + "displayed=\(player.displayedVideoFrames), audioPlayed=\(player.playedAudioBuffers), "
            + "activations=\(state.completedActivations), deactivations=\(state.completedDeactivations), "
            + "systemActive=\(state.active), ranOnMain=\(state.ranOnMainThread), events=\(state.events)"
        print("Audio preparation integration: \(diagnostic)")
        let attachment = XCTAttachment(string: diagnostic)
        attachment.name = phase
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private enum PreparationTestError: Error { case timeout }

private nonisolated final class GatedSystemAudioSessionDriver: AudioSessionDriver {
    enum Event: Equatable, Sendable {
        case activationBegan(Int)
        case activationFinished(Int)
        case deactivationFinished
    }

    struct Snapshot: Sendable {
        var requestedActivations = 0
        var completedActivations = 0
        var completedDeactivations = 0
        var inFlight = 0
        var failedOperations = 0
        var ranOnMainThread = false
        var active = false
        var heldActivations: Set<Int> = []
        var events: [Event] = []
    }

    private enum Failure: Error { case holdTimedOut }
    private let state = Mutex(Snapshot())
    private let gates = Mutex<[Int: DispatchSemaphore]>([:])
    var snapshot: Snapshot { state.withLock { $0 } }

    func holdActivation(_ index: Int) {
        gates.withLock { $0[index] = DispatchSemaphore(value: 0) }
    }

    func releaseActivation(_ index: Int) {
        gates.withLock { $0[index] }?.signal()
    }

    func releaseAll() {
        let pending = gates.withLock { Array($0.values) }
        for gate in pending { gate.signal() }
    }

    func activate() throws {
        let index = state.withLock { current in
            current.requestedActivations += 1
            current.inFlight += 1
            current.ranOnMainThread = current.ranOnMainThread || Thread.isMainThread
            current.events.append(.activationBegan(current.requestedActivations))
            return current.requestedActivations
        }
        defer { state.withLock { $0.inFlight -= 1 } }
        do {
            if let gate = gates.withLock({ $0[index] }) {
                state.withLock { _ = $0.heldActivations.insert(index) }
                let result = gate.wait(timeout: .now() + 15)
                state.withLock { _ = $0.heldActivations.remove(index) }
                guard result == .success else { throw Failure.holdTimedOut }
            }
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
            state.withLock { current in
                current.completedActivations += 1
                current.active = true
                current.events.append(.activationFinished(index))
            }
        } catch {
            state.withLock { $0.failedOperations += 1 }
            throw error
        }
    }

    func deactivate() throws {
        state.withLock { current in
            current.inFlight += 1
            current.ranOnMainThread = current.ranOnMainThread || Thread.isMainThread
        }
        defer { state.withLock { $0.inFlight -= 1 } }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            state.withLock { current in
                current.completedDeactivations += 1
                current.active = false
                current.events.append(.deactivationFinished)
            }
        } catch {
            state.withLock { $0.failedOperations += 1 }
            throw error
        }
    }
}
#endif
