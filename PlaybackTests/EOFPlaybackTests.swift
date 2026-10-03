import XCTest
import VLCKit
import AetherVLCBridge
import FilmDomain
import FilmSources
import FilmLibrary
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
        surface = VLCVideoView(frame: NSRect(x: 0, y: 0, width: 640, height: 360))
        surface.backColor = .black
        window.contentView = surface
        window.orderFront(nil)
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
        player.onProgress = { [weak self] position, duration, confirmed in
            guard let self else { return }
            self.progressCalls += 1
            if duration > 0 { self.maximumProgressFraction = max(self.maximumProgressFraction, position / duration) }
            self.store.recordProgress(self.item, position: position, duration: duration, allowsAutomaticWatched: confirmed)
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

    private func realSMBTail(fails: Bool) async throws {
        let fixture = try await EOFSMBFixture.configuration()
        let credentials = SMBCredentials(username: fixture.username, password: fixture.password)
        let connection = SMBConnection(name: "fixture", host: "127.0.0.1", port: fixture.port, share: fixture.share, rootPath: fixture.mediaPath)
        let path = fixture.mediaPath + "/clip-short-gop.mp4"
        let metadataURL = try XCTUnwrap(Bundle(for: Self.self).resourceURL?
            .appendingPathComponent("PlaybackFixtures/clip-short-gop-tail.json"))
        let metadata = try JSONDecoder().decode(EOFTailMetadata.self, from: Data(contentsOf: metadataURL))
        XCTAssertGreaterThan(metadata.lastVideoPTSBeforeTail, 11.9)
        XCTAssertGreaterThanOrEqual(metadata.firstHeldPTS, 11.966)
        XCTAssertGreaterThan(metadata.fileBytes, metadata.tailHoldAt)
        let provider = TailHeldSMBProvider(holdAt: metadata.tailHoldAt)
        let size = try await provider.fileSize(connection, credentials: credentials, path: path)
        XCTAssertEqual(size, metadata.fileBytes)
        let stream = SMBStreamingServer(provider: provider, connection: connection, credentials: credentials, path: path, size: size)
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
        player.load(url: url, startAt: 10)
        do {
            try await wait("SMB near-tail real output", timeout: 6) {
                self.player.backendClockIsRunning && (self.player.backendClockTime ?? 0) > 11.8
                    && (self.player.backendTime ?? 0) > 11.85 && (self.player.backendTime ?? 99) < 12.05
                    && self.player.isPlaying && self.player.displayedVideoFrames > 5 && self.player.playedAudioBuffers > 5
            }
            let held = await provider.heldReadCount()
            XCTAssertGreaterThan(held, 0, "Actual pending NAS tail read must be reached before release/failure.")
            let initialFailure = await stream.readFailure()
            XCTAssertNil(initialFailure)
            snapshot("SMB near-tail before " + (fails ? "source error" : "healthy release"))
            await provider.resolve(fails: fails)
            if fails {
                try await wait("SMB source failure blocks EOS", timeout: 6) { rejected && self.player.errorMessage != nil }
                XCTAssertEqual(ended, 0)
                XCTAssertEqual(validatorCalls, 1)
                let sourceFailure = await stream.readFailure()
                XCTAssertEqual(sourceFailure, SMBError.connectionFailed)
                XCTAssertLessThan(player.position, player.duration, "Failed input must not synthesize the final position.")
                let saved = try await persistedProgress()
                XCTAssertLessThan(saved?.position ?? player.duration, player.duration)
            } else {
                try await wait("SMB healthy real EOS", timeout: 6) { self.ended == 1 }
                XCTAssertEqual(validatorCalls, 1)
                XCTAssertNil(player.errorMessage)
                let finalFailure = await stream.readFailure()
                XCTAssertNil(finalFailure)
            }
            snapshot("SMB tail result")
            player.stop()
            await stream.stop()
            await provider.close()
        } catch {
            await provider.resolve(fails: true)
            player.stop()
            await stream.stop()
            await provider.close()
            throw error
        }
    }

    private func outputReady(_ label: String) async throws {
        try await wait(label) {
            self.player.duration > 11 && (self.player.backendClockTime ?? 0) > 0.8
                && (self.player.backendClockTime ?? 0) < self.player.duration
                && self.player.displayedVideoFrames > 0 && self.player.playedAudioBuffers > 0
        }
    }

    private func wait(_ label: String, timeout: Double = 12, condition: () -> Bool) async throws {
        snapshot(label + " begin")
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        while !condition() && .now < deadline { try await Task.sleep(for: .milliseconds(100)) }
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

private actor TailHeldSMBProvider: SMBFileProviding {
    private let provider = SMBProvider()
    private let holdAt: Int64
    private var resolution: Bool?
    private var waiters: [CheckedContinuation<Void, any Error>] = []
    private var heldReads = 0
    init(holdAt: Int64) { self.holdAt = holdAt }
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
        if range.lowerBound >= holdAt {
            heldReads += 1
            if resolution == nil {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in waiters.append(continuation) }
            }
            if resolution == true { throw SMBError.connectionFailed }
        }
        let upper = resolution == false ? range.upperBound : min(range.upperBound, holdAt)
        let data = try await provider.readFile(connection, credentials: credentials, path: path, range: range.lowerBound..<upper)
        print("EOF SMB bytes offset=\(range.lowerBound) requested=\(range.count) actual=\(data.count)")
        return data
    }
    func heldReadCount() -> Int { heldReads }
    func resolve(fails: Bool) {
        resolution = fails
        let pending = waiters
        waiters = []
        for continuation in pending {
            if fails { continuation.resume(throwing: SMBError.connectionFailed) }
            else { continuation.resume() }
        }
    }
    func close() async { await provider.close() }
}

private enum EOFPlaybackError: Error { case timeout, fixtureUnavailable }

private struct EOFSMBFixture: Decodable {
    let port: Int
    let username: String
    let password: String
    let share: String
    let mediaPath: String

    static func configuration() async throws -> Self {
        guard let address = ProcessInfo.processInfo.environment["AETHERFILM_SMB_BOOTSTRAP_URL"],
              let url = URL(string: address), url.scheme == "http", url.host == "127.0.0.1" else {
            throw XCTSkip("Run the SMB fixture launcher with --bootstrap-only and generated playback fixtures.")
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw EOFPlaybackError.fixtureUnavailable }
            return try JSONDecoder().decode(Self.self, from: data)
        } catch { throw EOFPlaybackError.fixtureUnavailable }
    }
}

private struct EOFTailMetadata: Decodable {
    let fileBytes: Int64
    let tailHoldAt: Int64
    let lastVideoPTSBeforeTail: Double
    let firstHeldPTS: Double
}
