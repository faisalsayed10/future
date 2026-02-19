import Foundation

struct FutureItem: Identifiable, Codable, Equatable {
    let id: UUID
    let url: String
    let title: String?
    let note: String?
    let createdAt: Date
    let deliverAt: Date
    var isRead: Bool

    var isDelivered: Bool {
        Date() >= deliverAt
    }

    var domain: String? {
        URL(string: url)?.host
    }
}
