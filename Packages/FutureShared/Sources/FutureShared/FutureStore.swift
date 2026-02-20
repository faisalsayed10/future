import Foundation

@MainActor
public class FutureStore {
    public static let shared = FutureStore()

    private let defaults: UserDefaults
    private let key = "futureItems"

    public init() {
        defaults = UserDefaults(suiteName: "group.com.fsayed.Future") ?? .standard
    }

    public var items: [FutureItem] {
        get {
            guard let data = defaults.data(forKey: key) else { return [] }
            return (try? JSONDecoder().decode([FutureItem].self, from: data)) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            defaults.set(data, forKey: key)
        }
    }

    public func add(_ item: FutureItem) {
        var current = items
        current.append(item)
        items = current
    }

    public func markRead(_ id: UUID) {
        var current = items
        if let index = current.firstIndex(where: { $0.id == id }) {
            current[index].isRead = true
            items = current
        }
    }

    public func delete(_ id: UUID) {
        var current = items
        current.removeAll { $0.id == id }
        items = current
        ThumbnailStore.shared.delete(for: id)
    }

    public func snooze(_ id: UUID, to newDate: Date) {
        var current = items
        if let index = current.firstIndex(where: { $0.id == id }) {
            let old = current[index]
            current[index] = FutureItem(
                id: old.id,
                url: old.url,
                title: old.title,
                note: old.note,
                createdAt: old.createdAt,
                deliverAt: newDate,
                isRead: false,
                labels: old.labels
            )
            items = current
        }
    }

    public func updateLabels(_ id: UUID, labels: [String]) {
        var current = items
        if let index = current.firstIndex(where: { $0.id == id }) {
            current[index].labels = labels
            items = current
        }
    }
}
