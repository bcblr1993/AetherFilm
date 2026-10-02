import Foundation

public struct PlayerTrack: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct PlayerChapter: Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let time: Double?

    public init(id: Int, name: String, time: Double?) {
        self.id = id
        self.name = name
        self.time = time
    }
}
