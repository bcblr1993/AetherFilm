#if os(macOS)
import AppKit
import SwiftUI

/// Adds context only to this view’s native window, split-column, or section host.
/// Native children and roles remain owned by SwiftUI.
@MainActor
struct NativeAccessibilityContext: NSViewRepresentable {
    enum Scope { case windowContent, splitColumn, sectionHeader }
    var label: String
    var scope: Scope

    func makeNSView(context: Context) -> ContextView {
        let view = ContextView()
        view.setAccessibilityElement(false)
        view.updateContext(label: label, scope: scope)
        return view
    }

    func updateNSView(_ nsView: ContextView, context: Context) {
        nsView.updateContext(label: label, scope: scope)
    }

    static func dismantleNSView(_ nsView: ContextView, coordinator: ()) {
        nsView.cancelPendingUpdates()
    }

    final class ContextView: NSView {
        private var contextLabel = ""
        private var scope: Scope = .windowContent
        private var active = false
        private var generation = 0

        func updateContext(label: String, scope: Scope) {
            contextLabel = label
            self.scope = scope
            active = true
            applyContextLabel()
            scheduleApplication()
        }

        func cancelPendingUpdates() {
            active = false
            generation += 1
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            scheduleApplication()
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            scheduleApplication()
        }

        private func scheduleApplication() {
            generation += 1
            let scheduledGeneration = generation
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active, self.generation == scheduledGeneration else { return }
                self.applyContextLabel()
            }
        }

        private func targetView() -> NSView? {
            guard let ownWindow = window else { return nil }
            switch scope {
            case .windowContent:
                guard let content = ownWindow.contentView,
                      content.accessibilityRole() == .group else { return nil }
                return content
            case .splitColumn, .sectionHeader:
                var previous: NSView = self
                var current = superview
                var nearestGroup: NSView?
                var accessibleGroupCount = 0
                var depth = 0
                while let view = current, depth < 32 {
                    guard view.window === ownWindow else { return nil }
                    if let split = view as? NSSplitView {
                        guard split.arrangedSubviews.contains(where: { $0 === previous }),
                              let candidate = nearestGroup,
                              scope != .sectionHeader || accessibleGroupCount >= 2,
                              candidate !== ownWindow.contentView,
                              candidate.window === ownWindow,
                              candidate === previous || candidate.isDescendant(of: previous) else { return nil }
                        return candidate
                    }
                    if view.isAccessibilityElement(), view.accessibilityRole() == .group {
                        accessibleGroupCount += 1
                        if nearestGroup == nil { nearestGroup = view }
                    }
                    if view === ownWindow.contentView { return nil }
                    previous = view
                    current = view.superview
                    depth += 1
                }
                return nil
            }
        }

        private func applyContextLabel() {
            guard active, let target = targetView(),
                  target.accessibilityLabel() != contextLabel else { return }
            target.setAccessibilityLabel(contextLabel)
        }
    }
}
#endif
