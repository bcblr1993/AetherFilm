import Foundation

public protocol SMBFileProviding: Sendable {
    func testConnection(_ connection: SMBConnection, credentials: SMBCredentials) async throws
    func listDirectory(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> [MediaItem]
    func fileSize(_ connection: SMBConnection, credentials: SMBCredentials, path: String) async throws -> Int64
    func readFile(_ connection: SMBConnection, credentials: SMBCredentials, path: String, range: Range<Int64>) async throws -> Data
}
