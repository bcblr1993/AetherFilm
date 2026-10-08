import Foundation
import Observation
import FilmDomain
import FilmLibrary
import FilmSources

enum AppSection: Hashable, Identifiable {
    case local, continueWatching, smb(UUID)
    var id: String {
        switch self {
        case .local: "local"
        case .continueWatching: "continue"
        case .smb(let id): id.uuidString
        }
    }
}

@MainActor @Observable final class AppStore {
    struct PreparedPlayback: Sendable {
        let url: URL
        let sessionID: UUID
    }
    var snapshot = LibrarySnapshot()
    var section: AppSection = .local
    var currentPath = ""
    var directoryItems: [MediaItem] = []
    var isLoading = false
    var isImporting = false
    var errorMessage: String?
    var playingItem: MediaItem?
    private(set) var playbackErrorMessage: String?

    @ObservationIgnored private let library: LibraryStore
    @ObservationIgnored private let smb: any SMBFileProviding
    @ObservationIgnored private let credentialsReader: (@MainActor (SMBConnection) throws -> SMBCredentials)?
    @ObservationIgnored private var browseGeneration = UUID()
    @ObservationIgnored private var stream: SMBStreamingServer?
    @ObservationIgnored private var activeAccess: URL?
    @ObservationIgnored private var queue: [MediaItem] = []
    @ObservationIgnored private var lastSavedAt: Date = .distantPast
    @ObservationIgnored private var loaded = false
    @ObservationIgnored private var loadingTask: Task<Void, Never>?
    @ObservationIgnored private var playbackGeneration = UUID()
    @ObservationIgnored private var playbackItemID: String?
    @ObservationIgnored private var automaticWatchedInCurrentPlayback = false
    @ObservationIgnored private var playbackProgressFailed = false
    @ObservationIgnored private var persistenceTask: Task<Void, Error>?
    @ObservationIgnored private var subtitleCacheURLs: [URL] = []
    #if DEBUG
    @ObservationIgnored private var fixtureMarker: URL?
    #endif

    init(library: LibraryStore? = nil, smb: (any SMBFileProviding)? = nil,
         credentialsReader: (@MainActor (SMBConnection) throws -> SMBCredentials)? = nil) {
        self.credentialsReader = credentialsReader
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let session = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--ui-test-session=") }?
                .split(separator: "=", maxSplits: 1).last.map(String.init) ?? UUID().uuidString
            let safeSession = session.filter { $0.isLetter || $0.isNumber || $0 == "-" }
            self.library = library ?? LibraryStore(url: FileManager.default.temporaryDirectory
                .appendingPathComponent("AetherFilmUI-\(safeSession)/library.json"))
            self.smb = smb ?? UIFixtureSMBProvider()
            self.fixtureMarker = FileManager.default.temporaryDirectory.appendingPathComponent("AetherFilmUI-\(safeSession)/seeded")
        } else {
            self.library = library ?? LibraryStore(url: support.appendingPathComponent("AetherFilm/library.json"))
            self.smb = smb ?? SMBProvider()
        }
        #else
        self.library = library ?? LibraryStore(url: support.appendingPathComponent("AetherFilm/library.json"))
        self.smb = smb ?? SMBProvider()
        #endif
    }

    var localItems: [MediaItem] { MediaFormats.sorted(snapshot.localItems.filter(\.isVideo)) }
    var connections: [SMBConnection] { snapshot.connections }
    var selectedConnection: SMBConnection? {
        guard case .smb(let id) = section else { return nil }
        return connections.first { $0.id == id }
    }
    var continueItems: [MediaItem] {
        let all = snapshot.localItems + snapshot.recentItems
        var seen = Set<String>()
        return all.filter { seen.insert($0.id).inserted && progress(for: $0)?.canContinue == true }
            .sorted { (progress(for: $0)?.updatedAt ?? .distantPast) > (progress(for: $1)?.updatedAt ?? .distantPast) }
    }
    var displayItems: [MediaItem] {
        switch section {
        case .local: localItems
        case .continueWatching: continueItems
        case .smb: MediaFormats.sorted(directoryItems.filter { $0.isDirectory || $0.isVideo })
        }
    }
    func progress(for item: MediaItem) -> PlaybackProgress? { snapshot.progress[item.id] }

    var favoriteDirectories: [String] {
        guard let source = selectedConnection else { return [] }
        return (snapshot.nasBrowse[source.id.uuidString]?.favoritePaths ?? []).filter {
            (try? SMBPath.isWithin($0, root: source.rootPath)) == true
        }
    }
    var currentDirectoryIsFavorite: Bool { favoriteDirectories.contains(currentPath) }
    var lastBrowsedItemID: String? {
        guard let source = selectedConnection,
              let state = snapshot.nasBrowse[source.id.uuidString], state.lastPath == currentPath else { return nil }
        return state.lastItemID
    }

    func toggleFavoriteDirectory() async {
        guard let source = selectedConnection, !isLoading,
              (try? SMBPath.isWithin(currentPath, root: source.rootPath)) == true else { return }
        let key = source.id.uuidString
        let previous = snapshot.nasBrowse[key]
        var state = snapshot.nasBrowse[key] ?? NASBrowseState(lastPath: currentPath)
        if state.favoritePaths.contains(currentPath) { state.favoritePaths.removeAll { $0 == currentPath } }
        else { state.favoritePaths.append(currentPath) }
        snapshot.nasBrowse[key] = state
        do { try await persist() }
        catch {
            if snapshot.nasBrowse[key] == state { snapshot.nasBrowse[key] = previous }
            errorMessage = error.localizedDescription
        }
    }

    func setAutomaticallyPlayNext(_ enabled: Bool) async {
        let previous = snapshot.automaticallyPlayNext
        snapshot.automaticallyPlayNext = enabled
        do { try await persist() }
        catch { snapshot.automaticallyPlayNext = previous; errorMessage = error.localizedDescription }
    }

    func load() async {
        guard !loaded else { return }
        if let loadingTask { await loadingTask.value; return }
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                snapshot = try await library.load(); loaded = true
                #if DEBUG
                await loadUIFixturesIfRequested()
                #endif
            }
            catch { errorMessage = error.localizedDescription }
        }
        loadingTask = task
        await task.value
        loadingTask = nil
    }

    func select(_ section: AppSection) async {
        self.section = section
        browseGeneration = UUID()
        errorMessage = nil
        directoryItems = []
        if let source = selectedConnection {
            let saved = snapshot.nasBrowse[source.id.uuidString]?.lastPath
            currentPath = saved.flatMap { (try? SMBPath.isWithin($0, root: source.rootPath)) == true ? $0 : nil }
                ?? source.rootPath
        } else { currentPath = "" }
        isLoading = false
        if selectedConnection != nil { await browse(path: currentPath) }
    }

    func browse(path: String) async {
        guard let connection = selectedConnection else { return }
        let generation = UUID()
        browseGeneration = generation; isLoading = true; errorMessage = nil
        defer { if browseGeneration == generation { isLoading = false } }
        do {
            let canonical = try SMBPath.normalized(path)
            guard try SMBPath.isWithin(canonical, root: connection.rootPath) else { throw FilmError.invalidPath }
            let credentials = try credentials(for: connection)
            let entries = try await smb.listDirectory(connection, credentials: credentials, path: canonical)
            try Task.checkCancellation()
            guard browseGeneration == generation, selectedConnection?.id == connection.id else { return }
            currentPath = canonical; directoryItems = entries
            let key = connection.id.uuidString
            var state = snapshot.nasBrowse[key] ?? NASBrowseState(lastPath: canonical)
            if state.lastPath != canonical { state.lastItemID = nil }
            state.lastPath = canonical
            snapshot.nasBrowse[key] = state
            try await persist()
        } catch is CancellationError { }
        catch { if browseGeneration == generation { errorMessage = error.localizedDescription } }
    }

    func addSMB(_ draft: SMBConnectionDraft) async throws {
        guard let port = draft.portNumber else { throw FilmError.invalidConnection }
        let host = draft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let connection = try SMBConnection(name: name.isEmpty ? host : name,
            host: host, port: Int(port), share: draft.share,
            rootPath: try SMBPath.normalized(draft.directory), username: draft.username, domain: draft.domain,
            requireEncryption: draft.requireEncryption).validated()
        let credentials = SMBCredentials(username: draft.username, password: draft.password, domain: draft.domain)
        try await smb.testConnection(connection, credentials: credentials)
        try Task.checkCancellation()
        try KeychainStore.save(credentials, sourceID: connection.id)
        let before = snapshot
        snapshot.connections.append(connection)
        do { try await persist() }
        catch {
            snapshot = before
            try? KeychainStore.remove(sourceID: connection.id)
            throw error
        }
        await select(.smb(connection.id))
    }

    func importFiles(_ urls: [URL]) async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
        errorMessage = nil
        await load()
        guard loaded else { return }
        for url in urls {
            do {
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                let suffix = url.pathExtension.lowercased()
                guard MediaFormats.video.contains(suffix) || MediaFormats.subtitle.contains(suffix) else { continue }
                let originalID = "import:\(url.standardizedFileURL.absoluteString)"
                guard !snapshot.localItems.contains(where: { $0.id == originalID || $0.path == url.path }) else { continue }
                var item: MediaItem
                #if os(macOS)
                let bookmark = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
                item = MediaItem(name: url.lastPathComponent, path: url.path, bookmark: bookmark)
                #else
                let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Imports")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let destination = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(suffix)
                try await Task.detached(priority: .userInitiated) { try FileManager.default.copyItem(at: url, to: destination) }.value
                item = MediaItem(name: url.lastPathComponent, path: destination.path)
                #endif
                item.id = originalID
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                item.size = values?.fileSize.map(Int64.init); item.modifiedAt = values?.contentModificationDate
                snapshot.localItems.append(item)
            } catch { errorMessage = "无法导入「\(url.lastPathComponent)」，请检查文件权限和可用空间。" }
        }
        do { try await persist() } catch { errorMessage = error.localizedDescription }
        let importError = errorMessage
        await select(.local)
        errorMessage = importError
    }

    func play(_ item: MediaItem) async {
        if item.isDirectory { await browse(path: item.path); return }
        queue = MediaFormats.sorted(displayItems.filter(\.isVideo))
        playingItem = item
        if let source = selectedConnection, item.sourceID == source.id {
            let key = source.id.uuidString
            var state = snapshot.nasBrowse[key] ?? NASBrowseState(lastPath: currentPath)
            state.lastItemID = item.id
            snapshot.nasBrowse[key] = state
            do { try await persist() } catch { errorMessage = error.localizedDescription }
        }
    }

    func preparePlayback(_ item: MediaItem) async throws -> PreparedPlayback {
        let generation = beginPlaybackSession(for: item)
        await releasePlaybackResources()
        try Task.checkCancellation()
        guard playbackGeneration == generation else { throw CancellationError() }
        if let sourceID = item.sourceID {
            guard let connection = connections.first(where: { $0.id == sourceID }) else { throw FilmError.missingSource }
            let credentials = try credentials(for: connection)
            let size = try await smb.fileSize(connection, credentials: credentials, path: item.path)
            try Task.checkCancellation()
            guard playbackGeneration == generation else { throw CancellationError() }
            let next = SMBStreamingServer(provider: smb, connection: connection, credentials: credentials, path: item.path, size: size,
                onReadFailure: { [weak self] failure in
                    Task { @MainActor [weak self] in
                        guard let self, self.isCurrentPlayback(item, sessionID: generation) else { return }
                        self.rejectAutomaticWatched(item, sessionID: generation)
                        self.playbackErrorMessage = failure.localizedDescription
                        await self.flushProgress()
                        guard self.isCurrentPlayback(item, sessionID: generation) else { return }
                        await self.stream?.stop()
                    }
                })
            do {
                let url = try await next.start()
                try Task.checkCancellation()
                guard playbackGeneration == generation else { throw CancellationError() }
                stream = next
                return PreparedPlayback(url: url, sessionID: generation)
            } catch { await next.stop(); throw error }
        }
        var url = URL(fileURLWithPath: item.path)
        #if os(macOS)
        if let bookmark = item.bookmark {
            var stale = false
            url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
            if url.startAccessingSecurityScopedResource() { activeAccess = url }
        }
        #endif
        guard FileManager.default.fileExists(atPath: url.path) else { throw FilmError.missingFile }
        return PreparedPlayback(url: url, sessionID: generation)
    }

    func subtitleCandidates(for item: MediaItem) async throws -> [MediaItem] {
        if let sourceID = item.sourceID {
            guard let connection = connections.first(where: { $0.id == sourceID }) else { throw FilmError.missingSource }
            let path = (item.path as NSString).deletingLastPathComponent
            return try await smb.listDirectory(connection, credentials: credentials(for: connection), path: path).filter(\.isSubtitle)
        }
        return snapshot.localItems.filter(\.isSubtitle)
    }

    func subtitleURL(_ subtitle: MediaItem) async throws -> URL {
        let generation = playbackGeneration
        if let sourceID = subtitle.sourceID {
            guard let connection = connections.first(where: { $0.id == sourceID }) else { throw FilmError.missingSource }
            let credentials = try credentials(for: connection)
            let size = try await smb.fileSize(connection, credentials: credentials, path: subtitle.path)
            guard size > 0, size <= 8 * 1024 * 1024 else { throw FilmError.invalidRange }
            let data = try await smb.readFile(connection, credentials: credentials, path: subtitle.path, range: 0..<size)
            try Task.checkCancellation()
            guard playbackGeneration == generation else { throw CancellationError() }
            guard data.count == size else { throw FilmError.invalidRange }
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("AetherFilm/Subtitles")
            try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
            let url = caches.appendingPathComponent(UUID().uuidString).appendingPathExtension(subtitle.fileExtension)
            try data.write(to: url, options: .atomic)
            subtitleCacheURLs.append(url)
            return url
        }
        #if os(macOS)
        if let bookmark = subtitle.bookmark {
            var stale = false
            return try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
        }
        #endif
        return URL(fileURLWithPath: subtitle.path)
    }

    func beginPlaybackSession(for item: MediaItem) -> UUID {
        playbackGeneration = UUID()
        playbackItemID = item.id
        playbackErrorMessage = nil
        automaticWatchedInCurrentPlayback = false
        playbackProgressFailed = false
        return playbackGeneration
    }

    func beginPlaybackProgress(_ item: MediaItem, sessionID: UUID) {
        guard isCurrentPlayback(item, sessionID: sessionID) else { return }
        // A replay is a new native input. Existing watched state is its history.
        automaticWatchedInCurrentPlayback = false
        playbackProgressFailed = playbackErrorMessage != nil
    }

    func recordProgress(_ item: MediaItem, position: Double, duration: Double,
                        allowsAutomaticWatched: Bool = true, sessionID: UUID? = nil) {
        if let sessionID, !isCurrentPlayback(item, sessionID: sessionID) { return }
        guard position.isFinite, duration.isFinite, duration > 0 else { return }
        if let sourceID = item.sourceID, !connections.contains(where: { $0.id == sourceID }) { return }
        let wasWatched = snapshot.progress[item.id]?.isWatched ?? false
        let next = PlaybackProgress(itemID: item.id, position: position, duration: duration,
            isWatched: wasWatched,
            allowsAutomaticWatched: allowsAutomaticWatched && (sessionID == nil || !playbackProgressFailed))
        if sessionID != nil, !wasWatched, next.isWatched {
            automaticWatchedInCurrentPlayback = true
        }
        snapshot.progress[item.id] = next
        snapshot.recentItems.removeAll { $0.id == item.id }
        snapshot.recentItems.insert(item, at: 0)
        if snapshot.recentItems.count > 500 { snapshot.recentItems.removeLast(snapshot.recentItems.count - 500) }
        if Date().timeIntervalSince(lastSavedAt) >= 5 {
            lastSavedAt = Date()
            persistProgressInBackground()
        }
    }

    func rejectAutomaticWatched(_ item: MediaItem, sessionID: UUID) {
        guard isCurrentPlayback(item, sessionID: sessionID) else { return }
        playbackProgressFailed = true
        guard automaticWatchedInCurrentPlayback else { return }
        automaticWatchedInCurrentPlayback = false
        guard var progress = snapshot.progress[item.id] else { return }
        // Keep the real resume point. Do not rerun the automatic 95% initializer.
        progress.isWatched = false
        snapshot.progress[item.id] = progress
        persistProgressInBackground()
    }

    func flushProgress() async {
        do { try await persist() } catch { errorMessage = error.localizedDescription }
    }

    func nextItem(after item: MediaItem) -> MediaItem? {
        guard let index = queue.firstIndex(where: { $0.id == item.id }), index + 1 < queue.count else { return nil }
        return queue[index + 1]
    }

    func playbackSession(for item: MediaItem) -> UUID? {
        playbackItemID == item.id ? playbackGeneration : nil
    }

    func canCompletePlayback(after item: MediaItem, sessionID: UUID) async -> Bool {
        guard isCurrentPlayback(item, sessionID: sessionID) else { return false }
        let currentStream = stream
        let failure = await currentStream?.readFailure()
        guard isCurrentPlayback(item, sessionID: sessionID) else { return false }
        if let failure {
            rejectAutomaticWatched(item, sessionID: sessionID)
            playbackErrorMessage = failure.localizedDescription
            await flushProgress()
            return false
        }
        return playbackErrorMessage == nil
    }

    func completePlayback(after item: MediaItem, sessionID: UUID) async {
        guard await canCompletePlayback(after: item, sessionID: sessionID),
              isCurrentPlayback(item, sessionID: sessionID) else { return }
        let old = progress(for: item)
        snapshot.progress[item.id] = PlaybackProgress(itemID: item.id, position: old?.position ?? 0,
            duration: old?.duration ?? 0, isWatched: true)
        if old?.isWatched != true { automaticWatchedInCurrentPlayback = true }
        if !snapshot.recentItems.contains(where: { $0.id == item.id }) { snapshot.recentItems.append(item) }
        // Backend completion remains automatic, not an explicit user override.
        await flushProgress()
        guard await canCompletePlayback(after: item, sessionID: sessionID),
              isCurrentPlayback(item, sessionID: sessionID) else { return }
        if snapshot.automaticallyPlayNext, let next = nextItem(after: item) { playingItem = next }
    }

    private func isCurrentPlayback(_ item: MediaItem, sessionID: UUID) -> Bool {
        playbackGeneration == sessionID && playbackItemID == item.id && playingItem?.id == item.id
    }

    func playNext(after item: MediaItem) async {
        let sessionID = playbackGeneration
        guard playingItem?.id == item.id else { return }
        await flushProgress()
        guard playbackGeneration == sessionID, playingItem?.id == item.id else { return }
        if let next = nextItem(after: item) { playingItem = next }
    }

    func markWatched(_ item: MediaItem) async {
        if playbackItemID == item.id { automaticWatchedInCurrentPlayback = false }
        let old = progress(for: item)
        snapshot.progress[item.id] = PlaybackProgress(itemID: item.id, position: old?.position ?? 0,
            duration: old?.duration ?? 0, isWatched: true)
        if !snapshot.recentItems.contains(where: { $0.id == item.id }) { snapshot.recentItems.append(item) }
        await flushProgress()
    }

    func clearProgress(_ item: MediaItem) async {
        if playbackItemID == item.id { automaticWatchedInCurrentPlayback = false }
        snapshot.progress.removeValue(forKey: item.id)
        snapshot.recentItems.removeAll { $0.id == item.id }
        await flushProgress()
    }

    func removeLocalItem(_ item: MediaItem) async {
        snapshot.localItems.removeAll { $0.id == item.id }
        await clearProgress(item)
    }

    func removeConnection(_ connection: SMBConnection) async {
        do {
            let before = snapshot
            if playingItem?.sourceID == connection.id { playingItem = nil; await stopStreaming() }
            snapshot.connections.removeAll { $0.id == connection.id }
            snapshot.nasBrowse.removeValue(forKey: connection.id.uuidString)
            let sourceItemIDs = Set(snapshot.recentItems.filter { $0.sourceID == connection.id }.map(\.id))
            snapshot.recentItems.removeAll { $0.sourceID == connection.id }
            let sourcePrefix = connection.id.uuidString + ":"
            snapshot.progress = snapshot.progress.filter { !sourceItemIDs.contains($0.key) && !$0.key.hasPrefix(sourcePrefix) }
            do { try await persist() } catch { snapshot = before; throw error }
            try KeychainStore.remove(sourceID: connection.id)
            if let provider = smb as? SMBProvider { await provider.forgetConnection(connection.id) }
            if selectedConnection == nil { await select(.local) }
        } catch { errorMessage = error.localizedDescription }
    }

    func stopStreaming(for itemID: String? = nil, sessionID: UUID? = nil) async {
        guard itemID == nil || playbackItemID == itemID else { return }
        guard sessionID == nil || playbackGeneration == sessionID else { return }
        playbackGeneration = UUID()
        playbackItemID = nil
        playbackErrorMessage = nil
        automaticWatchedInCurrentPlayback = false
        playbackProgressFailed = false
        await releasePlaybackResources()
    }

    private func releasePlaybackResources() async {
        let oldStream = stream
        let oldAccess = activeAccess
        let oldSubtitles = subtitleCacheURLs
        stream = nil; activeAccess = nil
        subtitleCacheURLs = []
        oldAccess?.stopAccessingSecurityScopedResource()
        for url in oldSubtitles { try? FileManager.default.removeItem(at: url) }
        await oldStream?.stop()
    }

    private func persistProgressInBackground() {
        // Submit the real snapshot now. A later explicit flush must join this
        // write even if its background completion observer has not run yet.
        let save = enqueuePersistence()
        Task { [weak self] in
            do { try await save.value }
            catch { self?.errorMessage = error.localizedDescription }
        }
    }

    private func persist() async throws {
        try await enqueuePersistence().value
    }

    private func enqueuePersistence() -> Task<Void, Error> {
        let previous = persistenceTask
        let value = snapshot
        let next = Task { [library] in
            if let previous { _ = await previous.result }
            try await library.save(value)
        }
        persistenceTask = next
        // Preserve MainActor submission order across the library actor hop.
        // A periodic older save cannot overwrite a subsequently queued rollback.
        return next
    }

    private func credentials(for connection: SMBConnection) throws -> SMBCredentials {
        if let credentialsReader { return try credentialsReader(connection) }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"), connection.host == "fixture.invalid" {
            return SMBCredentials(username: "fixture", password: "")
        }
        #endif
        return try KeychainStore.read(sourceID: connection.id)
    }

    #if DEBUG
    private func loadUIFixturesIfRequested() async {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--ui-testing") else { return }
        if args.contains("--ui-fixtures"), let marker = fixtureMarker,
           !FileManager.default.fileExists(atPath: marker.path),
           let folder = Bundle.main.url(forResource: "UIFixtures", withExtension: nil),
           let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            snapshot.localItems = MediaFormats.sorted(urls.filter { MediaFormats.video.contains($0.pathExtension) }.map {
                MediaItem(name: $0.lastPathComponent, path: $0.path)
            })
            try? await persist()
            try? Data().write(to: marker, options: .atomic)
        }
        if args.contains("--ui-source-error") || args.contains("--ui-source-fixtures") {
            let source = SMBConnection(id: UUID(uuidString: "33CCCCCC-4444-5555-8888-AAAABBBBCCCC")!,
                name: "测试 NAS", host: "fixture.invalid", share: "Videos")
            if !snapshot.connections.contains(where: { $0.id == source.id }) { snapshot.connections.append(source) }
            // Fixture credentials contain no user secret; Keychain is bypassed by browse below.
            await select(.smb(source.id))
        }
    }
    #endif
}
