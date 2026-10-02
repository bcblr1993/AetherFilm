import SwiftUI
import VLCKit

public struct PlayerSurface: View {
    private let player: FilmPlayer

    public init(player: FilmPlayer) { self.player = player }

    public var body: some View {
        NativePlayerSurface(player: player)
            .accessibilityLabel("视频画面")
    }
}

#if os(macOS)
private struct NativePlayerSurface: NSViewRepresentable {
    let player: FilmPlayer

    func makeCoordinator() -> Coordinator { Coordinator(player: player) }

    func makeNSView(context: Context) -> VLCVideoView {
        let view = VLCVideoView(frame: .zero)
        view.backColor = .black
        view.fillScreen = false
        player.attachDrawable(view)
        return view
    }

    func updateNSView(_ view: VLCVideoView, context: Context) { player.attachDrawable(view) }

    static func dismantleNSView(_ view: VLCVideoView, coordinator: Coordinator) {
        coordinator.player?.detachDrawable(view)
    }

    final class Coordinator {
        weak var player: FilmPlayer?
        init(player: FilmPlayer) { self.player = player }
    }
}
#elseif os(iOS)
private struct NativePlayerSurface: UIViewRepresentable {
    let player: FilmPlayer

    func makeCoordinator() -> Coordinator { Coordinator(player: player) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        player.attachDrawable(view)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) { player.attachDrawable(view) }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.player?.detachDrawable(view)
    }

    final class Coordinator {
        weak var player: FilmPlayer?
        init(player: FilmPlayer) { self.player = player }
    }
}
#endif
