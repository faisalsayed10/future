import SwiftUI
import Foundation

struct ItemRow: View {
    let item: FutureItem

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.isRead ? Color.clear : Color.accentColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? item.domain ?? "Link")
                    .font(.headline)
                    .lineLimit(2)

                Text(item.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let note = item.note {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(timeDescription)
                    .font(.caption2)
                    .foregroundStyle(item.isDelivered ? Color.secondary : Color.accentColor)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var timeDescription: String {
        if item.isDelivered {
            return "Arrived \(item.deliverAt.formatted(.relative(presentation: .named)))"
        } else {
            return "Arriving \(item.deliverAt.formatted(.relative(presentation: .named)))"
        }
    }
}
