import Foundation
import Testing
@testable import FilmDomain

@Suite struct FilmDomainTests {
    @Test func identitiesIncludeSourceAndPreserveChinesePaths() {
        let source = UUID()
        let first = MediaItem(name: "电影 01.mkv", path: "剧集/电影 01.mkv", sourceID: source)
        let same = MediaItem(name: "显示名称.mkv", path: "剧集/电影 01.mkv", sourceID: source)
        let other = MediaItem(name: first.name, path: first.path, sourceID: UUID())
        #expect(first.id == same.id)
        #expect(first.id != other.id)
        #expect(first.isVideo && first.title == "电影 01")
        #expect(first.localURL == nil)
    }

    @Test func directoriesSortFirstAndEpisodesSortNaturally() {
        let items = ["episode10.mkv", "episode2.mkv", "episode1.mkv"].map { MediaItem(name: $0, path: $0) }
        let folder = MediaItem(name: "Z", path: "Z", isDirectory: true)
        #expect(MediaFormats.sorted(items + [folder]).map(\.name) == ["Z", "episode1.mkv", "episode2.mkv", "episode10.mkv"])
        #expect(!folder.isVideo)
        #expect(MediaItem(name: "中文.ASS", path: "中文.ASS").isSubtitle)
    }

    @Test func progressClampsInvalidAndOutOfBoundsValues() {
        for value in [Double.nan, .infinity, -.infinity, -50] {
            let progress = PlaybackProgress(itemID: "a", position: value, duration: value)
            #expect(progress.position == 0 && progress.duration == 0 && progress.fraction == 0)
            #expect(!progress.canContinue)
        }
        let clamped = PlaybackProgress(itemID: "a", position: 900, duration: 100)
        #expect(clamped.position == 100 && clamped.isWatched && clamped.resumePosition == 0)
    }

    @Test func shortVideosRemainResumableBeforeCompletion() {
        let halfway = PlaybackProgress(itemID: "a", position: 5, duration: 10)
        #expect(halfway.canContinue && !halfway.isWatched && halfway.resumePosition == 5)
        #expect(PlaybackProgress(itemID: "a", position: 9.5, duration: 10).isWatched)
        #expect(!PlaybackProgress(itemID: "a", position: 0, duration: 10).canContinue)
    }

    @Test func relativePathNormalizationDoesNotDecodeLiteralNames() throws {
        #expect(try SMBPath.normalized("//电影/./第一集.mkv/") == "电影/第一集.mkv")
        #expect(try SMBPath.normalized("literal%2Fname.mkv") == "literal%2Fname.mkv")
        #expect(try SMBPath.joining("电影", "100% #1.mkv") == "电影/100% #1.mkv")
        for path in ["../movie", "a/../b", "a\\b", "a\0b"] {
            #expect(throws: FilmError.self) { try SMBPath.normalized(path) }
        }
    }

    @Test func directoryBoundaryIsNotAStringPrefix() throws {
        #expect(try SMBPath.isWithin("Movies/a.mkv", root: "Movies"))
        #expect(try SMBPath.isWithin("Movies", root: "Movies"))
        #expect(try !SMBPath.isWithin("MoviesElsewhere/a.mkv", root: "Movies"))
        #expect(try !SMBPath.isWithin("Movie", root: "Movies"))
    }

    @Test func connectionConfigurationCannotContainURLCredentials() throws {
        let connection = SMBConnection(name: "Home", host: "nas.local", share: "Video", username: "viewer")
        #expect(try connection.validated().endpoint?.user == nil)
        let json = String(decoding: try JSONEncoder().encode(connection), as: UTF8.self)
        #expect(!json.contains("password"))
        for host in ["smb://nas", "user@nas", "nas/a", "bad host"] {
            #expect(throws: FilmError.self) { try SMBConnection(name: "", host: host, share: "video").validated() }
        }
        #expect(throws: FilmError.self) { try SMBConnection(name: "", host: "nas", port: 0, share: "video").validated() }
    }

    @Test func rangesMatchHTTPSeekSemantics() throws {
        #expect(try ByteRange(header: nil, size: 100).length == 100)
        #expect(try ByteRange(header: "bytes=10-19", size: 100).length == 10)
        #expect(try ByteRange(header: "bytes=90-", size: 100).upperBound == 99)
        #expect(try ByteRange(header: "bytes=-20", size: 100).lowerBound == 80)
        #expect(try ByteRange(header: "bytes=-200", size: 100).length == 100)
        #expect(try ByteRange(header: "bytes=90-999", size: 100).length == 10)
        for header in ["bytes=100-", "bytes=10-9", "bytes=-0", "bytes=0-1,5-6", "bytes=a-b", "items=0-1", "bytes=0-9223372036854775808"] {
            #expect(throws: FilmError.self) { try ByteRange(header: header, size: 100) }
        }
        #expect(throws: FilmError.self) { try ByteRange(header: nil, size: 0) }
    }
}
