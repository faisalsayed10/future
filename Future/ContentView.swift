import SwiftUI
import UIKit

struct ContentView: View {
    @State private var items: [FutureItem] = []

    private var upcomingItems: [FutureItem] {
        items.filter { !$0.isDelivered }.sorted { $0.deliverAt < $1.deliverAt }
    }

    private var deliveredItems: [FutureItem] {
        items.filter { $0.isDelivered }.sorted { $0.deliverAt > $1.deliverAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        if !upcomingItems.isEmpty {
                            Section {
                                ForEach(upcomingItems) { item in
                                    ItemRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture { openItem(item) }
                                }
                                .onDelete { offsets in
                                    deleteItems(from: upcomingItems, at: offsets)
                                }
                            } header: {
                                Label("Arriving Soon", systemImage: "clock")
                            }
                        }
                        if !deliveredItems.isEmpty {
                            Section {
                                ForEach(deliveredItems) { item in
                                    ItemRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture { openItem(item) }
                                }
                                .onDelete { offsets in
                                    deleteItems(from: deliveredItems, at: offsets)
                                }
                            } header: {
                                Label("Delivered", systemImage: "tray.full")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Future")
            .onAppear { loadItems() }
            .refreshable { loadItems() }
        }
    }

    private func loadItems() {
        items = FutureStore.shared.items
    }

    private func openItem(_ item: FutureItem) {
        FutureStore.shared.markRead(item.id)
        if let url = URL(string: item.url) {
            UIApplication.shared.open(url)
        }
        loadItems()
    }

    private func deleteItems(from source: [FutureItem], at offsets: IndexSet) {
        for offset in offsets {
            let item = source[offset]
            NotificationManager.shared.cancelNotification(for: item.id)
            FutureStore.shared.delete(item.id)
        }
        loadItems()
    }
}

#Preview {
    ContentView()
}
