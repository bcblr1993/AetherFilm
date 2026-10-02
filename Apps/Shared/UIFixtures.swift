#if DEBUG
import Foundation
import FilmDomain

actor UIFixtureSMBProvider: SMBFileProviding {
    func testConnection(_ connection: SMBConnection, credentials: SMBCredentials) async throws {
        throw FilmError.invalidConnection
    }
    func listDirectory(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> [MediaItem] {
        try await Task.sleep(for: .milliseconds(500))
        if ProcessInfo.processInfo.arguments.contains("--ui-source-error") { throw FilmError.missingSource }
        if path == "Movies/Empty" { return [] }
        if path == "Movies" {
            return [MediaItem(name: "Empty", path: "Movies/Empty", sourceID: connection.id, isDirectory: true),
                    MediaItem(name: "Episode 01.mkv", path: "Movies/Episode 01.mkv", sourceID: connection.id)]
        }
        return [MediaItem(name: "Movies", path: "Movies", sourceID: connection.id, isDirectory: true),
                MediaItem(name: "Episode 01.mp4", path: "Episode 01.mp4", sourceID: connection.id),
                MediaItem(name: "Episode 02.mkv", path: "Episode 02.mkv", sourceID: connection.id)]
    }
    func fileSize(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> Int64 { throw FilmError.missingFile }
    func readFile(_ connection: SMBConnection, credentials: SMBCredentials, path: String, range: Range<Int64>) async throws -> Data { throw FilmError.missingFile }
}
#endif
