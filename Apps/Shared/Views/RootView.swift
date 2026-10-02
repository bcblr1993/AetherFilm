import FilmDomain
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Bindable var store: AppStore

    @State private var showingImporter = false
    @State private var showingSMBConnection = false
    @State private var searchQuery = ""
    @State private var connectionToRemove: SMBConnection?
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        navigation
            #if DEBUG && os(macOS)
            .background(UITestWindowSizing())
            #endif
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: Self.videoTypes,
                          allowsMultipleSelection: true) { result in
                switch result {
                case let .success(urls):
                    Task { await store.importFiles(urls) }
                case let .failure(error):
                    if (error as NSError).code != NSUserCancelledError {
                        store.errorMessage = "无法打开所选文件，请重新选择。"
                    }
                }
            }
            .sheet(isPresented: $showingSMBConnection) {
                SMBConnectionSheet { draft in
                    try await store.addSMB(draft)
                }
            }
            #if os(iOS)
            .fullScreenCover(item: $store.playingItem) { item in
                PlayerScreen(item: item, store: store)
            }
            #endif
            .confirmationDialog("移除这个 SMB 片源？", isPresented: removingConnection,
                                titleVisibility: .visible, presenting: connectionToRemove) { source in
                Button("移除片源", role: .destructive) {
                    Task { await store.removeConnection(source) }
                    connectionToRemove = nil
                }
            } message: { _ in
                Text("会移除连接和保存的登录信息。NAS 上的视频会保留。")
            }
    }

    @ViewBuilder
    private var navigation: some View {
        #if os(macOS)
        if let item = store.playingItem {
            PlayerScreen(item: item, store: store)
        } else {
            splitNavigation
        }
        #else
        if horizontalSizeClass == .regular {
            splitNavigation
        } else {
            NavigationStack {
                browserContent
                    .navigationTitle(navigationTitle)
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { sourceMenu }
                        ToolbarItem(placement: .topBarTrailing) { addMenu }
                    }
            }
        }
        #endif
    }

    private var splitNavigation: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("AetherFilm")
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            browserContent
                .navigationTitle(navigationTitle)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            showingImporter = true
                        } label: {
                            Label("导入视频", systemImage: "plus")
                        }
                        .help("导入本地视频")
                        .disabled(store.isImporting)
                        .accessibilityIdentifier("library.import")
                        .keyboardShortcut("o", modifiers: .command)

                        Button {
                            showingSMBConnection = true
                        } label: {
                            Label("连接 SMB", systemImage: "externaldrive.badge.plus")
                        }
                        .help("连接 NAS 上的 SMB 共享")
                        .accessibilityIdentifier("library.connectSMB")
                        .keyboardShortcut("k", modifiers: .command)
                    }
                }
        }
    }

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            Section("观看") {
                Label("本地文件", systemImage: "folder")
                    .tag(AppSection.local)
                    .accessibilityIdentifier("sidebar.local")
                Label("继续观看", systemImage: "play.circle")
                    .tag(AppSection.continueWatching)
                    .accessibilityIdentifier("sidebar.continue")
            }
            Section("NAS") {
                ForEach(store.connections) { source in
                    Label(source.name, systemImage: "externaldrive.connected.to.line.below")
                        .tag(AppSection.smb(source.id))
                        .accessibilityIdentifier("sidebar.smb." + source.id.uuidString)
                        .contextMenu {
                            Button("移除片源", role: .destructive) { connectionToRemove = source }
                        }
                }
                Button {
                    showingSMBConnection = true
                } label: {
                    Label("连接 SMB", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("sidebar.connectSMB")
            }
        }
        .listStyle(.sidebar)
    }

    private var browserContent: some View {
        VStack(spacing: 0) {
            browserHeader
            Divider()

            if store.isImporting && store.displayItems.isEmpty {
                Spacer()
                ProgressView("正在导入视频…")
                    .accessibilityIdentifier("library.importing")
                Spacer()
            } else if store.isLoading && store.displayItems.isEmpty {
                Spacer()
                ProgressView("正在读取目录…")
                    .accessibilityIdentifier("browser.loading")
                Spacer()
            } else if let message = store.errorMessage, store.displayItems.isEmpty {
                StatePlaceholder(title: "暂时无法打开", symbol: "exclamationmark.triangle",
                                 description: message, actionTitle: "重试", action: retry,
                                 identifier: "browser.error")
            } else if store.displayItems.isEmpty {
                emptyContent
            } else if filteredItems.isEmpty {
                StatePlaceholder(title: "没有匹配的文件", symbol: "magnifyingglass",
                                 description: "试试其他关键词。", identifier: "browser.noResults")
            } else {
                fileList
            }
        }
        .searchable(text: $searchQuery, prompt: "筛选当前列表")
        .onChange(of: store.section) { _, _ in searchQuery = "" }
        #if os(macOS)
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        #endif
    }

    private var browserHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: sourceSymbol)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(headerTitle)
                        .font(.headline)
                    Text(headerDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("正在刷新目录")
                } else if store.selectedConnection != nil {
                    Button(action: retry) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("刷新目录")
                    .accessibilityIdentifier("browser.refresh")
                }
                if let source = store.selectedConnection {
                    Menu {
                        Button("移除片源", systemImage: "minus.circle", role: .destructive) {
                            connectionToRemove = source
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("片源选项")
                    .accessibilityIdentifier("browser.sourceOptions")
                }
            }

            if canGoUp {
                Button {
                    let parent = store.currentPath.split(separator: "/").dropLast().joined(separator: "/")
                    Task { await store.browse(path: parent) }
                } label: {
                    Label("上一级", systemImage: "arrow.up")
                        .font(.subheadline)
                }
                .buttonStyle(.glass)
                .disabled(store.isLoading)
                .accessibilityIdentifier("browser.up")
            }

            if store.isImporting && !store.displayItems.isEmpty {
                ProgressView("正在导入视频…")
                    .font(.subheadline)
                    .accessibilityIdentifier("library.importing")
            }

            if let message = store.errorMessage, !store.displayItems.isEmpty {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("browser.inlineError")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fileList: some View {
        List {
            if !folders.isEmpty {
                Section("文件夹") {
                    ForEach(folders) { item in mediaButton(item) }
                }
            }
            if !videos.isEmpty {
                Section(store.section == .continueWatching ? "接着看" : "视频") {
                    ForEach(videos) { item in mediaButton(item) }
                }
            }
        }
        .accessibilityIdentifier("browser.list")
    }

    private func mediaButton(_ item: MediaItem) -> some View {
        Button {
            if item.isDirectory {
                Task { await store.browse(path: item.path) }
            } else {
                Task { await store.play(item) }
            }
        } label: {
            MediaRowView(item: item, progress: store.progress(for: item))
        }
        .buttonStyle(.plain)
        .disabled(store.isLoading)
        .accessibilityHint(item.isDirectory ? "打开文件夹" : "播放视频")
        .contextMenu {
            if !item.isDirectory {
                Button("从头播放", systemImage: "play.fill") {
                    Task {
                        await store.clearProgress(item)
                        await store.play(item)
                    }
                }
                Button("标记为已看", systemImage: "checkmark.circle") {
                    Task { await store.markWatched(item) }
                }
                if store.progress(for: item) != nil {
                    Button("清除观看记录", systemImage: "arrow.counterclockwise") {
                        Task { await store.clearProgress(item) }
                    }
                }
                if item.sourceID == nil {
                    Divider()
                    Button("从本地列表移除", systemImage: "minus.circle", role: .destructive) {
                        Task { await store.removeLocalItem(item) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        switch store.section {
        case .local:
            StatePlaceholder(title: "从一部视频开始", symbol: "play.rectangle",
                             description: "导入本地视频，或连接 NAS 上的 SMB 共享。",
                             actionTitle: "导入视频", action: { showingImporter = true },
                             identifier: "library.empty")
        case .continueWatching:
            StatePlaceholder(title: "还没有观看记录", symbol: "play.circle",
                             description: "播放过的视频会出现在这里，随时接着看。",
                             actionTitle: "打开本地文件", action: {
                                 Task { await store.select(.local) }
                             }, identifier: "continue.empty")
        case .smb:
            StatePlaceholder(title: "这个目录没有视频", symbol: "folder",
                             description: "请选择其他目录，或刷新查看新加入的文件。",
                             actionTitle: "刷新", action: retry, identifier: "browser.empty")
        }
    }

    private var sourceMenu: some View {
        Menu {
            Button("本地文件", systemImage: "folder") { select(.local) }
                .accessibilityIdentifier("source.local")
            Button("继续观看", systemImage: "play.circle") { select(.continueWatching) }
                .accessibilityIdentifier("source.continue")
            if !store.connections.isEmpty {
                Divider()
                ForEach(store.connections) { source in
                    Button(source.name, systemImage: "externaldrive") { select(.smb(source.id)) }
                        .accessibilityIdentifier("source.smb." + source.id.uuidString)
                }
            }
            Divider()
            Button("连接 SMB", systemImage: "plus.circle") { showingSMBConnection = true }
                .accessibilityIdentifier("source.connectSMB")
        } label: {
            Image(systemName: "sidebar.left")
        }
        .accessibilityLabel("选择片源")
        .accessibilityIdentifier("source.menu")
    }

    private var addMenu: some View {
        Menu {
            Button("导入视频", systemImage: "doc.badge.plus") { showingImporter = true }
                .disabled(store.isImporting)
                .accessibilityIdentifier("library.import")
            Button("连接 SMB", systemImage: "externaldrive.badge.plus") { showingSMBConnection = true }
                .accessibilityIdentifier("library.connectSMB")
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("添加视频或片源")
        .accessibilityIdentifier("library.addMenu")
    }

    private var sidebarSelection: Binding<AppSection?> {
        Binding(get: { store.section }, set: { if let section = $0 { select(section) } })
    }

    private var removingConnection: Binding<Bool> {
        Binding(get: { connectionToRemove != nil }, set: { if !$0 { connectionToRemove = nil } })
    }

    private var navigationTitle: String {
        switch store.section {
        case .local: "本地文件"
        case .continueWatching: "继续观看"
        case .smb: store.selectedConnection?.name ?? "SMB"
        }
    }

    private var headerTitle: String {
        if store.selectedConnection != nil {
            return store.currentPath.split(separator: "/").last.map(String.init)
                ?? store.selectedConnection?.share ?? "共享目录"
        }
        return store.section == .continueWatching ? "上次看到这里" : "自己的视频，随时打开"
    }

    private var headerDetail: String {
        if let source = store.selectedConnection {
            let path = store.currentPath.isEmpty ? source.share : source.share + "/" + store.currentPath
            return "SMB · \(path) · \(store.displayItems.count) 个项目"
        }
        if store.section == .continueWatching {
            return "\(store.continueItems.count) 部视频 · 观看进度保存在这台设备"
        }
        return "\(store.localItems.count) 部视频 · 支持本地文件和 SMB NAS"
    }

    private var sourceSymbol: String {
        switch store.section {
        case .local: "folder"
        case .continueWatching: "play.circle"
        case .smb: "externaldrive.connected.to.line.below"
        }
    }

    private var canGoUp: Bool {
        guard let source = store.selectedConnection else { return false }
        return store.currentPath.split(separator: "/").count > source.rootPath.split(separator: "/").count
    }

    private var filteredItems: [MediaItem] {
        store.displayItems.filter {
            ($0.isDirectory || $0.isVideo)
                && (searchQuery.isEmpty || $0.name.localizedStandardContains(searchQuery))
        }
    }

    private var folders: [MediaItem] { filteredItems.filter(\.isDirectory) }
    private var videos: [MediaItem] { filteredItems.filter { !$0.isDirectory } }

    private func select(_ section: AppSection) {
        Task { await store.select(section) }
    }

    private func retry() {
        Task {
            if store.selectedConnection != nil { await store.browse(path: store.currentPath) }
            else { await store.select(store.section) }
        }
    }

    #if os(macOS)
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let files = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !files.isEmpty else { return false }
        Task { @MainActor in
            var urls: [URL] = []
            for provider in files {
                let data: Data? = await withCheckedContinuation { continuation in
                    _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                        continuation.resume(returning: data)
                    }
                }
                if let data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
            }
            guard !urls.isEmpty else {
                store.errorMessage = "无法读取拖入的文件，请使用“导入视频”重新选择。"
                return
            }
            await store.importFiles(urls)
        }
        return true
    }
    #endif

    private static var videoTypes: [UTType] {
        [.movie, .video, .mpeg4Movie, .quickTimeMovie,
         UTType(importedAs: "org.matroska.mkv", conformingTo: .movie)]
    }
}
