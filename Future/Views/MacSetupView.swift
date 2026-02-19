import SwiftUI
import UIKit

struct MacSetupView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "macbook.and.iphone")
                            .font(.system(size: 48))
                            .foregroundStyle(.accent)
                        Text("Get notified on your Mac")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Receive Future notifications on your Mac too — no app install needed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 32)

                    VStack(spacing: 24) {
                        // Step 1
                        stepView(
                            number: 1,
                            title: "Set up iPhone Mirroring",
                            subtitle: "On your Mac running macOS Sequoia or later, open System Settings and set up iPhone Mirroring.",
                            content: {
                                mockMacSetting
                            }
                        )

                        // Step 2
                        stepView(
                            number: 2,
                            title: "Enable notifications on Mac",
                            subtitle: "On your iPhone, go to Settings > Notifications > Future and turn on \"Show on Mac\".",
                            content: {
                                mockNotificationSetting
                            }
                        )

                        // Step 3
                        stepView(
                            number: 3,
                            title: "You're all set",
                            subtitle: "When a link is delivered, you'll get a notification on both your iPhone and your Mac.",
                            content: {
                                mockNotificationBanner
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }

            // Bottom buttons
            VStack(spacing: 10) {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Notification Settings", systemImage: "gear")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Got It")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.bar)
        }
    }

    // MARK: - Step View

    private func stepView<Content: View>(
        number: Int,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                content()
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Mock Settings Illustrations

    private var mockMacSetting: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "macbook")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("iPhone Mirroring")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("System Settings > Desktop & Dock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var mockNotificationSetting: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                Text("Show on Mac")
                    .font(.subheadline)
                Spacer()
                // Fake toggle
                Capsule()
                    .fill(Color.green)
                    .frame(width: 42, height: 26)
                    .overlay(alignment: .trailing) {
                        Circle()
                            .fill(.white)
                            .frame(width: 22, height: 22)
                            .padding(.trailing, 2)
                    }
            }
            .padding(12)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var mockNotificationBanner: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.gradient)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "paperplane.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("From Past You")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("Check out this article you saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("now")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}
