import SwiftUI
import UIKit
import FutureShared

struct ContentView: View {
    @State private var items: [FutureItem] = []
    @State private var notificationItem: FutureItem?
    @State private var startInSnoozeMode = false
    @State private var showMacSetup = false
    @AppStorage("hasSeenMacSetup") private var hasSeenMacSetup = false

    private var upcomingItems: [FutureItem] {
        items.filter { !$0.isDelivered && !$0.isNeverDeliver }.sorted { $0.deliverAt < $1.deliverAt }
    }

    private var deliveredItems: [FutureItem] {
        items.filter { $0.isDelivered }.sorted { $0.deliverAt > $1.deliverAt }
    }

    private var savedItems: [FutureItem] {
        items.filter { $0.isNeverDeliver }.sorted { $0.createdAt > $1.createdAt }
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
                        if !savedItems.isEmpty {
                            Section {
                                ForEach(savedItems) { item in
                                    ItemRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture { openItem(item) }
                                }
                                .onDelete { offsets in
                                    deleteItems(from: savedItems, at: offsets)
                                }
                            } header: {
                                Label("Saved", systemImage: "bookmark")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Future")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showMacSetup = true
                    } label: {
                        Image(systemName: "macbook.and.iphone")
                    }
                }
            }
            .onAppear {
                loadItems()
                labelUnlabeledItems()
                if !hasSeenMacSetup {
                    showMacSetup = true
                }
            }
            .refreshable {
                loadItems()
                labelUnlabeledItems()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showNotificationDetail)) { notification in
                guard let idString = notification.userInfo?["itemId"] as? String,
                      let id = UUID(uuidString: idString) else { return }
                let snooze = notification.userInfo?["snooze"] as? Bool ?? false

                loadItems()

                if let item = FutureStore.shared.items.first(where: { $0.id == id }) {
                    startInSnoozeMode = snooze
                    notificationItem = item
                }
            }
            .sheet(isPresented: $showMacSetup) {
                MacSetupView {
                    hasSeenMacSetup = true
                    showMacSetup = false
                }
            }
            .sheet(item: $notificationItem) { item in
                NotificationSheet(
                    item: item,
                    startInSnoozeMode: startInSnoozeMode,
                    onOpen: {
                        FutureStore.shared.markRead(item.id)
                        if let url = URL(string: item.url) {
                            UIApplication.shared.open(url)
                        }
                        notificationItem = nil
                        loadItems()
                    },
                    onSnooze: { newDate, isNever in
                        if isNever {
                            FutureStore.shared.snooze(item.id, to: .distantFuture)
                        } else {
                            FutureStore.shared.snooze(item.id, to: newDate)
                            NotificationManager.shared.scheduleNotification(
                                for: FutureItem(
                                    id: item.id,
                                    url: item.url,
                                    title: item.title,
                                    note: item.note,
                                    createdAt: item.createdAt,
                                    deliverAt: newDate,
                                    isRead: false,
                                    labels: item.labels
                                )
                            )
                        }
                        notificationItem = nil
                        loadItems()
                    },
                    onDismiss: {
                        notificationItem = nil
                    }
                )
            }
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

    private func labelUnlabeledItems() {
        let unlabeled = items.filter { $0.labels.isEmpty }
        for item in unlabeled {
            Task {
                let labels = await LabelGenerator.shared.generateLabels(for: item)
                if !labels.isEmpty {
                    FutureStore.shared.updateLabels(item.id, labels: labels)
                    loadItems()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
