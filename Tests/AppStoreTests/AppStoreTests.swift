import XCTest
import FilmDomain
import FilmLibrary
import FilmSources
@testable import AetherFilm

@MainActor final class AppStoreTests: XCTestCase {
    private var directory: URL!
    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("FilmAppStoreTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDown() async throws { try? FileManager.default.removeItem(at: directory) }

    private func makeStore(smb: (any SMBFileProviding)? = nil,
                           credentialsReader: (@MainActor (SMBConnection) throws -> SMBCredentials)? = nil) -> AppStore {
        AppStore(library: LibraryStore(url: directory.appendingPathComponent("library.json")), smb: smb, credentialsReader: credentialsReader)
    }

    func testResumeAndWatchedStateSurviveReopening() async throws {
        let item = MediaItem(name: "example.mp4", path: directory.appendingPathComponent("example.mp4").path)
        let store = makeStore(); await store.load()
        store.snapshot.localItems = [item]
        store.recordProgress(item, position: 5, duration: 30)
        await store.flushProgress()
        let reopened = makeStore(); await reopened.load()
        XCTAssertEqual(reopened.progress(for: item)?.resumePosition, 5)
        XCTAssertEqual(reopened.continueItems.map(\.id), [item.id])
        await reopened.markWatched(item)
        XCTAssertTrue(reopened.continueItems.isEmpty)
        await reopened.clearProgress(item)
        XCTAssertNil(reopened.progress(for: item))
    }

    func testPausedSeekNearEndPersistsAsResumeUntilPlaybackIsConfirmed() async throws {
        let item = MediaItem(name: "short.mp4", path: directory.appendingPathComponent("short.mp4").path)
        let store = makeStore(); await store.load()
        store.snapshot.localItems = [item]
        store.recordProgress(item, position: 11.5, duration: 12, allowsAutomaticWatched: false)
        await store.flushProgress()

        let reopened = makeStore(); await reopened.load()
        XCTAssertEqual(reopened.progress(for: item)?.resumePosition, 11.5)
        XCTAssertEqual(reopened.progress(for: item)?.isWatched, false)
        XCTAssertEqual(reopened.continueItems.map(\.id), [item.id])

        reopened.recordProgress(item, position: 11.5, duration: 12, allowsAutomaticWatched: true)
        await reopened.flushProgress()
        let completed = makeStore(); await completed.load()
        XCTAssertEqual(completed.progress(for: item)?.isWatched, true)
        XCTAssertTrue(completed.continueItems.isEmpty)
        completed.recordProgress(item, position: 11, duration: 12, allowsAutomaticWatched: false)
        await completed.flushProgress()
        let stillCompleted = makeStore(); await stillCompleted.load()
        XCTAssertEqual(stillCompleted.progress(for: item)?.isWatched, true,
                       "An unconfirmed seek must preserve a previously confirmed watched state.")
    }

    func testRemovingNASRemovesOrphanedResumeEntries() async throws {
        let store = makeStore(); await store.load()
        let source = SMBConnection(name: "Fixture", host: "fixture.invalid", share: "Videos")
        let item = MediaItem(name: "video.mkv", path: "video.mkv", sourceID: source.id)
        let olderItem = MediaItem(name: "older.mkv", path: "older.mkv", sourceID: source.id)
        store.snapshot.connections = [source]
        store.recordProgress(item, position: 5, duration: 30)
        store.snapshot.progress[olderItem.id] = PlaybackProgress(itemID: olderItem.id, position: 5, duration: 30)
        await store.flushProgress()
        await store.removeConnection(source)
        XCTAssertTrue(store.connections.isEmpty)
        XCTAssertTrue(store.continueItems.isEmpty)
        XCTAssertNil(store.progress(for: olderItem), "Source removal also clears progress evicted from recent history.")
        store.recordProgress(item, position: 10, duration: 30)
        XCTAssertNil(store.progress(for: item))
    }

    func testRemovingLocalItemPreservesOriginalFile() async throws {
        let file = directory.appendingPathComponent("mine.mp4")
        let content = Data("owned video fixture".utf8)
        try content.write(to: file)
        let item = MediaItem(name: file.lastPathComponent, path: file.path)
        let store = makeStore(); await store.load(); store.snapshot.localItems = [item]
        await store.removeLocalItem(item)
        XCTAssertTrue(store.localItems.isEmpty)
        XCTAssertEqual(try Data(contentsOf: file), content)
    }

    func testColdLaunchAndOpenFileShareOneLibraryLoad() async throws {
        let file = directory.appendingPathComponent("打开 中文 video.mp4")
        let content = Data("owned cold-open fixture".utf8)
        try content.write(to: file)
        let store = makeStore()
        async let launch: Void = store.load()
        async let incomingFile: Void = store.importFiles([file])
        _ = await (launch, incomingFile)
        XCTAssertEqual(store.localItems.map(\.name), [file.lastPathComponent])
        let reopened = makeStore(); await reopened.load()
        XCTAssertEqual(reopened.localItems.map(\.name), [file.lastPathComponent])
        XCTAssertEqual(try Data(contentsOf: file), content)
    }

    func testManualNextDoesNotMarkAnUnfinishedVideoWatched() async throws {
        let store = makeStore(); await store.load()
        let first = MediaItem(name: "episode1.mp4", path: "/fixture/episode1.mp4")
        let second = MediaItem(name: "episode2.mp4", path: "/fixture/episode2.mp4")
        store.snapshot.localItems = [second, first]
        await store.play(first)
        store.recordProgress(first, position: 2, duration: 30)
        await store.playNext(after: first)
        XCTAssertEqual(store.playingItem?.id, second.id)
        XCTAssertEqual(store.progress(for: first)?.isWatched, false)
    }

    func testOldCompletionAfterReopeningSameItemCannotMarkWatchedOrAdvance() async throws {
        let store = makeStore(); await store.load()
        let first = MediaItem(name: "episode1.mp4", path: directory.appendingPathComponent("episode1.mp4").path)
        let second = MediaItem(name: "episode2.mp4", path: directory.appendingPathComponent("episode2.mp4").path)
        try Data("owned session fixture".utf8).write(to: URL(fileURLWithPath: first.path))
        store.snapshot.localItems = [second, first]
        await store.play(first)
        _ = try await store.preparePlayback(first)
        let oldSession = try XCTUnwrap(store.playbackSession(for: first))
        await store.stopStreaming(for: first.id)
        _ = try await store.preparePlayback(first)
        let newSession = try XCTUnwrap(store.playbackSession(for: first))
        XCTAssertNotEqual(oldSession, newSession)
        await store.stopStreaming(for: first.id, sessionID: oldSession)
        XCTAssertEqual(store.playbackSession(for: first), newSession)
        store.recordProgress(first, position: 2, duration: 30)

        await store.completePlayback(after: first, sessionID: oldSession)
        XCTAssertEqual(store.playingItem?.id, first.id)
        XCTAssertEqual(store.progress(for: first)?.isWatched, false)

        await store.completePlayback(after: first, sessionID: newSession)
        XCTAssertEqual(store.playingItem?.id, second.id)
        XCTAssertEqual(store.progress(for: first)?.isWatched, true)
        let reopened = makeStore(); await reopened.load()
        XCTAssertEqual(reopened.progress(for: first)?.isWatched, true)
        await store.stopStreaming()
    }

    func testNASReadFailurePreventsCompletionAndRetryCreatesCleanSession() async throws {
        let source = SMBConnection(name: "Isolated failing source", host: "fixture.invalid", share: "Videos")
        let provider = CompletionFailureProvider()
        let store = makeStore(smb: provider, credentialsReader: { _ in SMBCredentials(username: "fixture", password: "") })
        await store.load()
        let first = MediaItem(name: "episode1.mp4", path: "episode1.mp4", sourceID: source.id)
        let second = MediaItem(name: "episode2.mp4", path: "episode2.mp4", sourceID: source.id)
        store.snapshot.connections = [source]
        store.directoryItems = [first, second]
        store.section = .smb(source.id)
        await store.play(first)
        let prepared = try await store.preparePlayback(first)
        let failedSession = try XCTUnwrap(store.playbackSession(for: first))
        store.recordProgress(first, position: 2, duration: 30)
        do {
            _ = try await URLSession.shared.data(from: prepared.url)
            XCTFail("A source read failure cannot fulfill the advertised HTTP body.")
        } catch { }
        await store.completePlayback(after: first, sessionID: failedSession)
        XCTAssertEqual(store.playingItem?.id, first.id)
        XCTAssertEqual(store.progress(for: first)?.isWatched, false)
        XCTAssertEqual(store.playbackErrorMessage, SMBError.connectionFailed.localizedDescription)

        await provider.allowReads()
        let retry = try await store.preparePlayback(first)
        let retrySession = try XCTUnwrap(store.playbackSession(for: first))
        XCTAssertNotEqual(failedSession, retrySession)
        XCTAssertNil(store.playbackErrorMessage)
        let (data, _) = try await URLSession.shared.data(from: retry.url)
        XCTAssertEqual(data.count, 16)
        await store.completePlayback(after: first, sessionID: failedSession)
        XCTAssertEqual(store.playingItem?.id, first.id)
        await store.completePlayback(after: first, sessionID: retrySession)
        XCTAssertEqual(store.playingItem?.id, second.id)
        XCTAssertEqual(store.progress(for: first)?.isWatched, true)
        await store.stopStreaming()
    }
}

private actor CompletionFailureProvider: SMBFileProviding {
    private var fails = true
    func allowReads() { fails = false }
    func testConnection(_ connection: SMBConnection, credentials: SMBCredentials) async throws { }
    func listDirectory(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> [MediaItem] { [] }
    func fileSize(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> Int64 { 16 }
    func readFile(_ connection: SMBConnection, credentials: SMBCredentials, path: String, range: Range<Int64>) async throws -> Data {
        if fails { throw SMBError.connectionFailed }
        return Data(repeating: 0, count: Int(range.count))
    }
}
