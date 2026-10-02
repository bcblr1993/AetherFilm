import Foundation
import Security
import FilmDomain

enum KeychainStore {
    private struct Secret: Codable { var username: String; var password: String; var domain: String }
    private static let service = "com.aethernative.AetherFilm.smb"

    static func save(_ credentials: SMBCredentials, sourceID: UUID) throws {
        let data = try JSONEncoder().encode(Secret(username: credentials.username, password: credentials.password, domain: credentials.domain))
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecAttrAccount as String: sourceID.uuidString]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var addition = query
            addition[kSecValueData as String] = data
            addition[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(addition as CFDictionary, nil) == errSecSuccess else { throw KeychainError.unavailable }
        } else if status != errSecSuccess { throw KeychainError.unavailable }
    }

    static func read(sourceID: UUID) throws -> SMBCredentials {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecAttrAccount as String: sourceID.uuidString,
                                   kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let secret = try? JSONDecoder().decode(Secret.self, from: data) else { throw KeychainError.missing }
        return SMBCredentials(username: secret.username, password: secret.password, domain: secret.domain)
    }

    static func remove(sourceID: UUID) throws {
        let status = SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecAttrAccount as String: sourceID.uuidString] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unavailable }
    }

    private enum KeychainError: LocalizedError {
        case missing, unavailable
        var errorDescription: String? {
            switch self {
            case .missing: "无法读取 NAS 密码，请重新连接这个片源。"
            case .unavailable: "无法保存到系统钥匙串，请解锁设备后重试。"
            }
        }
    }
}
