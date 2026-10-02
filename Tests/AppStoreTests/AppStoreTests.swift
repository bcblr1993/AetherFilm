import XCTest
import FilmDomain
import FilmLibrary
@testable import AetherFilm

@MainActor final class AppStoreTests: XCTestCase {
    private var directory: URL!
    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("FilmAppStoreTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDown() async throws { try? FileManager.default.removeItem(at: directory) }

    private func makeStore() -> AppStore {
        AppStore(library: LibraryStore(url: directory.appendingPathComponent("library.json")))
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
        await store.playNext(after: first, markCompleted: true)
        XCTAssertEqual(store.progress(for: first)?.isWatched, true)
    }
}
