import Foundation

public struct PlaybackProgress: Codable, Hashable, Sendable {
    public let itemID: String
    public var position: Double
    public var duration: Double
    public var updatedAt: Date
    public var isWatched: Bool

    public init(itemID: String, position: Double, duration: Double, updatedAt: Date = Date(), isWatched: Bool = false) {
        self.itemID = itemID
        self.duration = duration.isFinite ? max(0, duration) : 0
        self.position = position.isFinite ? max(0, position) : 0
        if self.duration > 0 { self.position = min(self.position, self.duration) }
        self.updatedAt = updatedAt
        self.isWatched = isWatched || (self.duration > 0 && self.position / self.duration >= 0.95)
    }

    public var fraction: Double { duration > 0 ? min(1, max(0, position / duration)) : 0 }
    public var resumePosition: Double { isWatched ? 0 : position }
    public var canContinue: Bool { !isWatched && position > 0 && (duration == 0 || position < duration) }
}

public struct ByteRange: Equatable, Sendable {
    public let lowerBound: Int64
    public let upperBound: Int64
    public var length: Int64 { upperBound - lowerBound + 1 }

    public init(header: String?, size: Int64) throws {
        guard size > 0 else { throw FilmError.invalidRange }
        guard let header else { lowerBound = 0; upperBound = size - 1; return }
        guard header.hasPrefix("bytes="), !header.contains(",") else { throw FilmError.invalidRange }
        let parts = header.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw FilmError.invalidRange }
        if parts[0].isEmpty {
            guard let suffix = Int64(parts[1]), suffix > 0 else { throw FilmError.invalidRange }
            lowerBound = max(0, size - suffix); upperBound = size - 1
        } else {
            guard let start = Int64(parts[0]), start >= 0, start < size else { throw FilmError.invalidRange }
            let end: Int64
            if parts[1].isEmpty { end = size - 1 }
            else {
                guard let parsed = Int64(parts[1]), parsed >= start else { throw FilmError.invalidRange }
                end = min(parsed, size - 1)
            }
            lowerBound = start; upperBound = end
        }
    }
}
