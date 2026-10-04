#if DEBUG && os(macOS)
import AppKit
import SwiftUI

/// Applies an actual window size so restored geometry cannot bypass a UI layout test.
struct UITestWindowSizing: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { SizingView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class SizingView: NSView {
        private var hasAppliedSize = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard !hasAppliedSize, let window,
                  ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
            // SwiftUI restores scene geometry as the window becomes visible.
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window, self.window === window,
                      !self.hasAppliedSize, window.isVisible else { return }
                let width = self.requestedDimension("--ui-width=", fallback: 980, minimum: 620)
                let height = self.requestedDimension("--ui-height=", fallback: 680, minimum: 440)
                window.setContentSize(NSSize(width: width, height: height))
                window.center()
                self.hasAppliedSize = true
            }
        }

        private func requestedDimension(_ prefix: String, fallback: Double, minimum: Double) -> Double {
            guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
                  let value = Double(argument.dropFirst(prefix.count)), value.isFinite, value > 0 else {
                return fallback
            }
            return max(minimum, value)
        }
    }
}
#endif
