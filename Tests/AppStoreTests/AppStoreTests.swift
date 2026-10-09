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

    func testNASDirectoriesAndLastOpenedRowRestoreAndStayInsideRoot() async throws {
        let source = SMBConnection(name: "Test NAS", host: "fixture.invalid", share: "Videos", rootPath: "Movies")
        let provider = BrowseStateProvider()
        let credentials: @MainActor (SMBConnection) throws -> SMBCredentials = { _ in
            SMBCredentials(username: "fixture", password: "")
        }
        let store = makeStore(smb: provider, credentialsReader: credentials)
        await store.load(); store.snapshot.connections = [source]
        await store.select(.smb(source.id))
        await store.browse(path: "Movies/中文 剧集")
        await store.toggleFavoriteDirectory()
        let item = try XCTUnwrap(store.displayItems.first)
        await store.play(item)
        await store.select(.local)
        await store.select(.smb(source.id))
        XCTAssertEqual(store.currentPath, "Movies/中文 剧集")
        XCTAssertEqual(store.lastBrowsedItemID, item.id)
        XCTAssertEqual(store.favoriteDirectories, ["Movies/中文 剧集"])

        let reopened = makeStore(smb: provider, credentialsReader: credentials)
        await reopened.load(); await reopened.select(.smb(source.id))
        XCTAssertEqual(reopened.currentPath, "Movies/中文 剧集")
        XCTAssertEqual(reopened.lastBrowsedItemID, item.id)
        await reopened.toggleFavoriteDirectory()
        XCTAssertTrue(reopened.favoriteDirectories.isEmpty)
        reopened.snapshot.nasBrowse[source.id.uuidString] = NASBrowseState(lastPath: "Other", favoritePaths: ["Other"])
        await reopened.select(.smb(source.id))
        XCTAssertEqual(reopened.currentPath, "Movies")
        XCTAssertTrue(reopened.favoriteDirectories.isEmpty)
        await reopened.removeConnection(source)
        XCTAssertNil(reopened.snapshot.nasBrowse[source.id.uuidString])
    }

    func testAutoplayOffPersistsCompletionAndManualNextStillWorks() async throws {
        let store = makeStore(); await store.load()
        let first = MediaItem(name: "episode1.mp4", path: "owned-first")
        let second = MediaItem(name: "episode2.mp4", path: "owned-second")
        store.snapshot.localItems = [second, first]
        await store.setAutomaticallyPlayNext(false)
        await store.play(first)
        let session = store.beginPlaybackSession(for: first)
        await store.completePlayback(after: first, sessionID: session)
        XCTAssertEqual(store.playingItem?.id, first.id)
        XCTAssertEqual(store.progress(for: first)?.isWatched, true)
        let reopened = makeStore(); await reopened.load()
        XCTAssertFalse(reopened.snapshot.automaticallyPlayNext)
        XCTAssertEqual(reopened.progress(for: first)?.isWatched, true)
        await store.playNext(after: first)
        XCTAssertEqual(store.playingItem?.id, second.id)
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

    func testHealthyAutomaticWatchedSessionPersistsBeforeCompletion() async throws {
        let item = MediaItem(name: "short.mp4", path: "fixture-only")
        let store = makeStore(); await store.load(); store.playingItem = item
        let session = store.beginPlaybackSession(for: item)
        store.recordProgress(item, position: 11.5, duration: 12, sessionID: session)
        await store.flushProgress()
        let saved = try await LibraryStore(url: directory.appendingPathComponent("library.json")).load()
        XCTAssertTrue(try XCTUnwrap(saved.progress[item.id]).isWatched)
        XCTAssertEqual(saved.progress[item.id]?.position, 11.5)
    }

    func testFailedSessionRetractsAutomaticWatchedButRetainsResume() async throws {
        let item = MediaItem(name: "short.mp4", path: "fixture-only")
        let store = makeStore(); await store.load(); store.playingItem = item
        let session = store.beginPlaybackSession(for: item)
        store.recordProgress(item, position: 11.5, duration: 12, sessionID: session)
        await store.flushProgress()
        let before = try await LibraryStore(url: directory.appendingPathComponent("library.json")).load()
        XCTAssertTrue(try XCTUnwrap(before.progress[item.id]).isWatched)
        let olderSave = Task { await store.flushProgress() }
        store.rejectAutomaticWatched(item, sessionID: session)
        store.recordProgress(item, position: 11.6, duration: 12, sessionID: session)
        await store.flushProgress(); await olderSave.value
        let saved = try await LibraryStore(url: directory.appendingPathComponent("library.json")).load()
        XCTAssertFalse(try XCTUnwrap(saved.progress[item.id]).isWatched)
        XCTAssertEqual(saved.progress[item.id]?.resumePosition, 11.6)
    }

    func testPriorWatchedHistorySurvivesNewSessionFailure() async throws {
        let item = MediaItem(name: "short.mp4", path: "fixture-only")
        let initial = makeStore(); await initial.load(); await initial.markWatched(item)
        let store = makeStore(); await store.load(); store.playingItem = item
        let session = store.beginPlaybackSession(for: item)
        store.recordProgress(item, position: 11.5, duration: 12, sessionID: session)
        store.rejectAutomaticWatched(item, sessionID: session)
        await store.flushProgress()
        let saved = try await LibraryStore(url: directory.appendingPathComponent("library.json")).load()
        XCTAssertTrue(try XCTUnwrap(saved.progress[item.id]).isWatched)
    }

    func testManualMarkAfterAutomaticWatchedSurvivesSessionFailure() async throws {
        let item = MediaItem(name: "short.mp4", path: "fixture-only")
        let store = makeStore(); await store.load(); store.playingItem = item
        let session = store.beginPlaybackSession(for: item)
        store.recordProgress(item, position: 11.5, duration: 12, sessionID: session)
        await store.markWatched(item)
        store.rejectAutomaticWatched(item, sessionID: session)
        store.recordProgress(item, position: 11.6, duration: 12, sessionID: session)
        await store.flushProgress()
        let saved = try await LibraryStore(url: directory.appendingPathComponent("library.json")).load()
        XCTAssertTrue(try XCTUnwrap(saved.progress[item.id]).isWatched)
    }

    func testStoppedSessionFailureCannotRetractNewSessionWatched() async throws {
        let item = MediaItem(name: "short.mp4", path: "fixture-only")
        let store = makeStore(); await store.load(); store.playingItem = item
        let oldSession = store.beginPlaybackSession(for: item)
        store.recordProgress(item, position: 5, duration: 12, sessionID: oldSession)
        await store.stopStreaming(for: item.id, sessionID: oldSession)
        let newSession = store.beginPlaybackSession(for: item)
        store.recordProgress(item, position: 11.5, duration: 12, sessionID: newSession)
        store.rejectAutomaticWatched(item, sessionID: oldSession)
        store.recordProgress(item, position: 1, duration: 12, sessionID: oldSession)
        await store.flushProgress()
        let saved = try await LibraryStore(url: directory.appendingPathComponent("library.json")).load()
        XCTAssertTrue(try XCTUnwrap(saved.progress[item.id]).isWatched)
        XCTAssertEqual(saved.progress[item.id]?.position, 11.5)
        store.rejectAutomaticWatched(item, sessionID: newSession)
        XCTAssertFalse(try XCTUnwrap(store.progress(for: item)).isWatched)
    }

    func testClearedProgressDoesNotRestoreSessionAutomaticWatchedAfterFailure() async throws {
        let item = MediaItem(name: "short.mp4", path: "fixture-only")
        let store = makeStore(); await store.load(); store.playingItem = item
        let session = store.beginPlaybackSession(for: item)
        store.recordProgress(item, position: 11.5, duration: 12, sessionID: session)
        await store.clearProgress(item)
        store.rejectAutomaticWatched(item, sessionID: session)
        store.recordProgress(item, position: 11.6, duration: 12, sessionID: session)
        await store.flushProgress()
        let saved = try await LibraryStore(url: directory.appendingPathComponent("library.json")).load()
        XCTAssertFalse(try XCTUnwrap(saved.progress[item.id]).isWatched)
        XCTAssertEqual(saved.progress[item.id]?.position, 11.6)
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

    #if os(macOS)
    func testReadonlyLocalImportBookmarkSurvivesReopening() async throws {
        let file = directory.appendingPathComponent("只读 中文 video.mp4")
        let content = Data("owned readonly import fixture".utf8)
        try content.write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: file.path)
        let store = makeStore()
        await store.importFiles([file])
        XCTAssertNil(store.errorMessage)
        XCTAssertNotNil(try XCTUnwrap(store.localItems.first).bookmark)
        await store.importFiles([file])
        XCTAssertEqual(store.localItems.count, 1)
        let reopened = makeStore()
        await reopened.load()
        let item = try XCTUnwrap(reopened.localItems.first)
        let prepared = try await reopened.preparePlayback(item)
        XCTAssertEqual(try Data(contentsOf: prepared.url), content)
        XCTAssertEqual(prepared.url.standardizedFileURL, file.standardizedFileURL)
        XCTAssertEqual(try Data(contentsOf: file), content)
    }
    #endif

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

private actor BrowseStateProvider: SMBFileProviding {
    func testConnection(_ connection: SMBConnection, credentials: SMBCredentials) async throws { }
    func listDirectory(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> [MediaItem] {
        [MediaItem(name: "Episode 02.mp4", path: try SMBPath.joining(path, "Episode 02.mp4"), sourceID: connection.id)]
    }
    func fileSize(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> Int64 { 0 }
    func readFile(_ connection: SMBConnection, credentials: SMBCredentials, path: String, range: Range<Int64>) async throws -> Data { Data() }
}
