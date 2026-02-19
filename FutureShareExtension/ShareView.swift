import SwiftUI

struct ShareView: View {
    let url: String
    let title: String?
    let onSend: (FutureItem) -> Void
    let onCancel: () -> Void

    @State private var timeInput = ""
    @State private var note = ""
    @State private var selectedIndex = 0
    @State private var suggestions: [TimeSuggestion] = []
    @State private var aiSuggestion: TimeSuggestion?
    @State private var isAILoading = false
    @State private var aiTask: Task<Void, Never>?

    private let parser = NaturalLanguageDateParser()

    private var displaySuggestions: [TimeSuggestion] {
        if !suggestions.isEmpty { return suggestions }
        if let ai = aiSuggestion { return [ai] }
        return []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Link preview
                linkPreview

                divider

                // Time input field
                timeField

                divider

                // Suggestion list
                suggestionList

                divider

                // Note + Send
                bottomBar
            }
            .navigationTitle("Send to Future")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
            .onAppear {
                suggestions = parser.defaultSuggestions()
            }
        }
    }

    // MARK: - Link Preview

    private var linkPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }
            Text(url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Time Input

    private var timeField: some View {
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

                    // Cancel any pending AI request
                    aiTask?.cancel()
                    aiSuggestion = nil
                    isAILoading = false

                    // If deterministic parser found nothing, fall back to on-device LLM
                    if suggestions.isEmpty && !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                        isAILoading = true
                        aiTask = Task {
                            // Debounce 500ms so we don't fire on every keystroke
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
    }

    // MARK: - Suggestions

    private var suggestionList: some View {
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
            }
        }
    }

    private func suggestionRow(_ suggestion: TimeSuggestion, isSelected: Bool) -> some View {
        HStack(spacing: 0) {
            // Selection indicator bar
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

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            TextField("Add a note (optional)", text: $note)
                .font(.subheadline)

            Button {
                send()
            } label: {
                Text("Send")
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

    // MARK: - Helpers

    private var divider: some View {
        Divider().padding(.horizontal, 8)
    }

    private func send() {
        guard !displaySuggestions.isEmpty else { return }
        let index = min(selectedIndex, displaySuggestions.count - 1)
        let selected = displaySuggestions[index]

        let item = FutureItem(
            id: UUID(),
            url: url,
            title: title,
            note: note.isEmpty ? nil : note,
            createdAt: Date(),
            deliverAt: selected.date,
            isRead: false
        )
        onSend(item)
    }
}
