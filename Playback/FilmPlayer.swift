import Foundation
import Observation
import FilmDomain
import VLCKit
import AetherVLCBridge
#if DEBUG
import Synchronization
#endif
#if os(iOS)
import AVFAudio
#endif

/// The application owns one player. Every opened film gets a fresh VLC session,
/// so delayed callbacks from a previous film cannot change the current film.
@MainActor @Observable
public final class FilmPlayer: NSObject {
    public enum SeekStatus: Equatable, Sendable {
        case seeking
        case waitingForSource
    }

    public private(set) var position: Double = 0
    public private(set) var duration: Double = 0
    public private(set) var isPlaying = false
    public private(set) var isLoading = false
    public private(set) var seekStatus: SeekStatus?
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

    @ObservationIgnored public var onProgress: (@MainActor (Double, Double, Bool) -> Void)?
    @ObservationIgnored public var onPlaybackSessionStarted: (@MainActor () -> Void)?
    @ObservationIgnored public var onPlaybackFailure: (@MainActor () -> Void)?
    @ObservationIgnored public var completionValidator: (@MainActor () async -> Bool)?
    @ObservationIgnored public var onEnded: (@MainActor () -> Void)?
    @ObservationIgnored private var engine: AetherVLCMediaPlayer?
    @ObservationIgnored private var events: PlayerEvents?
    @ObservationIgnored private var sessionID = UUID()
    @ObservationIgnored private var failureNotified = false
    @ObservationIgnored private weak var drawable: AnyObject?
    @ObservationIgnored private var scopedURLs: [URL] = []
    @ObservationIgnored private var pendingSeek: Double?
    private struct SeekPresentation {
        let id: UUID
        let target: Double
        let began: ContinuousClock.Instant
        let callbackBaseline: UInt64
        let videoBaseline: UInt64
        let audioBaseline: UInt64
        var maximumRate: Double
        var hasPlayed: Bool
        var callbackSequence: UInt64? = nil
        var requestEnded = false
    }
    @ObservationIgnored private var seekPresentation: SeekPresentation?
    @ObservationIgnored private var seekStatusDelay: Task<Void, Never>?
    @ObservationIgnored private var wantsToPlay = false
    @ObservationIgnored private var backendIsLoading = false
    @ObservationIgnored private var didStart = false
    @ObservationIgnored private var didEnd = false
    @ObservationIgnored private var stoppingReason: AetherVLCMediaStoppingReason?
    @ObservationIgnored private var didBackendStop = false
    @ObservationIgnored private var stoppingInputTime: Double?
    @ObservationIgnored private var stoppingHadError = false
    @ObservationIgnored private var measuredInputTime: Double?
    @ObservationIgnored private var seekEvidenceTarget: Double?
    @ObservationIgnored private var seekOutputBaseline: UInt64 = 0
    @ObservationIgnored private var completionEvaluation: Task<Void, Never>?
    var backendEngineForTesting: AetherVLCMediaPlayer? { engine }
    @ObservationIgnored private var measuredClockTime: Double?
    var backendClockTime: Double? { measuredClockTime }
    @ObservationIgnored private var measuredClockSystemDate: Int64?
    var backendClockIsRunning: Bool { measuredClockTime != nil && (measuredClockSystemDate.map { $0 > 0 && $0 != Int64.max } ?? false) }
    var backendInputTime: Double? { measuredInputTime }
    var backendStoppingReason: Int? { stoppingReason.map { Int($0.rawValue) } }
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
        seekStatusDelay?.cancel()
        completionEvaluation?.cancel()
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
    @ObservationIgnored fileprivate var debugLifecycleTrace: PlaybackLifecycleTrace?
    @ObservationIgnored fileprivate var debugTraceGeneration = 0

    /// Explicit integration-test opt-in. No paths, URLs or credentials enter
    /// this bounded trace, and Release builds omit its storage and callbacks.
    func debugEnableLifecycleTrace(origin: ContinuousClock.Instant = .now, capacity: Int = 2_048) {
        debugLifecycleTrace = PlaybackLifecycleTrace(origin: origin, capacity: capacity)
    }

    func debugLifecycleTraceData() -> Data? { debugLifecycleTrace?.snapshotData() }

    fileprivate func debugRecordLifecycle(_ event: PlaybackLifecycleTrace.Event,
                                         generation: Int? = nil, sourceSequence: Int? = nil,
                                         state: Int? = nil, time: Int64? = nil,
                                         systemDate: Int64? = nil, target: Double? = nil,
                                         accepted: Bool? = nil,
                                         displayed: UInt64? = nil, played: UInt64? = nil) {
        guard let debugLifecycleTrace else { return }
        #if os(iOS)
        let preparingAudio = pendingAudioActivation != nil
        #else
        let preparingAudio = false
        #endif
        debugLifecycleTrace.record(event, generation: generation ?? debugTraceGeneration,
                                    sourceSequence: sourceSequence, state: state, time: time,
                                    systemDate: systemDate, target: target,
                                    modelPlaying: isPlaying, wantsToPlay: wantsToPlay,
                                    audioPending: preparingAudio, accepted: accepted,
                                    displayed: displayed, played: played)
    }

    // Isolated probe only: capture one actual paused callback and release it
    // through the same delegate Task after real playback has resumed.
    @ObservationIgnored private(set) var debugPausedCallbacksReceived = 0
    func debugHoldNextPausedCallback() { events?.debugHoldNextPausedCallback() }
    var debugHasHeldPausedCallback: Bool { events?.debugHasHeldPausedCallback ?? false }
    func debugReleaseHeldPausedCallback() { events?.debugReleaseHeldPausedCallback() }
    func debugRetainHeldPausedRelease() -> @MainActor () -> Void {
        let previous = events
        return { previous?.debugReleaseHeldPausedCallback() }
    }
    #endif

    public func load(url: URL, startAt: Double = 0) {
        #if DEBUG
        debugRecordLifecycle(.commandLoad, target: startAt.isFinite ? startAt : nil)
        #endif
        stop()
        failureNotified = false
        onPlaybackSessionStarted?()
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
        installEngine(media: media)
        // Wait for SwiftUI's native surface before starting video output. This
        // also prevents VLC from opening an independent desktop video window.
        if drawable != nil { startEngine() }
    }

    public func play() {
        #if DEBUG
        debugRecordLifecycle(.commandPlay)
        #endif
        wantsToPlay = true
        recordSeekPlayback(playing: true)
        guard drawable != nil, let engine else { return }
        if didEnd {
            didEnd = false
            pendingSeek = 0
            position = 0
        }
        if engine.state == .stopped || engine.state == .nothingSpecial {
            startEngine()
        } else {
        #if os(iOS)
        requestAudioActivation(for: engine)
        #else
        #if DEBUG
        debugRecordLifecycle(.enginePlaySubmitted)
        #endif
        engine.play()
            #endif
        }
    }

    public func pause() {
        #if DEBUG
        debugRecordLifecycle(.commandPause)
        #endif
        #if os(iOS)
        resumesAfterInterruption = false
        #endif
        recordSeekPlayback(playing: engine?.state == .playing)
        wantsToPlay = false
        #if DEBUG
        debugRecordLifecycle(.enginePauseSubmitted)
        #endif
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
        #if DEBUG
        debugRecordLifecycle(.commandSeek, target: seconds.isFinite ? seconds : nil)
        #endif
        guard seconds.isFinite else { return }
        clearSeekPresentation()
        let target = duration > 0 ? min(duration, max(0, seconds)) : max(0, seconds)
        seekEvidenceTarget = target
        seekOutputBaseline = displayedVideoFrames
        measuredInputTime = nil
        measuredClockTime = nil
        pendingSeek = target
        applyPendingSeek()
    }

    public func setRate(_ newRate: Float) {
        guard newRate.isFinite else { return }
        rate = min(3, max(0.25, newRate))
        recordSeekPlayback(rate: rate)
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
        #if DEBUG
        debugRecordLifecycle(.commandStop)
        #endif
        captureProgress()
        sessionID = UUID()
        clearSeekPresentation()
        stoppingReason = nil
        didBackendStop = false
        stoppingInputTime = nil
        stoppingHadError = false
        measuredInputTime = nil
        measuredClockTime = nil
        seekEvidenceTarget = nil
        seekOutputBaseline = 0
        completionEvaluation?.cancel()
        completionEvaluation = nil
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

    private func installEngine(media: VLCMedia) {
        #if DEBUG
        debugTraceGeneration += 1
        #endif
        var options = ["--quiet", "--no-video-title-show", "--stats-min-report-interval=50"]
        #if os(macOS)
        options.append("--vout=samplebufferdisplay")
        #endif
        let player = AetherVLCMediaPlayer(options: options)
        if capturesDecoderEvidence {
            player.libraryInstance.loggers = [DecoderEvents(owner: self, sessionID: sessionID)]
        }
        let delegate = PlayerEvents(owner: self, sessionID: sessionID)
        player.delegate = delegate
        player.timeChangeUpdateInterval = 0.25
        // This minimum period throttles normal-point updates to at most 20/sec.
        // The selected source controls their actual cadence; a final normal
        // point is not promised. UI time notifications remain at 4Hz.
        player.minimalTimePeriod = 50_000
        player.media = media
        player.drawable = drawable
        engine = player
        events = delegate
    }

    private func replaceFinishedEngine() {
        guard let previous = engine, let media = previous.media else { return }
        // Reuse the media item, including imported slaves and metadata, but give
        // every replay a fresh C player and immutable delegate generation.
        previous.delegate = nil
        previous.drawable = nil
        previous.media = nil
        sessionID = UUID()
        clearSeekPresentation()
        completionEvaluation?.cancel()
        completionEvaluation = nil
        openingTimeout?.cancel()
        openingTimeout = nil
        subtitleLoadingTask?.cancel()
        subtitleLoadingTask = nil
        #if os(iOS)
        pendingAudioActivation = nil
        audioSessionCoordinator.deactivate(owner: audioSessionOwner)
        #endif
        didStart = false
        stoppingReason = nil
        didBackendStop = false
        stoppingInputTime = nil
        stoppingHadError = false
        measuredInputTime = nil
        measuredClockTime = nil
        measuredClockSystemDate = nil
        seekEvidenceTarget = nil
        seekOutputBaseline = 0
        backendIsLoading = true
        refreshLoading()
        failureNotified = false
        onPlaybackSessionStarted?()
        installEngine(media: media)
    }

    private func startEngine() {
        if didBackendStop { replaceFinishedEngine() }
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
        #if DEBUG
        debugRecordLifecycle(.enginePlaySubmitted)
        #endif
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
    private func requestAudioActivation(for engine: AetherVLCMediaPlayer) {
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
        #if DEBUG
        debugRecordLifecycle(.audioRequested)
        let trace = debugLifecycleTrace
        let generation = debugTraceGeneration
        #endif
        refreshLoading()
        audioSessionCoordinator.activate(owner: audioSessionOwner) { [weak self] succeeded in
            #if DEBUG
            trace?.record(.audioWorkerFinished, generation: generation, accepted: succeeded)
            #endif
            // Pass only values across the worker boundary, never a VLC object.
            Task { @MainActor [weak self] in
                self?.finishAudioActivation(succeeded, request: request, token: token, engineID: engineID)
            }
        }
    }

    private func finishAudioActivation(_ succeeded: Bool, request: UUID, token: UUID,
                                       engineID: ObjectIdentifier) {
        #if DEBUG
        debugRecordLifecycle(.audioFinished, accepted: succeeded && token == sessionID
                             && pendingAudioActivation == request
                             && engine.map(ObjectIdentifier.init) == engineID)
        #endif
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
        #if DEBUG
        debugRecordLifecycle(.enginePlaySubmitted)
        #endif
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
        // Include initial/resume seeks in the same evidence boundary.
        seekEvidenceTarget = bounded
        seekOutputBaseline = displayedVideoFrames
        measuredInputTime = nil
        measuredClockTime = nil
        // NSNumber keeps long media timestamps outside the old Int32 API.
        #if DEBUG
        debugRecordLifecycle(.seekSubmitted, target: bounded)
        #endif
        beginSeekPresentation(target: bounded, engine: engine)
        engine.time = VLCTime(number: NSNumber(value: bounded * 1_000))
        #if DEBUG
        debugRecordLifecycle(.seekApplied, target: bounded)
        #endif
        position = bounded
        // Save paused-seek resume without treating the requested target as watched.
        onProgress?(position, duration, false)
    }

    private func beginSeekPresentation(target: Double, engine: AetherVLCMediaPlayer) {
        seekStatusDelay?.cancel()
        let requestID = UUID()
        seekPresentation = SeekPresentation(id: requestID, target: target, began: .now,
            callbackBaseline: engine.seekCallbackSequence,
            videoBaseline: displayedVideoFrames, audioBaseline: playedAudioBuffers,
            maximumRate: Double(rate), hasPlayed: wantsToPlay || engine.state == .playing)
        seekStatus = .seeking
        let token = sessionID
        // This changes presentation only. It is not a read deadline or failure.
        seekStatusDelay = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard !Task.isCancelled, let self, self.sessionID == token,
                  self.seekPresentation?.id == requestID else { return }
            self.seekStatus = .waitingForSource
            self.seekStatusDelay = nil
        }
    }

    private func clearSeekPresentation() {
        seekStatusDelay?.cancel()
        seekStatusDelay = nil
        seekPresentation = nil
        seekStatus = nil
    }

    private func recordSeekPlayback(playing: Bool = false, rate: Float? = nil) {
        guard var presentation = seekPresentation else { return }
        presentation.hasPlayed = presentation.hasPlayed || playing
        if let rate, rate.isFinite, rate > 0 {
            presentation.maximumRate = max(presentation.maximumRate, Double(rate))
        }
        seekPresentation = presentation
    }

    fileprivate func receiveSeeking(_ seeking: Bool, targetTime: Int64, sequence: UInt64, token: UUID) {
        guard token == sessionID, let engine, !didBackendStop,
              stoppingReason == nil, errorMessage == nil,
              var presentation = seekPresentation, targetTime >= 0,
              sequence > presentation.callbackBaseline,
              sequence == engine.seekCallbackSequence,
              abs(Double(targetTime) / 1_000_000 - presentation.target) < 0.002 else { return }
        if presentation.callbackSequence != sequence {
            presentation.callbackSequence = sequence
            presentation.requestEnded = !seeking
        } else if !seeking {
            // NULL from on_seek ends a request; it can also mean source removal.
            // Only subsequent real output/clock evidence clears the UI below.
            presentation.requestEnded = true
        }
        // Tasks can deliver the start after its matching end. The immutable
        // sequence proves the start existed; a late start cannot reopen it.
        seekPresentation = presentation
        refreshSeekPresentation()
    }

    private func refreshSeekPresentation() {
        guard let presentation = seekPresentation, presentation.requestEnded,
              let sequence = presentation.callbackSequence, let engine,
              engine.seekCallbackSequence == sequence,
              !didBackendStop, stoppingReason == nil, errorMessage == nil,
              let clock = measuredClockTime, let input = measuredInputTime,
              clock.isFinite, input.isFinite, duration > 0,
              clock <= duration + 1, input <= duration + 1 else { return }
        let elapsed = presentation.began.duration(to: .now).components
        let seconds = max(0, Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18)
        // A permissive UI bound, not a clock estimate: use the highest rate
        // seen in this request and allow elapsed time after any play. Pauses
        // and lower later rates can only reduce real progress below this cap.
        let advance = presentation.hasPlayed ? seconds * presentation.maximumRate : 0
        let lower = max(0, presentation.target - 1)
        let upper = min(duration + 1, presentation.target + advance + 1)
        guard clock >= lower, clock <= upper, input >= lower, input <= upper else { return }
        if wantsToPlay {
            guard backendClockIsRunning,
                  displayedVideoFrames > presentation.videoBaseline || playedAudioBuffers > presentation.audioBaseline else { return }
        } else {
            // Paused seeks can output a preview frame with INT64_MAX as date.
            // They must not require running audio or resume playback to clear UI.
            guard engine.state == .paused,
                  measuredClockSystemDate == Int64.max,
                  displayedVideoFrames > presentation.videoBaseline else { return }
        }
        clearSeekPresentation()
    }

    private func captureProgress() {
        guard let engine, didStart, !didEnd else { return }
        guard let raw = engine.time.value?.doubleValue, raw.isFinite, raw >= 0 else { return }
        let seconds = raw / 1_000
        // A failed upstream interpolation can otherwise fabricate an enormous
        // time, which must never be clamped into a believable completed film.
        guard duration > 0, seconds <= duration + 1 else { return }
        guard displayedVideoFrames > 0 || playedAudioBuffers > 0 else { return }
        guard let clock = measuredClockTime else { return }
        // A timer can report the nominal duration for an incomplete source.
        // Only the completion validator may publish that final point.
        if completionValidator != nil, seconds >= duration { return }
        position = min(duration, max(0, seconds))
        if let target = seekEvidenceTarget {
            guard displayedVideoFrames > seekOutputBaseline, abs(clock - target) < 1 else {
                onProgress?(position, duration, false)
                return
            }
            seekEvidenceTarget = nil
        }
        // The UI may still contain an immediate seek estimate. A real normal
        // clock point must reach that position before it can mark the film watched.
        // Native stopping can precede its queued delegate delivery. Draining a
        // failed input must save a resume point without newly confirming watched.
        let state = engine.state
        let confirmed = (state == .playing || state == .paused)
            && stoppingReason == nil && !didBackendStop && completionEvaluation == nil
            && errorMessage == nil
        // Cached milliseconds can lead a normal microsecond point slightly.
        // Confirm only the position already covered by that actual normal clock.
        let progressPosition = confirmed ? min(position, max(0, clock)) : position
        #if DEBUG
        debugRecordLifecycle(.progressCheckpoint, state: Int(state.rawValue),
            systemDate: measuredClockSystemDate, target: progressPosition, accepted: confirmed,
            displayed: displayedVideoFrames, played: playedAudioBuffers)
        #endif
        onProgress?(progressPosition, duration, confirmed)
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
        clearSeekPresentation()
        openingTimeout?.cancel()
        openingTimeout = nil
        backendIsLoading = false
        isLoading = false
        isPlaying = false
        wantsToPlay = false
        if !failureNotified, !didEnd {
            failureNotified = true
            onPlaybackFailure?()
        }
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
            recordSeekPlayback(playing: engine.state == .playing)
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
            refreshSeekPresentation()
            // libVLC queues input controls asynchronously. A play requested
            // immediately after pause may run before libVLC considers itself
            // paused. Reconcile this late pause event with the latest intent.
            if wantsToPlay {
                #if os(iOS)
                if pendingAudioActivation == nil {
                    #if DEBUG
                    debugRecordLifecycle(.enginePlaySubmitted)
                    #endif
                    engine.play()
                }
                #else
                #if DEBUG
                debugRecordLifecycle(.enginePlaySubmitted)
                #endif
                engine.play()
                #endif
            }
        case .error:
            fail("无法播放这个视频，请检查文件格式或片源连接。")
        case .stopping:
            clearSeekPresentation()
            captureProgress()
            isPlaying = false
            backendIsLoading = false
            isLoading = false
        case .stopped:
            clearSeekPresentation()
            backendIsLoading = false
            isLoading = false
            isPlaying = false
            didBackendStop = true
            evaluateCompletion()
        case .nothingSpecial:
            break
        @unknown default:
            break
        }
    }

    fileprivate func receiveStoppingReason(_ reason: AetherVLCMediaStoppingReason, inputTime: Int64, hadError: Bool, token: UUID) {
        guard token == sessionID, engine != nil else { return }
        clearSeekPresentation()
        stoppingReason = reason
        stoppingInputTime = inputTime >= 0 ? Double(inputTime) / 1_000_000 : nil
        stoppingHadError = hadError
        evaluateCompletion()
    }

    fileprivate func receiveClockPoint(_ time: Int64, position: Double, systemDate: Int64, token: UUID) {
        guard token == sessionID, engine != nil, time >= 0 else { return }
        measuredClockTime = Double(time) / 1_000_000
        measuredClockSystemDate = systemDate
        refreshSeekPresentation()
        if didBackendStop { evaluateCompletion() }
    }

    fileprivate func receiveInputTime(_ time: Int64, position: Double, token: UUID) {
        guard token == sessionID, engine != nil, time >= 0 else { return }
        measuredInputTime = Double(time) / 1_000_000
        refreshSeekPresentation()
        if didBackendStop { evaluateCompletion() }
    }

    private func evaluateCompletion() {
        guard didBackendStop, stoppingReason != nil, completionEvaluation == nil,
              didStart, wantsToPlay, !didEnd, errorMessage == nil, let engine else { return }
        let token = sessionID
        let identity = ObjectIdentifier(engine)
        guard stoppingReason == .endOfStream, !stoppingHadError,
              let clock = stoppingInputTime, duration > 0,
              clock >= duration - 0.25,
              displayedVideoFrames > 0 || playedAudioBuffers > 0 else {
            fail("播放已中断，请检查片源连接后重试。")
            return
        }
        let validator = completionValidator
        completionEvaluation = Task { [weak self] in
            let allowed = await validator?() ?? true
            guard let self, !Task.isCancelled, self.sessionID == token,
                  self.engine.map(ObjectIdentifier.init) == identity,
                  self.didBackendStop, self.wantsToPlay, !self.didEnd,
                  self.errorMessage == nil else { return }
            self.completionEvaluation = nil
            guard allowed else {
                self.fail("播放已中断，请检查片源连接后重试。")
                return
            }
            self.didEnd = true
            self.wantsToPlay = false
            self.position = self.duration
            self.onProgress?(self.position, self.duration, true)
            self.onEnded?()
        }
    }

    fileprivate func receiveTime(token: UUID) {
        guard token == sessionID else { return }
        isSeekable = engine?.isSeekable ?? false
        updateDuration()
        applyPendingSeek()
        captureProgress()
        refreshSeekPresentation()
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
        recordSeekPlayback(rate: appliedRate)
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
        let dynamicVideoToolbox = context?.module == "videotoolbox"
        // Static VLC modules share the linked libvlc module-name symbol.
        // Match the actual codec source and emitter function before accepting evidence.
        let staticVideoToolbox = context?.module == "libvlc"
            && context?.file?.hasSuffix("/modules/codec/videotoolbox/decoder.c") == true
        let selected = message.hasPrefix("Using Video Toolbox to decode ")
            && (dynamicVideoToolbox || (staticVideoToolbox && context?.function == "OpenDecoder"))
        let accepted = message.hasPrefix("session accepted first frame ")
            && (dynamicVideoToolbox || (staticVideoToolbox && context?.function == "DecodeBlock"))
        guard selected || accepted else { return }
        let token = sessionID
        Task { @MainActor [weak owner] in
            owner?.receiveDecoderEvidence(selected: selected, acceptedFrame: accepted, token: token)
        }
    }
}

#if DEBUG
/// A trace contains only immutable values supplied by the integration test,
/// commands and existing callbacks. Its lock never encloses a backend call.
fileprivate nonisolated final class PlaybackLifecycleTrace: Sendable {
    enum Event: Int, Codable, Sendable, CaseIterable {
        case commandLoad = 1, commandPlay, commandPause, commandSeek, seekApplied, commandStop
        case audioRequested = 10, audioFinished, audioWorkerFinished
        case enginePlaySubmitted = 15, enginePauseSubmitted, seekSubmitted
        case callbackState = 20, deliveryState, appliedState
        case callbackClock = 30, deliveryClock
        case callbackInput = 40, deliveryInput
        case callbackStopping = 50, deliveryStopping
        case callbackTime = 60, callbackBuffering, callbackLength
        case progressCheckpoint = 70
    }

    private struct Record: Encodable, Sendable {
        let sequence: Int
        let elapsedSeconds: Double
        let eventCode: Int
        let generation: Int
        let sourceSequence: Int?
        let state: Int?
        let timeMicroseconds: Int64?
        let systemDateMicroseconds: Int64?
        let clockRunning: Bool?
        let targetSeconds: Double?
        let modelPlaying: Bool?
        let wantsToPlay: Bool?
        let audioPending: Bool?
        let accepted: Bool?
        let displayedVideoFrames: UInt64?
        let playedAudioBuffers: UInt64?
    }

    private struct State: Sendable {
        var records: [Record?]
        var cursor = 0
        var sequence = 0
    }

    private struct Snapshot: Encodable {
        let capacity: Int
        let totalEvents: Int
        let evictedEvents: Int
        let eventCodes: [String: Int]
        let records: [Record]
    }

    private let origin: ContinuousClock.Instant
    private let capacity: Int
    private let storage: Mutex<State>

    init(origin: ContinuousClock.Instant, capacity: Int) {
        self.origin = origin
        self.capacity = min(4_096, max(1, capacity))
        storage = Mutex(State(records: Array(repeating: nil, count: self.capacity)))
    }

    @discardableResult
    func record(_ event: Event, generation: Int, sourceSequence: Int? = nil,
                state: Int? = nil, time: Int64? = nil, systemDate: Int64? = nil,
                target: Double? = nil, modelPlaying: Bool? = nil, wantsToPlay: Bool? = nil,
                audioPending: Bool? = nil, accepted: Bool? = nil,
                displayed: UInt64? = nil, played: UInt64? = nil) -> Int {
        let elapsed = origin.duration(to: .now).components
        let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        return storage.withLock { value in
            value.sequence += 1
            let sequence = value.sequence
            value.records[value.cursor] = Record(sequence: sequence, elapsedSeconds: seconds,
                eventCode: event.rawValue, generation: generation, sourceSequence: sourceSequence,
                state: state, timeMicroseconds: time, systemDateMicroseconds: systemDate,
                clockRunning: systemDate.map { $0 > 0 && $0 != Int64.max },
                targetSeconds: target, modelPlaying: modelPlaying, wantsToPlay: wantsToPlay,
                audioPending: audioPending, accepted: accepted,
                displayedVideoFrames: displayed, playedAudioBuffers: played)
            value.cursor = (value.cursor + 1) % capacity
            return sequence
        }
    }

    func snapshotData() -> Data? {
        let copied = storage.withLock { value in
            (value.records.compactMap { $0 }.sorted { $0.sequence < $1.sequence }, value.sequence)
        }
        let codes = Dictionary(uniqueKeysWithValues: Event.allCases.map { (String(describing: $0), $0.rawValue) })
        let snapshot = Snapshot(capacity: capacity, totalEvents: copied.1,
            evictedEvents: max(0, copied.1 - copied.0.count), eventCodes: codes, records: copied.0)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(snapshot)
    }
}
#endif

/// Delegate callbacks do not carry mutable VLC objects across executors.
private final class PlayerEvents: NSObject, AetherVLCMediaPlayerDelegate {
    private weak var owner: FilmPlayer?
    private let sessionID: UUID

    @MainActor init(owner: FilmPlayer, sessionID: UUID) {
        self.owner = owner
        self.sessionID = sessionID
        #if DEBUG
        lifecycleTrace = owner.debugLifecycleTrace
        traceGeneration = owner.debugTraceGeneration
        #endif
    }

    #if DEBUG
    private let lifecycleTrace: PlaybackLifecycleTrace?
    private let traceGeneration: Int
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

    func mediaPlayerStopping(reason: AetherVLCMediaStoppingReason, inputTime: Int64, hadError: Bool) {
        let token = sessionID
        #if DEBUG
        let generation = traceGeneration
        let occurrence = lifecycleTrace?.record(.callbackStopping, generation: generation,
            state: Int(reason.rawValue), time: inputTime, accepted: !hadError)
        #endif
        Task { @MainActor [weak owner] in
            #if DEBUG
            owner?.debugRecordLifecycle(.deliveryStopping, generation: generation, sourceSequence: occurrence,
                state: Int(reason.rawValue), time: inputTime, accepted: !hadError)
            #endif
            owner?.receiveStoppingReason(reason, inputTime: inputTime, hadError: hadError, token: token)
        }
    }

    func mediaPlayerClockPoint(time: Int64, position: Double, systemDate: Int64) {
        let token = sessionID
        #if DEBUG
        let generation = traceGeneration
        let occurrence = lifecycleTrace?.record(.callbackClock, generation: generation, time: time, systemDate: systemDate)
        #endif
        Task { @MainActor [weak owner] in
            #if DEBUG
            // Existing statistics are read after the C callback has returned,
            // on MainActor and before entering the trace's primitive-value lock.
            let displayed = owner?.displayedVideoFrames
            let played = owner?.playedAudioBuffers
            owner?.debugRecordLifecycle(.deliveryClock, generation: generation, sourceSequence: occurrence,
                time: time, systemDate: systemDate, displayed: displayed, played: played)
            #endif
            owner?.receiveClockPoint(time, position: position, systemDate: systemDate, token: token)
        }
    }

    func mediaPlayerInputPositionChanged(time: Int64, position: Double) {
        let token = sessionID
        #if DEBUG
        let generation = traceGeneration
        let occurrence = lifecycleTrace?.record(.callbackInput, generation: generation, time: time)
        #endif
        Task { @MainActor [weak owner] in
            #if DEBUG
            owner?.debugRecordLifecycle(.deliveryInput, generation: generation, sourceSequence: occurrence, time: time)
            #endif
            owner?.receiveInputTime(time, position: position, token: token)
        }
    }

    func mediaPlayerSeekingChanged(_ seeking: Bool, targetTime: Int64, sequence: UInt64) {
        let token = sessionID
        Task { @MainActor [weak owner] in
            owner?.receiveSeeking(seeking, targetTime: targetTime, sequence: sequence, token: token)
        }
    }

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
        #if DEBUG
        let generation = traceGeneration
        let occurrence = lifecycleTrace?.record(.callbackState, generation: generation, state: Int(newState.rawValue))
        #endif
        Task { @MainActor [weak owner] in
            #if DEBUG
            owner?.debugRecordLifecycle(.deliveryState, generation: generation, sourceSequence: occurrence, state: Int(newState.rawValue))
            #endif
            owner?.receive(state: newState, token: token)
            #if DEBUG
            owner?.debugRecordLifecycle(.appliedState, generation: generation, sourceSequence: occurrence, state: Int(newState.rawValue))
            #endif
        }
    }

    func mediaPlayerTimeChanged(_ notification: Notification) {
        let token = sessionID
        #if DEBUG
        lifecycleTrace?.record(.callbackTime, generation: traceGeneration)
        #endif
        Task { @MainActor [weak owner] in owner?.receiveTime(token: token) }
    }

    func mediaPlayerBufferingChanged(_ progress: Float) {
        let token = sessionID
        #if DEBUG
        lifecycleTrace?.record(.callbackBuffering, generation: traceGeneration, target: progress.isFinite ? Double(progress) : nil)
        #endif
        Task { @MainActor [weak owner] in owner?.receiveBuffering(progress, token: token) }
    }

    func mediaPlayerLengthChanged(_ length: Int64) {
        let token = sessionID
        #if DEBUG
        lifecycleTrace?.record(.callbackLength, generation: traceGeneration, time: length)
        #endif
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
