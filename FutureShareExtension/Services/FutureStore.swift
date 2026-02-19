import Foundation

class FutureStore {
    static let shared = FutureStore()

    private let defaults: UserDefaults
    private let key = "futureItems"

    init() {
        defaults = UserDefaults(suiteName: "group.com.fsayed.Future") ?? .standard
    }

    var items: [FutureItem] {
        get {
            guard let data = defaults.data(forKey: key) else { return [] }
            return (try? JSONDecoder().decode([FutureItem].self, from: data)) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            defaults.set(data, forKey: key)
        }
    }

    func add(_ item: FutureItem) {
        var current = items
        current.append(item)
        items = current
    }

    func markRead(_ id: UUID) {
        var current = items
        if let index = current.firstIndex(where: { $0.id == id }) {
            current[index].isRead = true
            items = current
        }
    }

    func delete(_ id: UUID) {
        var current = items
        current.removeAll { $0.id == id }
        items = current
    }
}
