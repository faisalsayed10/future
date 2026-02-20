import SwiftUI
import FutureShared

struct ItemRow: View {
    let item: FutureItem

    @State private var thumbnail: UIImage?

    private static let labelColors: [Color] = [
        .blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    fallbackThumbnail
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                // Labels row (only if labels exist)
                if !item.labels.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(item.labels, id: \.self) { label in
                            Text(label)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(colorForLabel(label).opacity(0.12))
                                .foregroundStyle(colorForLabel(label))
                                .clipShape(Capsule())
                        }
                        Spacer()
                        Text(compactTime)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(timeColor)
                    }
                }

                // Title + time (inline when no labels)
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title ?? item.domain ?? "Link")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    if item.labels.isEmpty {
                        Spacer()
                        Text(compactTime)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(timeColor)
                    }
                }

                // Domain
                if let domain = item.domain {
                    Text(domain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
        .task(id: item.id) {
            thumbnail = ThumbnailStore.shared.load(for: item.id)
        }
    }

    // MARK: - Fallback Thumbnail

    @ViewBuilder
    private var fallbackThumbnail: some View {
        let initial = item.domain?.first.map(String.init)?.uppercased()
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
            if let initial {
                Text(initial)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func colorForLabel(_ label: String) -> Color {
        let hash = abs(label.hashValue)
        return Self.labelColors[hash % Self.labelColors.count]
    }

    private var compactTime: String {
        if item.isNeverDeliver {
            return "\u{00AF}\\_(ツ)_/\u{00AF}"
        }
        let now = Date()
        let interval = item.deliverAt.timeIntervalSince(now)
        if interval <= 0 {
            let elapsed = abs(interval)
            if elapsed < 3600 { return "\(max(1, Int(elapsed / 60)))m ago" }
            if elapsed < 86400 { return "\(Int(elapsed / 3600))h ago" }
            return "\(Int(elapsed / 86400))d ago"
        }
        if interval < 3600 { return "in \(max(1, Int(interval / 60)))m" }
        if interval < 86400 { return "in \(Int(interval / 3600))h" }
        return "in \(Int(interval / 86400))d"
    }

    private var timeColor: Color {
        if item.isNeverDeliver || item.isDelivered { return .secondary }
        return .orange
    }
}
