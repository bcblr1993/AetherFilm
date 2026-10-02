import SwiftUI

struct StatePlaceholder: View {
    let title: String
    let symbol: String
    let description: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var identifier: String? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
                .accessibilityIdentifier(identifier ?? "state.placeholder")
        } description: {
            Text(description)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier(identifier.map { $0 + ".action" } ?? "state.action")
            }
        }
    }
}
