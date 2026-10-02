import Foundation

public struct MediaItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var path: String
    public var sourceID: UUID?
    public var isDirectory: Bool
    public var size: Int64?
    public var modifiedAt: Date?
    public var bookmark: Data?

    public init(name: String, path: String, sourceID: UUID? = nil, isDirectory: Bool = false,
                size: Int64? = nil, modifiedAt: Date? = nil, bookmark: Data? = nil) {
        self.id = "\(sourceID?.uuidString ?? "local"):\(path)"
        self.name = name
        self.path = path
        self.sourceID = sourceID
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedAt = modifiedAt
        self.bookmark = bookmark
    }

    public var fileExtension: String { (name as NSString).pathExtension.lowercased() }
    public var title: String { (name as NSString).deletingPathExtension }
    public var isVideo: Bool { !isDirectory && MediaFormats.video.contains(fileExtension) }
    public var isSubtitle: Bool { !isDirectory && MediaFormats.subtitle.contains(fileExtension) }
    public var localURL: URL? { sourceID == nil ? URL(fileURLWithPath: path) : nil }
}

public enum MediaFormats {
    public static let video: Set<String> = ["mp4", "m4v", "mov", "mkv", "avi", "webm", "ts", "m2ts", "mpg", "mpeg", "wmv", "flv"]
    public static let subtitle: Set<String> = ["srt", "ass", "ssa", "vtt", "sub"]

    public static func sorted(_ items: [MediaItem]) -> [MediaItem] {
        items.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
    }
}
