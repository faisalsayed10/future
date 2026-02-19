import Foundation

public struct FutureItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let url: String
    public let title: String?
    public let note: String?
    public let createdAt: Date
    public let deliverAt: Date
    public var isRead: Bool
    public var labels: [String]

    public var isDelivered: Bool { !isNeverDeliver && Date() >= deliverAt }
    public var isNeverDeliver: Bool { deliverAt == .distantFuture }
    public var domain: String? { URL(string: url)?.host }

    public init(
        id: UUID,
        url: String,
        title: String?,
        note: String?,
        createdAt: Date,
        deliverAt: Date,
        isRead: Bool,
        labels: [String] = []
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.note = note
        self.createdAt = createdAt
        self.deliverAt = deliverAt
        self.isRead = isRead
        self.labels = labels
    }

    // Backwards-compatible decoder: labels defaults to [] if missing
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(String.self, forKey: .url)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        deliverAt = try container.decode(Date.self, forKey: .deliverAt)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        labels = try container.decodeIfPresent([String].self, forKey: .labels) ?? []
    }
}
