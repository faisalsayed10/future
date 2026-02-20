import SwiftUI
import UIKit
import FutureShared

struct ContentView: View {
    @State private var items: [FutureItem] = []
    @State private var notificationItem: FutureItem?
    @State private var startInSnoozeMode = false
    @State private var showInlineTitle = false
    @Environment(\.scenePhase) private var scenePhase

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
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("Future")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .padding(.horizontal, 16)

                            ContentUnavailableView {
                                Label("No Messages Yet", systemImage: "tray")
                            } description: {
                                Text("Share a link from any app and send it to your future self.")
                            }
                            .padding(.top, 140)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .refreshable {
                        loadItems()
                        labelUnlabeledItems()
                    }
                } else {
                    List {
                        Text("Future")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                            .onScrollVisibilityChange { visible in
                                showInlineTitle = !visible
                            }
                        if !upcomingItems.isEmpty {
                            ForEach(upcomingItems) { item in
                                ItemRow(item: item)
                                    .contentShape(Rectangle())
                                    .onTapGesture { openItem(item) }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            deleteItem(from: upcomingItems, item: item)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                    }
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        }
                        if !deliveredItems.isEmpty {
                            Section {
                                ForEach(deliveredItems) { item in
                                    ItemRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture { openItem(item) }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                deleteItem(from: deliveredItems, item: item)
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                        }
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                deleteItem(from: savedItems, item: item)
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                        }
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                }
                            } header: {
                                Label("Saved", systemImage: "bookmark")
                            }
                        }
                    }
                    .listStyle(.plain)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if showInlineTitle {
                            VStack(spacing: 0) {
                                Text("Future")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                Divider()
                            }
                            .background(.bar)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: showInlineTitle)
                    .refreshable {
                        loadItems()
                        labelUnlabeledItems()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                loadItems()
                labelUnlabeledItems()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    loadItems()
                }
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

    private func deleteItem(from source: [FutureItem], item: FutureItem) {
        NotificationManager.shared.cancelNotification(for: item.id)
        FutureStore.shared.delete(item.id)
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
