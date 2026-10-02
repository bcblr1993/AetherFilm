import Foundation
import Observation
import FilmDomain
import VLCKit
#if os(iOS)
import AVFAudio
#endif

/// The application owns one player. Every opened film gets a fresh VLC session,
/// so delayed callbacks from a previous film cannot change the current film.
@MainActor @Observable
public final class FilmPlayer: NSObject {
    public private(set) var position: Double = 0
    public private(set) var duration: Double = 0
    public private(set) var isPlaying = false
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public private(set) var subtitleErrorMessage: String?
    public private(set) var rate: Float = 1
    public private(set) var volume: Float = 1
    public private(set) var isSeekable = false
    public private(set) var audioTracks: [PlayerTrack] = []
    public private(set) var subtitleTracks: [PlayerTrack] = []
    public private(set) var selectedAudioID: String?
    public private(set) var selectedSubtitleID: String?
    public private(set) var chapters: [PlayerChapter] = []
    public private(set) var subtitleDelay: Double = 0
    public private(set) var subtitleScale: Float = 1
    public private(set) var fillsScreen = false

    @ObservationIgnored public var onProgress: (@MainActor (Double, Double) -> Void)?
    @ObservationIgnored public var onEnded: (@MainActor () -> Void)?
    @ObservationIgnored private var engine: VLCMediaPlayer?
    @ObservationIgnored private var events: PlayerEvents?
    @ObservationIgnored private var sessionID = UUID()
    @ObservationIgnored private weak var drawable: AnyObject?
    @ObservationIgnored private var scopedURLs: [URL] = []
    @ObservationIgnored private var pendingSeek: Double?
    @ObservationIgnored private var wantsToPlay = false
    @ObservationIgnored private var backendIsLoading = false
    @ObservationIgnored private var didStart = false
    @ObservationIgnored private var didEnd = false
    @ObservationIgnored private var openingTimeout: Task<Void, Never>?
    @ObservationIgnored private var subtitleLoadingTask: Task<Void, Never>?
    @ObservationIgnored private var preferredAudioLanguage: String?
    @ObservationIgnored private var preferredSubtitleLanguage: String?
    @ObservationIgnored var capturesDecoderEvidence = false
    @ObservationIgnored private(set) var videoToolboxSelected = false
    @ObservationIgnored private(set) var videoToolboxAcceptedFrame = false
    #if os(iOS)
    @ObservationIgnored private let audioSessionCoordinator: AudioSessionCoordinator
    @ObservationIgnored private let audioSessionOwner = UUID()
    @ObservationIgnored private var pendingAudioActivation: UUID?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var routeObserver: NSObjectProtocol?
    @ObservationIgnored private var resumesAfterInterruption = false
    #endif

    public override init() {
        #if os(iOS)
        audioSessionCoordinator = .shared
        #endif
        super.init()
        #if os(iOS)
        observeAudioSession()
        #endif
    }

    #if os(iOS)
    init(audioSessionCoordinator: AudioSessionCoordinator) {
        self.audioSessionCoordinator = audioSessionCoordinator
        super.init()
        observeAudioSession()
    }
    #endif

    isolated deinit {
        openingTimeout?.cancel()
        subtitleLoadingTask?.cancel()
        engine?.delegate = nil
        engine?.stop()
        engine?.drawable = nil
        for url in scopedURLs { url.stopAccessingSecurityScopedResource() }
        #if os(iOS)
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }
        pendingAudioActivation = nil
        audioSessionCoordinator.deactivate(owner: audioSessionOwner)
        #endif
    }

    // Read by integration tests to prove decoding and output, rather than
    // treating a moving progress slider as playback acceptance.
    var decodedVideoFrames: UInt64 { engine?.media?.statistics.decodedVideo ?? 0 }
    var displayedVideoFrames: UInt64 { engine?.media?.statistics.displayedPictures ?? 0 }
    var decodedAudioBuffers: UInt64 { engine?.media?.statistics.decodedAudio ?? 0 }
    var playedAudioBuffers: UInt64 { engine?.media?.statistics.playedAudioBuffers ?? 0 }
    // Read-only test diagnostics. VLC's time is its cached/interpolated clock,
    // so it must be evaluated together with actual decoded/output counts.
    var backendState: String {
        guard let engine else { return "none" }
        switch engine.state {
        case .nothingSpecial: return "nothingSpecial"
        case .opening: return "opening"
        case .playing: return "playing"
        case .paused: return "paused"
        case .stopping: return "stopping"
        case .stopped: return "stopped"
        case .error: return "error"
        @unknown default: return "unknown(\(engine.state.rawValue))"
        }
    }
    var backendIsPlaying: Bool? { engine?.isPlaying }
    var backendTime: Double? {
        guard let milliseconds = engine?.time.value?.doubleValue else { return nil }
        return milliseconds / 1_000
    }
    var appliedVolume: Float? { engine?.audio.map { Float($0.volume) / 100 } }
    var backendSubtitleTracks: [PlayerTrack] {
        engine?.textTracks.map { PlayerTrack(id: $0.trackId, name: $0.trackName) } ?? []
    }
    var backendChapterID: Int? { engine.map { Int($0.currentChapterIndex) } }

    #if DEBUG
    // Isolated probe only: capture one actual paused callback and release it
    // through the same delegate Task after real playback has resumed.
    @ObservationIgnored private(set) var debugPausedCallbacksReceived = 0
    func debugHoldNextPausedCallback() { events?.debugHoldNextPausedCallback() }
    var debugHasHeldPausedCallback: Bool { events?.debugHasHeldPausedCallback ?? false }
    func debugReleaseHeldPausedCallback() { events?.debugReleaseHeldPausedCallback() }
    #endif

    public func load(url: URL, startAt: Double = 0) {
        stop()
        errorMessage = nil
        subtitleErrorMessage = nil
        position = 0
        duration = 0
        audioTracks = []
        subtitleTracks = []
        selectedAudioID = nil
        selectedSubtitleID = nil
        chapters = []
        pendingSeek = startAt.isFinite && startAt > 0 ? startAt : nil
        wantsToPlay = true
        didStart = false
        didEnd = false
        backendIsLoading = true
        refreshLoading()
        isSeekable = false
        videoToolboxSelected = false
        videoToolboxAcceptedFrame = false

        guard ["file", "http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            fail("无法打开这个视频地址。")
            return
        }
        retainSecurityScope(for: url)
        guard let media = VLCMedia(url: url) else {
            fail("无法打开这个视频文件。")
            return
        }
        if let language = preferredAudioLanguage { media.addOption(":audio-language=\(language)") }
        if let language = preferredSubtitleLanguage { media.addOption(":sub-language=\(language)") }
        let player = VLCMediaPlayer(options: ["--quiet", "--no-video-title-show"])
        if capturesDecoderEvidence {
            player.libraryInstance.loggers = [DecoderEvents(owner: self, sessionID: sessionID)]
        }
        let delegate = PlayerEvents(owner: self, sessionID: sessionID)
        player.delegate = delegate
        player.timeChangeUpdateInterval = 0.25
        player.media = media
        player.drawable = drawable
        engine = player
        events = delegate
        // Wait for SwiftUI's native surface before starting video output. This
        // also prevents VLC from opening an independent desktop video window.
        if drawable != nil { startEngine() }
    }

    public func play() {
        wantsToPlay = true
        guard drawable != nil, let engine else { return }
        if didEnd {
            didEnd = false
            pendingSeek = 0
        }
        if engine.state == .stopped || engine.state == .nothingSpecial {
            startEngine()
        } else {
            #if os(iOS)
            requestAudioActivation(for: engine)
            #else
            engine.play()
            #endif
        }
    }

    public func pause() {
        #if os(iOS)
        resumesAfterInterruption = false
        #endif
        wantsToPlay = false
        engine?.pause()
        isPlaying = false
        backendIsLoading = false
        refreshLoading()
        openingTimeout?.cancel()
        openingTimeout = nil
        captureProgress()
    }

    public func toggle() {
        if isPlaying || (isLoading && wantsToPlay) { pause() } else { play() }
    }

    public func seek(_ seconds: Double) {
        guard seconds.isFinite else { return }
        let target = duration > 0 ? min(duration, max(0, seconds)) : max(0, seconds)
        pendingSeek = target
        applyPendingSeek()
    }

    public func setRate(_ newRate: Float) {
        guard newRate.isFinite else { return }
        rate = min(3, max(0.25, newRate))
        engine?.rate = rate
    }

    public func setVolume(_ newVolume: Float) {
        guard newVolume.isFinite else { return }
        volume = min(1, max(0, newVolume))
        engine?.audio?.volume = Int32((volume * 100).rounded())
    }

    public func selectChapter(_ id: Int) {
        guard let chapter = chapters.first(where: { $0.id == id }), let index = Int32(exactly: id), let engine else { return }
        engine.currentChapterIndex = index
        // VLC does not emit time callbacks for every chapter change while
        // paused. Queue a seek to the chapter's real timestamp and update the
        // observable position before playback resumes.
        if let time = chapter.time { seek(time) }
    }

    public func selectAudio(_ id: String) {
        guard let track = engine?.audioTracks.first(where: { $0.trackId == id }) else { return }
        track.isSelectedExclusively = true
        refreshTracks()
    }

    public func selectSubtitle(_ id: String?) {
        guard let engine else { return }
        if let id {
            guard let track = engine.textTracks.first(where: { $0.trackId == id }) else { return }
            engine.selectTextTracks([track])
        } else {
            engine.deselectAllTextTracks()
        }
        refreshTracks()
    }

    public func addSubtitle(_ url: URL) {
        subtitleLoadingTask?.cancel()
        subtitleLoadingTask = nil
        guard MediaFormats.subtitle.contains(url.pathExtension.lowercased()) else {
            subtitleErrorMessage = "请选择 SRT、ASS、SSA、VTT 或 SUB 字幕文件。"
            return
        }
        guard let engine else {
            subtitleErrorMessage = "请先打开视频后再添加字幕。"
            return
        }
        let previousTracks = Set(engine.textTracks.map(\.trackId))
        retainSecurityScope(for: url)
        guard engine.addPlaybackSlave(url, type: .subtitle, enforce: true) == 0 else {
            subtitleErrorMessage = "无法添加这个字幕文件，请检查文件是否可读。"
            return
        }
        subtitleErrorMessage = nil
        refreshTracks()
        let token = sessionID
        subtitleLoadingTask = Task { [weak self] in
            var addedTrackID: String?
            for _ in 0..<50 {
                guard !Task.isCancelled, let self, self.sessionID == token, let engine = self.engine else { return }
                if addedTrackID == nil {
                    addedTrackID = engine.textTracks.first(where: { !previousTracks.contains($0.trackId) })?.trackId
                }
                if let addedTrackID, let track = engine.textTracks.first(where: { $0.trackId == addedTrackID }) {
                    // VLC's forced-slave flag does not reliably re-enable a
                    // track after the user has disabled subtitles. Select the
                    // real newly added track and verify the engine's state.
                    if !track.isSelected { engine.selectTextTracks([track]) }
                    self.refreshTracks()
                    if self.selectedSubtitleID == addedTrackID {
                        self.subtitleErrorMessage = nil
                        return
                    }
                }
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
            guard let self, self.sessionID == token, !Task.isCancelled else { return }
            self.subtitleErrorMessage = "无法加载这个字幕文件，请检查内容和编码后重试。"
        }
    }

    public func setSubtitleDelay(_ seconds: Double) {
        guard seconds.isFinite else { return }
        subtitleDelay = min(600, max(-600, seconds))
        engine?.currentVideoSubTitleDelay = Int(subtitleDelay * 1_000_000)
    }

    public func setSubtitleScale(_ scale: Float) {
        guard scale.isFinite else { return }
        subtitleScale = min(3, max(0.5, scale))
        engine?.currentSubTitleFontScale = subtitleScale
    }

    public func setVideoFill(_ fills: Bool) {
        fillsScreen = fills
        engine?.videoFitMode = fills ? .larger : .smaller
    }

    /// Language codes are settings for the next film; manual track selection
    /// remains available for the currently playing film.
    public func setPreferredLanguages(audio: String?, subtitles: String?) {
        preferredAudioLanguage = normalizedLanguage(audio)
        preferredSubtitleLanguage = normalizedLanguage(subtitles)
    }

    /// Stops network/decoder work and releases security-scoped files. It never
    /// modifies or deletes the original film or subtitle.
    public func stop() {
        captureProgress()
        sessionID = UUID()
        openingTimeout?.cancel()
        openingTimeout = nil
        subtitleLoadingTask?.cancel()
        subtitleLoadingTask = nil
        engine?.delegate = nil
        engine?.stop()
        engine?.drawable = nil
        engine?.media = nil
        engine = nil
        events = nil
        for url in scopedURLs { url.stopAccessingSecurityScopedResource() }
        scopedURLs = []
        wantsToPlay = false
        isPlaying = false
        backendIsLoading = false
        isLoading = false
        isSeekable = false
        pendingSeek = nil
        #if os(iOS)
        resumesAfterInterruption = false
        pendingAudioActivation = nil
        audioSessionCoordinator.deactivate(owner: audioSessionOwner)
        #endif
    }

    public func attachDrawable(_ view: AnyObject) {
        #if os(iOS)
        let wasDetached = drawable == nil
        #endif
        drawable = view
        engine?.drawable = view
        #if os(iOS)
        // Reacquire audio when a dismantled surface is attached again. SwiftUI
        // also updates an existing surface; those updates must not reactivate.
        if wantsToPlay && wasDetached { play() }
        #else
        if wantsToPlay && !didStart { startEngine() }
        #endif
    }

    public func detachDrawable(_ view: AnyObject) {
        guard drawable === view else { return }
        engine?.drawable = nil
        drawable = nil
    }

    private func startEngine() {
        guard let engine else { return }
        engine.rate = rate
        engine.audio?.volume = Int32((volume * 100).rounded())
        engine.currentVideoSubTitleDelay = Int(subtitleDelay * 1_000_000)
        engine.currentSubTitleFontScale = subtitleScale
        engine.videoFitMode = fillsScreen ? .larger : .smaller
        #if os(iOS)
        requestAudioActivation(for: engine)
        #else
        armOpeningTimeout()
        engine.play()
        #endif
    }

    private func armOpeningTimeout() {
        guard openingTimeout == nil else { return }
        let token = sessionID
        openingTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            guard let self, self.sessionID == token else { return }
            #if os(iOS)
            guard !self.didStart || self.pendingAudioActivation != nil else { return }
            #else
            guard !self.didStart else { return }
            #endif
            self.fail("视频打开超时，请检查片源连接后重试。")
            self.engine?.stop()
        }
    }

    #if os(iOS)
    private func requestAudioActivation(for engine: VLCMediaPlayer) {
        // The deadline includes waiting for the background audio worker. A
        // repeated play request shares the activation already in flight.
        armOpeningTimeout()
        guard pendingAudioActivation == nil else {
            refreshLoading()
            return
        }
        let request = UUID()
        let token = sessionID
        let engineID = ObjectIdentifier(engine)
        pendingAudioActivation = request
        refreshLoading()
        audioSessionCoordinator.activate(owner: audioSessionOwner) { [weak self] succeeded in
            // Pass only values across the worker boundary, never a VLC object.
            Task { @MainActor [weak self] in
                self?.finishAudioActivation(succeeded, request: request, token: token, engineID: engineID)
            }
        }
    }

    private func finishAudioActivation(_ succeeded: Bool, request: UUID, token: UUID,
                                       engineID: ObjectIdentifier) {
        guard token == sessionID, pendingAudioActivation == request,
              let engine, ObjectIdentifier(engine) == engineID else { return }
        pendingAudioActivation = nil
        guard wantsToPlay else {
            refreshLoading()
            if !didStart { audioSessionCoordinator.deactivate(owner: audioSessionOwner) }
            return
        }
        guard drawable != nil else {
            // Keep the latest intent for a later surface attachment, but never
            // start a decoder after the native surface has been dismantled.
            openingTimeout?.cancel()
            openingTimeout = nil
            refreshLoading()
            audioSessionCoordinator.deactivate(owner: audioSessionOwner)
            return
        }
        guard succeeded else {
            fail("无法启动音频播放，请重试。")
            return
        }
        isPlaying = wantsToPlay && engine.state == .playing
        refreshLoading()
        engine.play()
        // Initial opening still waits for the real playing callback. Resuming
        // an existing session has finished its audio preparation here.
        if didStart {
            openingTimeout?.cancel()
            openingTimeout = nil
        }
    }
    #endif

    private func refreshLoading() {
        #if os(iOS)
        let preparingAudio = pendingAudioActivation != nil
        #else
        let preparingAudio = false
        #endif
        let waitingForPlayback = !didStart || engine?.state == .opening || engine?.state == .paused
        isLoading = wantsToPlay && errorMessage == nil && (backendIsLoading || preparingAudio || waitingForPlayback)
    }

    private func retainSecurityScope(for url: URL) {
        if url.isFileURL && !scopedURLs.contains(url) && url.startAccessingSecurityScopedResource() {
            scopedURLs.append(url)
        }
    }

    private func normalizedLanguage(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowed = CharacterSet.letters.union(CharacterSet(charactersIn: "-,"))
        guard !normalized.isEmpty, normalized.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return normalized
    }

    private func applyPendingSeek() {
        guard let target = pendingSeek, let engine, engine.isSeekable else { return }
        pendingSeek = nil
        let bounded = min(duration > 0 ? min(duration, target) : target,
                          Double(Int64.max / 1_000_000) - 1)
        // NSNumber keeps long media timestamps outside the old Int32 API.
        engine.time = VLCTime(number: NSNumber(value: bounded * 1_000))
        position = bounded
        onProgress?(position, duration)
    }

    private func captureProgress() {
        guard let engine, didStart, !didEnd else { return }
        guard let raw = engine.time.value?.doubleValue, raw.isFinite, raw >= 0 else { return }
        let safe = PlaybackProgress(itemID: "", position: raw / 1_000, duration: duration)
        position = safe.position
        onProgress?(position, duration)
    }

    private func refreshTracks() {
        guard let engine else { return }
        audioTracks = engine.audioTracks.map { PlayerTrack(id: $0.trackId, name: $0.trackName) }
        subtitleTracks = engine.textTracks.map { PlayerTrack(id: $0.trackId, name: $0.trackName) }
        selectedAudioID = engine.audioTracks.first(where: { $0.isSelected })?.trackId
        selectedSubtitleID = engine.textTracks.first(where: { $0.isSelected })?.trackId
        let currentTitle = engine.currentTitleIndex
        guard currentTitle >= 0 else { chapters = []; return }
        chapters = engine.chapterDescriptions(ofTitle: currentTitle).map {
            let milliseconds = $0.timeOffset.value?.doubleValue
            return PlayerChapter(id: Int($0.chapterIndex), name: $0.name ?? "章节 \(Int($0.chapterIndex) + 1)",
                                 time: milliseconds.map { max(0, $0 / 1_000) })
        }
    }

    private func fail(_ message: String) {
        openingTimeout?.cancel()
        openingTimeout = nil
        backendIsLoading = false
        isLoading = false
        isPlaying = false
        wantsToPlay = false
        errorMessage = message
        #if os(iOS)
        pendingAudioActivation = nil
        audioSessionCoordinator.deactivate(owner: audioSessionOwner)
        #endif
    }

    fileprivate func receive(state: VLCMediaPlayerState, token: UUID) {
        guard token == sessionID, let engine else { return }
        isSeekable = engine.isSeekable
        switch state {
        case .opening:
            backendIsLoading = true
            refreshLoading()
        case .playing:
            didStart = true
            isPlaying = wantsToPlay
            errorMessage = nil
            backendIsLoading = false
            refreshLoading()
            #if os(iOS)
            if pendingAudioActivation == nil {
                openingTimeout?.cancel()
                openingTimeout = nil
            }
            #else
            openingTimeout?.cancel()
            openingTimeout = nil
            #endif
            refreshTracks()
            updateDuration()
            applyPendingSeek()
            engine.rate = rate
            if !wantsToPlay { engine.pause() }
        case .paused:
            #if DEBUG
            debugPausedCallbacksReceived += 1
            #endif
            // A queued delegate event can arrive after the engine resumed.
            // Keep the observable control state aligned with current playback.
            isPlaying = wantsToPlay && engine.state == .playing
            if engine.state == .paused { backendIsLoading = false }
            refreshLoading()
            captureProgress()
            // libVLC queues input controls asynchronously. A play requested
            // immediately after pause may run before libVLC considers itself
            // paused. Reconcile this late pause event with the latest intent.
            if wantsToPlay {
                #if os(iOS)
                if pendingAudioActivation == nil { engine.play() }
                #else
                engine.play()
                #endif
            }
        case .error:
            fail("无法播放这个视频，请检查文件格式或片源连接。")
        case .stopping:
            captureProgress()
            isPlaying = false
            backendIsLoading = false
            isLoading = false
        case .stopped:
            backendIsLoading = false
            isLoading = false
            isPlaying = false
            // Recoverable subtitle errors must not prevent a completed video
            // from recording its end. Playback failures clear wantsToPlay.
            guard didStart, wantsToPlay, !didEnd else { return }
            // VLC 4 reports natural completion as stopped. A stop before the
            // known end is treated as an interrupted source, not as watched.
            if duration > 0 && position >= max(0, duration - 1.5) {
                didEnd = true
                wantsToPlay = false
                position = duration
                onProgress?(position, duration)
                onEnded?()
            } else {
                fail("播放已中断，请检查片源连接后重试。")
            }
        case .nothingSpecial:
            break
        @unknown default:
            break
        }
    }

    fileprivate func receiveTime(token: UUID) {
        guard token == sessionID else { return }
        isSeekable = engine?.isSeekable ?? false
        updateDuration()
        applyPendingSeek()
        captureProgress()
    }

    fileprivate func receiveTracks(token: UUID) {
        guard token == sessionID else { return }
        refreshTracks()
    }

    fileprivate func receiveDecoderEvidence(selected: Bool, acceptedFrame: Bool, token: UUID) {
        guard token == sessionID else { return }
        videoToolboxSelected = videoToolboxSelected || selected
        videoToolboxAcceptedFrame = videoToolboxAcceptedFrame || acceptedFrame
    }

    fileprivate func receiveLength(_ milliseconds: Int64, token: UUID) {
        guard token == sessionID, milliseconds > 0 else { return }
        isSeekable = engine?.isSeekable ?? false
        duration = Double(milliseconds) / 1_000
        applyPendingSeek()
    }

    fileprivate func receiveRate(_ appliedRate: Float, token: UUID) {
        guard token == sessionID, appliedRate.isFinite, appliedRate > 0 else { return }
        rate = appliedRate
    }

    fileprivate func receiveBuffering(_ progress: Float, token: UUID) {
        guard token == sessionID, errorMessage == nil, wantsToPlay else { return }
        backendIsLoading = progress < 1
        refreshLoading()
    }

    private func updateDuration() {
        guard let raw = engine?.media?.length.value?.doubleValue, raw.isFinite, raw > 0 else { return }
        duration = raw / 1_000
    }

    #if os(iOS)
    private func observeAudioSession() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let kind = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in
                guard let self, let kind, let type = AVAudioSession.InterruptionType(rawValue: kind) else { return }
                if type == .began {
                    let wasPlaying = self.wantsToPlay
                    self.pause()
                    self.resumesAfterInterruption = wasPlaying
                } else if self.resumesAfterInterruption {
                    self.resumesAfterInterruption = false
                    if AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) { self.play() }
                }
            }
        }
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor [weak self] in self?.pause() }
        }
    }
    #endif
}

/// Test-only capture reduces backend logs to two booleans. It retains or emits
/// no message, URL, file path or credentials from libVLC logging callbacks.
private final class DecoderEvents: NSObject, VLCLogging {
    var level: VLCLogLevel = .debug
    private weak var owner: FilmPlayer?
    private let sessionID: UUID

    @MainActor init(owner: FilmPlayer, sessionID: UUID) {
        self.owner = owner
        self.sessionID = sessionID
    }

    func handleMessage(_ message: String, logLevel: VLCLogLevel, context: VLCLogContext?) {
        guard context?.module == "videotoolbox" else { return }
        let selected = message.hasPrefix("Using Video Toolbox to decode ")
        let accepted = message.hasPrefix("session accepted first frame ")
        guard selected || accepted else { return }
        let token = sessionID
        Task { @MainActor [weak owner] in
            owner?.receiveDecoderEvidence(selected: selected, acceptedFrame: accepted, token: token)
        }
    }
}

/// Delegate callbacks do not carry mutable VLC objects across executors.
private final class PlayerEvents: NSObject, VLCMediaPlayerDelegate {
    private weak var owner: FilmPlayer?
    private let sessionID: UUID

    @MainActor init(owner: FilmPlayer, sessionID: UUID) {
        self.owner = owner
        self.sessionID = sessionID
    }

    #if DEBUG
    private let debugPauseLock = NSLock()
    private var debugHoldNextPause = false
    private var debugHeldPause: VLCMediaPlayerState?

    func debugHoldNextPausedCallback() {
        debugPauseLock.lock()
        defer { debugPauseLock.unlock() }
        debugHoldNextPause = true
    }

    var debugHasHeldPausedCallback: Bool {
        debugPauseLock.lock()
        defer { debugPauseLock.unlock() }
        return debugHeldPause != nil
    }

    func debugReleaseHeldPausedCallback() {
        debugPauseLock.lock()
        let held = debugHeldPause
        debugHeldPause = nil
        debugPauseLock.unlock()
        if let held { enqueueState(held) }
    }
    #endif

    func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        #if DEBUG
        debugPauseLock.lock()
        let hold = newState == .paused && debugHoldNextPause
        if hold {
            debugHoldNextPause = false
            debugHeldPause = newState
        }
        debugPauseLock.unlock()
        if hold { return }
        #endif
        enqueueState(newState)
    }

    private func enqueueState(_ newState: VLCMediaPlayerState) {
        let token = sessionID
        Task { @MainActor [weak owner] in owner?.receive(state: newState, token: token) }
    }

    func mediaPlayerTimeChanged(_ notification: Notification) {
        let token = sessionID
        Task { @MainActor [weak owner] in owner?.receiveTime(token: token) }
    }

    func mediaPlayerBufferingChanged(_ progress: Float) {
        let token = sessionID
        Task { @MainActor [weak owner] in owner?.receiveBuffering(progress, token: token) }
    }

    func mediaPlayerLengthChanged(_ length: Int64) {
        let token = sessionID
        Task { @MainActor [weak owner] in owner?.receiveLength(length, token: token) }
    }

    func mediaPlayerRateChanged(_ rate: Float) {
        let token = sessionID
        Task { @MainActor [weak owner] in owner?.receiveRate(rate, token: token) }
    }

    func mediaPlayerTrackAdded(_ trackId: String, with trackType: VLCMedia.TrackType) { tracksChanged() }
    func mediaPlayerTrackRemoved(_ trackId: String, with trackType: VLCMedia.TrackType) { tracksChanged() }
    func mediaPlayerTrackUpdated(_ trackId: String, with trackType: VLCMedia.TrackType) { tracksChanged() }
    func mediaPlayerTrackSelected(_ trackType: VLCMedia.TrackType, selectedId: String, unselectedId: String) { tracksChanged() }
    func mediaPlayerTitleListChanged(_ notification: Notification) { tracksChanged() }
    func mediaPlayerTitleSelectionChanged(_ notification: Notification) { tracksChanged() }
    func mediaPlayerChapterChanged(_ notification: Notification) { tracksChanged() }

    private func tracksChanged() {
        let token = sessionID
        Task { @MainActor [weak owner] in owner?.receiveTracks(token: token) }
    }
}
