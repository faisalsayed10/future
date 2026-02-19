import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Messages Yet", systemImage: "tray")
        } description: {
            Text("Share a link from any app and send it to your future self.")
        }
    }
}
