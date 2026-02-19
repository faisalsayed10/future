import SwiftUI
import FutureShared

struct NotificationSheet: View {
    let item: FutureItem
    let startInSnoozeMode: Bool
    let onOpen: () -> Void
    let onSnooze: (Date, Bool) -> Void // (date, isNever)
    let onDismiss: () -> Void

    @State private var isSnoozing = false
    @State private var timeInput = ""
    @State private var selectedIndex = 0
    @State private var suggestions: [TimeSuggestion] = []
    @State private var aiSuggestion: TimeSuggestion?
    @State private var isAILoading = false
    @State private var aiTask: Task<Void, Never>?
    @State private var customDate = Date().addingTimeInterval(3600)

    private let parser = NaturalLanguageDateParser()

    private var displaySuggestions: [TimeSuggestion] {
        if !suggestions.isEmpty { return suggestions }
        if let ai = aiSuggestion { return [ai] }
        return []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isSnoozing {
                    snoozeContent
                } else {
                    detailContent
                }
            }
            .navigationTitle(isSnoozing ? "Snooze" : "From Past You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isSnoozing {
                        Button("Back") {
                            withAnimation { isSnoozing = false }
                        }
                    } else {
                        Button("Dismiss") { onDismiss() }
                    }
                }
            }
            .onAppear {
                if startInSnoozeMode {
                    isSnoozing = true
                }
                suggestions = parser.defaultSuggestions()
            }
            .userActivity("com.fsayed.Future.viewLink") { activity in
                activity.webpageURL = URL(string: item.url)
                activity.title = item.title ?? item.url
                activity.isEligibleForHandoff = true
            }
        }
    }

    // MARK: - Detail Content

    private var detailContent: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title ?? item.domain ?? "Link")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Text(item.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let note = item.note {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !item.labels.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(item.labels, id: \.self) { label in
                            Text(label)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                }

                Text("Sent \(item.createdAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onOpen()
                } label: {
                    Label("Open", systemImage: "arrow.up.right")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    withAnimation { isSnoozing = true }
                } label: {
                    Label("Snooze", systemImage: "clock.arrow.circlepath")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
    }

    // MARK: - Snooze Content

    private var snoozeContent: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? item.domain ?? "Link")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(item.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            snoozeDivider

            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField("Try: 8 am, 3 days, aug 7", text: $timeInput)
                    .font(.title3)
                    .fontWeight(.medium)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: timeInput) { _, newValue in
                        suggestions = parser.suggestions(for: newValue)
                        selectedIndex = 0

                        aiTask?.cancel()
                        aiSuggestion = nil
                        isAILoading = false

                        if suggestions.isEmpty && !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                            isAILoading = true
                            aiTask = Task {
                                try? await Task.sleep(for: .milliseconds(500))
                                guard !Task.isCancelled else { return }

                                if let result = await parser.aiSuggestion(for: newValue) {
                                    guard !Task.isCancelled else { return }
                                    aiSuggestion = result
                                    selectedIndex = 0
                                }
                                isAILoading = false
                            }
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            snoozeDivider

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(displaySuggestions) { suggestion in
                        let index = displaySuggestions.firstIndex(where: { $0.id == suggestion.id }) ?? 0
                        suggestionRow(suggestion, isSelected: index == selectedIndex)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedIndex = index
                            }
                    }

                    if isAILoading {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Interpreting with on-device AI...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }

                    if displaySuggestions.isEmpty {
                        customPickerSection
                    }
                }
            }

            snoozeDivider

            HStack {
                Spacer()
                Button {
                    snooze()
                } label: {
                    Text("Snooze")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Suggestion Row

    private func suggestionRow(_ suggestion: TimeSuggestion, isSelected: Bool) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(width: 3)
                .padding(.vertical, 4)

            HStack {
                HStack(spacing: 6) {
                    Text(suggestion.label)
                        .font(.body)
                        .fontWeight(isSelected ? .medium : .regular)

                    if suggestion.isAIParsed {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                }

                Spacer()

                Text(suggestion.formattedDate)
                    .font(.footnote)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    // MARK: - Custom Date Picker

    private var customPickerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text("Pick a date & time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 8)

            DatePicker(
                "",
                selection: $customDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Helpers

    private var snoozeDivider: some View {
        Divider().padding(.horizontal, 8)
    }

    private func snooze() {
        if displaySuggestions.isEmpty {
            onSnooze(customDate, false)
            return
        }
        let index = min(selectedIndex, displaySuggestions.count - 1)
        let selected = displaySuggestions[index]
        onSnooze(selected.neverNotify ? .distantFuture : selected.date, selected.neverNotify)
    }
}
