import Foundation

public struct SMBConnection: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var share: String
    public var rootPath: String
    public var username: String
    public var domain: String
    public var requireEncryption: Bool

    public init(id: UUID = UUID(), name: String, host: String, port: Int = 445, share: String,
                rootPath: String = "", username: String = "", domain: String = "", requireEncryption: Bool = false) {
        self.id = id; self.name = name; self.host = host; self.port = port
        self.share = share; self.rootPath = rootPath; self.username = username; self.domain = domain
        self.requireEncryption = requireEncryption
    }

    private enum CodingKeys: String, CodingKey { case id, name, host, port, share, rootPath, username, domain, requireEncryption }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        host = try values.decode(String.self, forKey: .host)
        port = try values.decode(Int.self, forKey: .port)
        share = try values.decode(String.self, forKey: .share)
        rootPath = try values.decodeIfPresent(String.self, forKey: .rootPath) ?? ""
        username = try values.decodeIfPresent(String.self, forKey: .username) ?? ""
        domain = try values.decodeIfPresent(String.self, forKey: .domain) ?? ""
        requireEncryption = try values.decodeIfPresent(Bool.self, forKey: .requireEncryption) ?? false
    }

    public func validated() throws -> Self {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !host.contains("/"), !host.contains("@"), !host.contains(where: { $0.isWhitespace }),
              (1...65535).contains(port), !share.isEmpty,
              !share.contains("/"), !share.contains("\\"), share != ".", share != ".." else {
            throw FilmError.invalidConnection
        }
        _ = try SMBPath.normalized(rootPath)
        guard endpoint != nil else { throw FilmError.invalidConnection }
        return self
    }

    public var endpoint: URL? {
        var components = URLComponents()
        components.scheme = "smb"; components.host = host; components.port = port
        return components.url
    }
}

public struct SMBCredentials: Sendable {
    public let username: String
    public let password: String
    public let domain: String
    public init(username: String, password: String, domain: String = "") {
        self.username = username; self.password = password; self.domain = domain
    }
}

public enum SMBPath {
    public static func normalized(_ path: String) throws -> String {
        guard !path.contains("\0"), !path.contains("\\") else { throw FilmError.invalidPath }
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        guard !components.contains("..") else { throw FilmError.invalidPath }
        return components.filter { $0 != "." }.joined(separator: "/")
    }

    public static func joining(_ parent: String, _ child: String) throws -> String {
        guard !child.isEmpty, !child.contains("/"), child != ".", child != ".." else { throw FilmError.invalidPath }
        return try normalized(parent.isEmpty ? child : parent + "/" + child)
    }

    public static func isWithin(_ path: String, root: String) throws -> Bool {
        let canonical = try normalized(path), canonicalRoot = try normalized(root)
        return canonicalRoot.isEmpty || canonical == canonicalRoot || canonical.hasPrefix(canonicalRoot + "/")
    }
}

public enum FilmError: Error, LocalizedError, Sendable {
    case invalidConnection, invalidPath, invalidRange, corruptLibrary, unsupportedSchema, missingSource, missingFile

    public var errorDescription: String? {
        switch self {
        case .invalidConnection: "请检查服务器、端口和共享目录。"
        case .invalidPath: "无法访问这个目录，请重新选择片源。"
        case .invalidRange: "无法读取这段文件，请重试播放。"
        case .corruptLibrary: "观看记录文件无法读取，已保留原文件。"
        case .unsupportedSchema: "观看记录来自更新的版本，请更新应用后打开。"
        case .missingSource: "这个 NAS 片源已移除，请重新连接。"
        case .missingFile: "找不到文件，请重新导入或检查 NAS 连接。"
        }
    }
}
