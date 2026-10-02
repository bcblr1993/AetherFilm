import SwiftUI

@main struct AetherFilmApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        #if os(macOS)
        Window("AetherFilm", id: "main") { appContent }
            .defaultSize(width: requestedDimension("--ui-width=", defaultValue: 980),
                         height: requestedDimension("--ui-height=", defaultValue: 680))
            .windowStyle(.automatic)
        #else
        WindowGroup { appContent }
        #endif
    }

    private var appContent: some View {
        RootView(store: store)
            .tint(.teal)
            .task { await store.load() }
            .onOpenURL { url in Task { await store.importFiles([url]) } }
            #if DEBUG
            .modifier(UITestAppearance())
            #endif
            #if os(macOS)
            .frame(minWidth: 620, minHeight: 440)
            #endif
    }

    private func requestedDimension(_ prefix: String, defaultValue: Double) -> Double {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
           let value = Double(argument.dropFirst(prefix.count)), value > 0 { return value }
        #endif
        return defaultValue
    }
}

#if DEBUG
private struct UITestAppearance: ViewModifier {
    private let args = ProcessInfo.processInfo.arguments
    func body(content: Content) -> some View {
        if args.contains("--ui-testing") {
            content
                .defaultAppStorage(testPreferences)
                .preferredColorScheme(args.contains("--ui-appearance=dark") ? .dark : args.contains("--ui-appearance=light") ? .light : nil)
                .dynamicTypeSize(args.contains("--ui-content-size=accessibility3") || args.contains("--ui-content-size=accessibility-extra-extra-extra-large") ? .accessibility3 : .large)
        } else { content }
    }

    private var testPreferences: UserDefaults {
        let prefix = "--ui-test-session="
        let session = args.first(where: { $0.hasPrefix(prefix) })?
            .dropFirst(prefix.count).filter { $0.isLetter || $0.isNumber || $0 == "-" }
            ?? "process-\(ProcessInfo.processInfo.processIdentifier)"
        return UserDefaults(suiteName: "AetherFilmUITests.\(session)")!
    }
}
#endif
