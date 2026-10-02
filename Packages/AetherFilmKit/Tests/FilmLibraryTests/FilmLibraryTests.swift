import Foundation
import Testing
import FilmDomain
@testable import FilmLibrary

@Suite struct FilmLibraryTests {
    private func location() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AetherFilmTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("library.json")
    }

    @Test func roundTripRetainsSourcesBookmarksAndProgressWithoutSecrets() async throws {
        let url = try location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = LibraryStore(url: url)
        var state = try await store.load()
        let local = MediaItem(name: "电影.mkv", path: "/a/电影.mkv", bookmark: Data([1, 2, 3]))
        let source = SMBConnection(name: "NAS", host: "nas.local", share: "Movies", username: "viewer")
        state.localItems = [local]; state.connections = [source]
        state.progress[local.id] = PlaybackProgress(itemID: local.id, position: 42, duration: 100)
        try await store.save(state)
        let restored = try await LibraryStore(url: url).load()
        #expect(restored.localItems == [local])
        #expect(restored.connections == [source])
        #expect(restored.progress[local.id]?.resumePosition == 42)
        #expect(!String(decoding: try Data(contentsOf: url), as: UTF8.self).contains("password"))
    }

    @Test func corruptedLibraryIsPreservedAndRefusesAnOverwrite() async throws {
        let url = try location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let bytes = Data("{ corrupt user library".utf8)
        try bytes.write(to: url)
        let store = LibraryStore(url: url)
        await #expect(throws: FilmError.self) { try await store.load() }
        await #expect(throws: FilmError.self) { try await store.save(LibrarySnapshot()) }
        #expect(try Data(contentsOf: url) == bytes)
    }

    @Test func futureSchemaIsPreserved() async throws {
        let url = try location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var future = LibrarySnapshot(); future.schema = 99
        let bytes = try JSONEncoder().encode(future)
        try bytes.write(to: url)
        let store = LibraryStore(url: url)
        await #expect(throws: FilmError.self) { try await store.load() }
        #expect(try Data(contentsOf: url) == bytes)
    }

    @Test func removingLibraryEntryDoesNotDeleteTheVideo() async throws {
        let url = try location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let video = url.deletingLastPathComponent().appendingPathComponent("my-video.mp4")
        try Data("user video".utf8).write(to: video)
        let store = LibraryStore(url: url)
        var state = try await store.load()
        state.localItems = [MediaItem(name: video.lastPathComponent, path: video.path)]
        try await store.save(state)
        state.localItems.removeAll()
        try await store.save(state)
        #expect(try Data(contentsOf: video) == Data("user video".utf8))
    }
}
