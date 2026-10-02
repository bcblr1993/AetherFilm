import Foundation
import FilmDomain

public struct LibrarySnapshot: Codable, Sendable {
    public var schema: Int = 1
    public var localItems: [MediaItem] = []
    public var recentItems: [MediaItem] = []
    public var connections: [SMBConnection] = []
    public var progress: [String: PlaybackProgress] = [:]
    public init() {}
}

public actor LibraryStore {
    private let url: URL
    private var state = LibrarySnapshot()
    private var isLoaded = false

    public init(url: URL) { self.url = url }

    public func load() throws -> LibrarySnapshot {
        guard !isLoaded else { return state }
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(LibrarySnapshot.self, from: data)
                guard decoded.schema == 1 else { throw FilmError.unsupportedSchema }
                state = decoded
            } catch let error as FilmError { throw error }
            catch { throw FilmError.corruptLibrary }
        }
        isLoaded = true
        return state
    }

    public func save(_ snapshot: LibrarySnapshot) throws {
        if !isLoaded { _ = try load() }
        guard snapshot.schema == 1 else { throw FilmError.unsupportedSchema }
        let data = try JSONEncoder().encode(snapshot)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        state = snapshot
    }
}
