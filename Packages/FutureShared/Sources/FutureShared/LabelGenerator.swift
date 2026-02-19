import Foundation
import FoundationModels

@Generable
struct GeneratedLabels {
    @Guide(description: "Primary category label for this link. Use concise labels like: Tech, News, Video, Article, Shopping, Social, Recipe, Finance, Health, Travel, Music, Design, Dev, AI, Sports, Gaming, Education, Entertainment, Science, Business, Food, Fashion, Productivity, Tools, Reference")
    var primary: String

    @Guide(description: "Optional secondary category label, or empty string if one label is sufficient")
    var secondary: String
}

@MainActor
public class LabelGenerator {
    public static let shared = LabelGenerator()

    public init() {}

    public func generateLabels(for item: FutureItem) async -> [String] {
        guard case .available = SystemLanguageModel.default.availability else { return [] }

        let session = LanguageModelSession {
            """
            You are a link categorizer. Given a URL and optional title/note, assign 1-2 short \
            category labels. Use concise, common single-word categories like: Tech, News, Video, \
            Article, Shopping, Social, Recipe, Finance, Health, Travel, Music, Design, Dev, AI, \
            Sports, Gaming, Education, Entertainment, Science, Business, Food, Fashion, \
            Productivity, Tools, Reference. If one label is enough, leave secondary empty.
            """
        }

        var prompt = "URL: \(item.url)"
        if let title = item.title { prompt += "\nTitle: \(title)" }
        if let note = item.note { prompt += "\nNote: \(note)" }

        do {
            let response = try await session.respond(to: prompt, generating: GeneratedLabels.self)
            var labels = [response.content.primary]
            if !response.content.secondary.isEmpty {
                labels.append(response.content.secondary)
            }
            return labels
        } catch {
            return []
        }
    }
}
