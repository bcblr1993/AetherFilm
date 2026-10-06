import Foundation
import FilmDomain

public struct NASBrowseState: Codable, Equatable, Sendable {
    public var lastPath: String
    public var lastItemID: String?
    public var favoritePaths: [String]

    public init(lastPath: String = "", lastItemID: String? = nil, favoritePaths: [String] = []) {
        self.lastPath = lastPath
        self.lastItemID = lastItemID
        self.favoritePaths = favoritePaths
    }
}

public struct LibrarySnapshot: Codable, Sendable {
    public var schema: Int = 1
    public var localItems: [MediaItem] = []
    public var recentItems: [MediaItem] = []
    public var connections: [SMBConnection] = []
    public var progress: [String: PlaybackProgress] = [:]
    public var nasBrowse: [String: NASBrowseState] = [:]
    public var automaticallyPlayNext = true
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case schema, localItems, recentItems, connections, progress, nasBrowse, automaticallyPlayNext
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schema = try values.decode(Int.self, forKey: .schema)
        localItems = try values.decode([MediaItem].self, forKey: .localItems)
        recentItems = try values.decode([MediaItem].self, forKey: .recentItems)
        connections = try values.decode([SMBConnection].self, forKey: .connections)
        progress = try values.decode([String: PlaybackProgress].self, forKey: .progress)
        nasBrowse = try values.decodeIfPresent([String: NASBrowseState].self, forKey: .nasBrowse) ?? [:]
        automaticallyPlayNext = try values.decodeIfPresent(Bool.self, forKey: .automaticallyPlayNext) ?? true
    }
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
