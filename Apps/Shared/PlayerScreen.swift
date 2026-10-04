import SwiftUI
import UniformTypeIdentifiers
import FilmDomain
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct PlayerScreen: View {
    let item: MediaItem
    let store: AppStore
    @State private var player = FilmPlayer()
    @State private var openingError: String?
    @State private var subtitleError: String?
    @State private var subtitles: [MediaItem] = []
    @State private var playbackSessionID: UUID?
    @State private var showingSubtitlePicker = false
    @State private var showingOptions = false
    @State private var isScrubbing = false
    @State private var scrubPosition: Double = 0
    @State private var gesturePosition: Double?
    @State private var gestureVolume: Float?
    @State private var controlsVisible = true
    @State private var controlsInteraction = 0
    #if os(iOS)
    @State private var gestureBrightness: CGFloat?
    #endif
    @AppStorage("preferredAudioLanguage") private var preferredAudioLanguage = ""
    @AppStorage("preferredSubtitleLanguage") private var preferredSubtitleLanguage = ""
    @AppStorage("preferredPlaybackRate") private var preferredPlaybackRate = 1.0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                PlayerSurface(player: player)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Rectangle()
                    .fill(Color.clear)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("视频画面")
                    .accessibilityIdentifier("player.surface")
                    .gesture(SpatialTapGesture(count: 2).onEnded { value in
                        revealControls()
                        player.seek(player.position + (value.location.x < geometry.size.width / 2 ? -10 : 10))
                    }.exclusively(before: TapGesture().onEnded {
                        if player.seekStatus != nil {
                            revealControls()
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) { controlsVisible.toggle() }
                            controlsInteraction += 1
                        }
                    }))
                    .accessibilityAction(named: "显示播放控制") { revealControls() }
                    .simultaneousGesture(scrubbingGesture(width: geometry.size.width))
                VStack {
                    if showsControls {
                        header
                            .transition(.opacity)
                    }
                    Spacer()
                    if let error = openingError ?? store.playbackErrorMessage ?? player.errorMessage {
                        VStack(spacing: 14) {
                            Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                            Text(error).multilineTextAlignment(.center)
                            Button("重新播放") { Task { await open() } }.buttonStyle(.glassProminent)
                        }
                        .padding(24)
                        .glassEffect(in: .rect(cornerRadius: 24))
                        .accessibilityIdentifier("player.error")
                        Spacer()
                    } else if let status = player.seekStatus {
                        ProgressView(status == .seeking ? "正在跳转…" : "正在等待片源…")
                            .padding(20)
                            .glassEffect()
                            .accessibilityIdentifier("player.seekStatus")
                        Spacer()
                    } else if player.isLoading {
                        ProgressView("正在打开视频…")
                            .padding(20)
                            .glassEffect()
                            .accessibilityIdentifier("player.loading")
                        Spacer()
                    }
                    if showsControls {
                        controls
                            .transition(.opacity)
                    }
                }
                .padding(16)
            }
        }
        .preferredColorScheme(.dark)
        .tint(.mint)
        #if os(iOS)
        .statusBarHidden(!showsControls)
        .persistentSystemOverlays(showsControls ? .automatic : .hidden)
        #endif
        #if os(macOS)
        .frame(minWidth: 620, minHeight: 400, idealHeight: 620)
        #endif
        .task(id: item.id) { await open() }
        .task(id: "\(controlsInteraction)-\(player.isPlaying)-\(showingOptions)-\(isScrubbing)-\(voiceOverEnabled)-\(player.seekStatus != nil)") {
            guard player.isPlaying, player.seekStatus == nil, !showingOptions, !isScrubbing, !voiceOverEnabled else { return }
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            guard !Task.isCancelled, player.isPlaying, player.seekStatus == nil, openingError == nil, store.playbackErrorMessage == nil, player.errorMessage == nil else { return }
            withAnimation(.easeInOut(duration: 0.2)) { controlsVisible = false }
        }
        .onChange(of: player.isPlaying) { _, playing in if !playing { revealControls() } }
        .onChange(of: player.seekStatus) { _, status in if status != nil { revealControls() } }
        .onChange(of: player.errorMessage) { _, message in if message != nil { revealControls() } }
        .onChange(of: store.playbackErrorMessage) { _, message in
            if message != nil { player.stop(); revealControls() }
        }
        .onChange(of: player.subtitleErrorMessage) { _, message in
            if let message { subtitleError = message; revealControls() }
        }
        .onChange(of: showingOptions) { _, _ in revealControls() }
        .onDisappear(perform: stopPlaybackOnDisappear)
        .onChange(of: scenePhase) { _, phase in
            #if os(iOS)
            if phase == .background { player.pause() }
            #endif
            if phase != .active { Task { await store.flushProgress() } }
        }
        .fileImporter(isPresented: $showingSubtitlePicker,
                      allowedContentTypes: [.plainText, UTType(filenameExtension: "srt") ?? .data,
                                            UTType(filenameExtension: "ass") ?? .data, UTType(filenameExtension: "vtt") ?? .data],
                      onCompletion: handleSubtitleImport)
        .sheet(isPresented: $showingOptions) { playbackOptions }
        .alert("无法打开字幕", isPresented: Binding(get: { subtitleError != nil }, set: { if !$0 { subtitleError = nil } })) {
            Button("好", role: .cancel) { subtitleError = nil }
        } message: { Text(subtitleError ?? "") }
    }

    private func handleSubtitleImport(_ result: Result<URL, Error>) {
        if case .success(let url) = result { player.addSubtitle(url) }
    }

    private func stopPlaybackOnDisappear() {
        let sessionID = playbackSessionID
        player.stop()
        Task {
            await store.flushProgress()
            if let sessionID { await store.stopStreaming(for: item.id, sessionID: sessionID) }
        }
    }

    private var showsControls: Bool { controlsVisible || player.seekStatus != nil }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                guard store.playingItem?.id == item.id else { return }
                let sessionID = playbackSessionID
                player.stop()
                store.playingItem = nil
                #if os(iOS)
                dismiss()
                #endif
                Task {
                    await store.flushProgress()
                    if let sessionID { await store.stopStreaming(for: item.id, sessionID: sessionID) }
                }
            } label: { Image(systemName: "xmark").frame(width: 44, height: 44).contentShape(Rectangle()) }
            .buttonStyle(.glass)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("关闭播放器")
            .accessibilityIdentifier("player.close")
            Text(item.title).font(.headline).lineLimit(1)
            Spacer(minLength: 0)
            Button { showingOptions = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44).contentShape(Rectangle()) }
                .buttonStyle(.glass)
                .accessibilityLabel("字幕、音轨与播放设置")
                .accessibilityIdentifier("player.options")
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 22))
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Slider(value: Binding(get: { isScrubbing ? scrubPosition : player.position },
                                  set: { scrubPosition = $0 }), in: 0...max(1, player.duration)) { editing in
                revealControls()
                if editing { scrubPosition = player.position }
                isScrubbing = editing
                if !editing { player.seek(scrubPosition) }
            }
            .disabled(!player.isSeekable)
            .accessibilityLabel("播放进度")
            .accessibilityValue(time(isScrubbing ? scrubPosition : player.position))
            .accessibilityIdentifier("player.seek")
            HStack {
                Text(time(isScrubbing ? scrubPosition : player.position)).monospacedDigit()
                    .accessibilityIdentifier("player.time")
                Spacer()
                Text(time(player.duration)).monospacedDigit().foregroundStyle(.secondary)
                    .accessibilityIdentifier("player.duration")
            }.font(.caption)
            HStack(spacing: 4) {
                Button { revealControls(); player.seek(player.position - 10) } label: { Image(systemName: "gobackward.10").frame(width: 44, height: 44).contentShape(Rectangle()) }
                    .accessibilityLabel("后退十秒").keyboardShortcut(.leftArrow, modifiers: [])
                Button { revealControls(); player.toggle(); Task { await store.flushProgress() } } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title2).frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
                .accessibilityValue(player.isPlaying ? "正在播放" : "已暂停")
                .accessibilityIdentifier("player.playPause")
                .keyboardShortcut(.space, modifiers: [])
                Button { revealControls(); player.seek(player.position + 10) } label: { Image(systemName: "goforward.10").frame(width: 44, height: 44).contentShape(Rectangle()) }
                    .accessibilityLabel("前进十秒").keyboardShortcut(.rightArrow, modifiers: [])
                Spacer(minLength: 0)
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0], id: \.self) { rate in
                        Button(String(format: "%g×", rate)) { revealControls(); preferredPlaybackRate = rate; player.setRate(Float(rate)) }
                    }
                } label: { Text(String(format: "%g×", player.rate)).font(.subheadline.monospacedDigit()).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
                .accessibilityLabel("播放速度")
                .accessibilityValue(String(format: "%g倍", player.rate))
                .accessibilityIdentifier("player.rate")
                .simultaneousGesture(TapGesture().onEnded { revealControls() })
                if store.nextItem(after: item) != nil {
                    Button { Task { await store.playNext(after: item) } } label: { Image(systemName: "forward.end.fill").frame(width: 44, height: 44).contentShape(Rectangle()) }
                        .accessibilityLabel("下一个视频").accessibilityIdentifier("player.next")
                }
                #if os(macOS)
                Button { revealControls(); NSApp.keyWindow?.toggleFullScreen(nil) } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("切换全屏")
                .accessibilityIdentifier("player.fullscreen")
                .keyboardShortcut("f", modifiers: [.control, .command])
                #endif
            }
            .buttonStyle(.plain)
            .font(.title3)
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 24))
    }

    private var playbackOptions: some View {
        NavigationStack {
            Form {
                Section("音轨") {
                    ForEach(player.audioTracks) { track in
                        Button { player.selectAudio(track.id) } label: {
                            HStack { Text(track.name); Spacer(); if player.selectedAudioID == track.id { Image(systemName: "checkmark") } }
                        }
                    }
                    if player.audioTracks.isEmpty { Text("这个视频没有可选音轨").foregroundStyle(.secondary) }
                }
                Section("字幕") {
                    Button("关闭字幕") { player.selectSubtitle(nil) }
                    ForEach(player.subtitleTracks) { track in
                        Button { player.selectSubtitle(track.id) } label: {
                            HStack { Text(track.name); Spacer(); if player.selectedSubtitleID == track.id { Image(systemName: "checkmark") } }
                        }
                    }
                    ForEach(subtitles) { subtitle in
                        Button(subtitle.name) {
                            Task {
                                do { player.addSubtitle(try await store.subtitleURL(subtitle)) }
                                catch is CancellationError { }
                                catch { subtitleError = "请检查字幕文件和 NAS 连接。" }
                            }
                        }
                    }
                    Button("选择外置字幕…") { showingOptions = false; showingSubtitlePicker = true }
                    Stepper("字幕延迟：\(player.subtitleDelay, specifier: "%.1f") 秒", value:
                        Binding(get: { player.subtitleDelay }, set: { player.setSubtitleDelay($0) }), in: -10...10, step: 0.5)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("字幕大小").accessibilityHidden(true)
                        Slider(value: Binding(get: { Double(player.subtitleScale) }, set: { player.setSubtitleScale(Float($0)) }), in: 0.5...2)
                            .accessibilityLabel("字幕大小")
                    }
                }
                if !player.chapters.isEmpty {
                    Section("章节") {
                        ForEach(player.chapters) { chapter in
                            Button(chapter.name) { player.selectChapter(chapter.id); showingOptions = false }
                        }
                    }
                }
                Section("画面和声音") {
                    Toggle("填满画面", isOn: Binding(get: { player.fillsScreen }, set: { player.setVideoFill($0) }))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("音量").accessibilityHidden(true)
                        Slider(value: Binding(get: { Double(player.volume) }, set: { player.setVolume(Float($0)) }), in: 0...1)
                            .accessibilityLabel("音量")
                    }
                }
                Section("默认语言") {
                    Picker("音轨", selection: $preferredAudioLanguage) { languageChoices }
                    Picker("字幕", selection: $preferredSubtitleLanguage) { languageChoices }
                    Text("默认语言在下次打开视频时使用，当前视频可直接选择上面的轨道。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("播放设置")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("完成") { showingOptions = false }.accessibilityIdentifier("player.options.done")
            } }
        }
        #if os(macOS)
        .frame(width: 430, height: 500)
        #endif
    }

    private func open() async {
        revealControls()
        openingError = nil
        subtitleError = nil
        player.stop()
        player.setRate(Float(preferredPlaybackRate))
        player.setPreferredLanguages(audio: preferredAudioLanguage.isEmpty ? nil : preferredAudioLanguage,
            subtitles: preferredSubtitleLanguage.isEmpty ? nil : preferredSubtitleLanguage)
        player.onProgress = nil
        player.onPlaybackSessionStarted = nil
        player.onPlaybackFailure = nil
        player.onEnded = nil
        player.completionValidator = nil
        var preparedSessionID: UUID?
        do {
            let source = try await store.preparePlayback(item)
            let sessionID = source.sessionID
            preparedSessionID = sessionID
            try Task.checkCancellation()
            guard store.playbackSession(for: item) == sessionID, store.playingItem?.id == item.id else { throw CancellationError() }
            playbackSessionID = sessionID
            player.onPlaybackSessionStarted = { store.beginPlaybackProgress(item, sessionID: sessionID) }
            player.onProgress = { position, duration, confirmed in
                store.recordProgress(item, position: position, duration: duration,
                    allowsAutomaticWatched: confirmed, sessionID: sessionID)
            }
            player.onPlaybackFailure = { store.rejectAutomaticWatched(item, sessionID: sessionID) }
            player.completionValidator = { await store.canCompletePlayback(after: item, sessionID: sessionID) }
            player.onEnded = { Task { await store.completePlayback(after: item, sessionID: sessionID) } }
            player.load(url: source.url, startAt: store.progress(for: item)?.resumePosition ?? 0)
            subtitles = (try? await store.subtitleCandidates(for: item)) ?? []
            try Task.checkCancellation()
            guard store.playbackSession(for: item) == sessionID, store.playingItem?.id == item.id else { throw CancellationError() }
            let base = (item.name as NSString).deletingPathExtension.lowercased()
            if let match = subtitles.first(where: { ($0.name as NSString).deletingPathExtension.lowercased() == base }) {
                if let url = try? await store.subtitleURL(match) {
                    try Task.checkCancellation()
                    guard store.playbackSession(for: item) == sessionID, store.playingItem?.id == item.id else { throw CancellationError() }
                    player.addSubtitle(url)
                }
            }
        } catch is CancellationError {
            if let preparedSessionID { await store.stopStreaming(for: item.id, sessionID: preparedSessionID) }
        }
        catch { openingError = error.localizedDescription }
    }

    private func scrubbingGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20).onChanged { value in
            controlsVisible = true
            if abs(value.translation.width) > abs(value.translation.height) {
                if gesturePosition == nil { gesturePosition = player.position }
                scrubPosition = max(0, min(player.duration, (gesturePosition ?? 0) + value.translation.width / max(1, width) * player.duration))
                isScrubbing = true
            } else {
                #if os(iOS)
                if value.startLocation.x < width / 2,
                   let screen = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.screen {
                    if gestureBrightness == nil { gestureBrightness = screen.brightness }
                    screen.brightness = min(1, max(0.05, (gestureBrightness ?? 0.5) - value.translation.height / 300))
                } else {
                    if gestureVolume == nil { gestureVolume = player.volume }
                    player.setVolume((gestureVolume ?? 1) - Float(value.translation.height / 300))
                }
                #else
                if gestureVolume == nil { gestureVolume = player.volume }
                player.setVolume((gestureVolume ?? 1) - Float(value.translation.height / 300))
                #endif
            }
        }.onEnded { _ in
            controlsInteraction += 1
            if isScrubbing { player.seek(scrubPosition) }
            isScrubbing = false; gesturePosition = nil; gestureVolume = nil
            #if os(iOS)
            gestureBrightness = nil
            #endif
        }
    }

    private func revealControls() {
        controlsVisible = true
        controlsInteraction += 1
    }

    private func time(_ seconds: Double) -> String {
        let value = Int(seconds.isFinite ? max(0, seconds) : 0)
        return value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
                             : String(format: "%d:%02d", value / 60, value % 60)
    }

    @ViewBuilder private var languageChoices: some View {
        Text("自动").tag("")
        Text("中文").tag("zh,zho,chi")
        Text("英语").tag("en,eng")
        Text("日语").tag("ja,jpn")
        Text("韩语").tag("ko,kor")
    }
}
