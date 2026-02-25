import Foundation

struct AIRecipeAssistantInsight: Equatable {
    enum Source: String {
        case offline
        case openAI
        case gemini

        var badge: String {
            switch self {
            case .offline:
                return "On-device"
            case .openAI:
                return "OpenAI"
            case .gemini:
                return "Gemini"
            }
        }
    }

    let headline: String
    let message: String
    let source: Source
}

@MainActor
final class AIRecipeAssistantService {
    static let shared = AIRecipeAssistantService(
        allowRemote: ProcessInfo.processInfo.environment["ALLOW_REMOTE_AI"] == "1"
    )

    private let session: URLSession
    private let allowRemote: Bool

    init(session: URLSession = .shared, allowRemote: Bool = true) {
        self.session = session
        self.allowRemote = allowRemote
    }

    func generateInsight(
        language: AppLanguage,
        foods: [FoodItem],
        suggestions: [RecipeSuggestion],
        refreshSeed: Int = 0
    ) async -> AIRecipeAssistantInsight {
        let fallback = offlineInsight(
            language: language,
            foods: foods,
            suggestions: suggestions,
            refreshSeed: refreshSeed
        )
        guard allowRemote else { return fallback }

        let preference = providerPreference()
        for provider in providerOrder(for: preference) {
            switch provider {
            case .offline:
                break
            case .gemini:
                if let config = geminiConfig(),
                   let remoteText = try? await fetchGeminiInsight(
                    config: config,
                    language: language,
                    foods: foods,
                    suggestions: suggestions,
                    refreshSeed: refreshSeed
                   ) {
                    return AIRecipeAssistantInsight(
                        headline: localizedHeadline(language: language, isRemote: true),
                        message: remoteText,
                        source: .gemini
                    )
                }
            case .openAI:
                if let config = openAIConfig(),
                   let remoteText = try? await fetchOpenAIInsight(
                    config: config,
                    language: language,
                    foods: foods,
                    suggestions: suggestions,
                    refreshSeed: refreshSeed
                   ) {
                    return AIRecipeAssistantInsight(
                        headline: localizedHeadline(language: language, isRemote: true),
                        message: remoteText,
                        source: .openAI
                    )
                }
            case .auto:
                break
            }
        }

        return fallback
    }

    private func fetchOpenAIInsight(
        config: OpenAIConfig,
        language: AppLanguage,
        foods: [FoodItem],
        suggestions: [RecipeSuggestion],
        refreshSeed: Int
    ) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let payload = OpenAIRequest(
            model: config.model,
            messages: [
                .init(
                    role: "system",
                    content: """
                    You are a concise kitchen coach.
                    Keep answers under 35 words.
                    Match requested language style exactly.
                    """
                ),
                .init(
                    role: "user",
                    content: prompt(
                        language: language,
                        foods: foods,
                        suggestions: suggestions,
                        refreshSeed: refreshSeed
                    )
                )
            ],
            temperature: 0.5,
            max_tokens: 90
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await loadDataWithRetry(for: request)
        try validateHTTP(response: response, data: data)
        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        let text = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else {
            throw AIServiceError.emptyResponse
        }
        return normalize(text)
    }

    private func fetchGeminiInsight(
        config: GeminiConfig,
        language: AppLanguage,
        foods: [FoodItem],
        suggestions: [RecipeSuggestion],
        refreshSeed: Int
    ) async throws -> String {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(config.model):generateContent?key=\(config.apiKey)"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = GeminiRequest(
            contents: [
                .init(
                    parts: [
                        .init(
                            text: prompt(
                                language: language,
                                foods: foods,
                                suggestions: suggestions,
                                refreshSeed: refreshSeed
                            )
                        )
                    ]
                )
            ]
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await loadDataWithRetry(for: request)
        try validateHTTP(response: response, data: data)
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        let text = decoded.candidates
            .flatMap(\.content.parts)
            .compactMap(\.text)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else {
            throw AIServiceError.emptyResponse
        }
        return normalize(text)
    }

    private func offlineInsight(
        language: AppLanguage,
        foods: [FoodItem],
        suggestions: [RecipeSuggestion],
        refreshSeed: Int
    ) -> AIRecipeAssistantInsight {
        let expiredItems = foods
            .filter { $0.expiryStage == .expired }
            .sorted(by: { $0.expiryDate < $1.expiryDate })
        let cookableItems = foods
            .filter { $0.expiryStage != .expired }
            .sorted(by: { $0.expiryDate < $1.expiryDate })

        guard let urgent = cookableItems.first else {
            if let expired = expiredItems.first {
                let base = localized(
                    language: language,
                    hinglish: "\(expired.localizedName(for: language)) expire ho chuka hai. Pehle usko fridge list se remove karo, phir fresh items add karke recipe tip lo.",
                    english: "\(expired.localizedName(for: language)) has expired. Remove it from your fridge list first, then add fresh items for recipe tips.",
                    spanish: "\(expired.localizedName(for: language)) ya caducó. Elimínalo de tu lista primero y luego agrega items frescos para recetas."
                )
                return AIRecipeAssistantInsight(
                    headline: localizedHeadline(language: language, isRemote: false),
                    message: appendOfflineNudge(
                        base: base,
                        language: language,
                        refreshSeed: refreshSeed,
                        includesExpired: true
                    ),
                    source: .offline
                )
            }
            let base = localized(
                language: language,
                hinglish: "Fridge khaali hai. Kuch items add karo, phir main bataunga pehle kya cook karna hai.",
                english: "Your fridge is empty. Add a few items and I’ll suggest what to cook first.",
                spanish: "Tu refrigerador está vacío. Agrega items y te sugeriré qué cocinar primero."
            )
            return AIRecipeAssistantInsight(
                headline: localizedHeadline(language: language, isRemote: false),
                message: appendOfflineNudge(
                    base: base,
                    language: language,
                    refreshSeed: refreshSeed,
                    includesExpired: false
                ),
                source: .offline
            )
        }

        let cookableSuggestion = suggestions.first(where: { !$0.availableIngredientKeys.isEmpty })
        if let recipe = cookableSuggestion {
            if let expired = expiredItems.first {
                let base = localized(
                    language: language,
                    hinglish: "Pehle \(expired.localizedName(for: language)) remove karo (expired). Uske baad \(recipe.localizedTitle(for: language)) se \(urgent.localizedName(for: language)) use karo.",
                    english: "First remove expired \(expired.localizedName(for: language)). Then cook \(recipe.localizedTitle(for: language)) to use \(urgent.localizedName(for: language)).",
                    spanish: "Primero elimina \(expired.localizedName(for: language)) caducado. Luego cocina \(recipe.localizedTitle(for: language)) para usar \(urgent.localizedName(for: language))."
                )
                return AIRecipeAssistantInsight(
                    headline: localizedHeadline(language: language, isRemote: false),
                    message: appendOfflineNudge(
                        base: base,
                        language: language,
                        refreshSeed: refreshSeed,
                        includesExpired: true
                    ),
                    source: .offline
                )
            }
            let base = localized(
                language: language,
                hinglish: "Aaj \(urgent.localizedName(for: language)) use karo. Best option: \(recipe.localizedTitle(for: language)), sirf \(recipe.cookMinutes) min mein.",
                english: "Use \(urgent.localizedName(for: language)) today. Best pick: \(recipe.localizedTitle(for: language)) in \(recipe.cookMinutes) min.",
                spanish: "Usa \(urgent.localizedName(for: language)) hoy. Mejor opción: \(recipe.localizedTitle(for: language)) en \(recipe.cookMinutes) min."
            )
            return AIRecipeAssistantInsight(
                headline: localizedHeadline(language: language, isRemote: false),
                message: appendOfflineNudge(
                    base: base,
                    language: language,
                    refreshSeed: refreshSeed,
                    includesExpired: false
                ),
                source: .offline
            )
        }

        if let expired = expiredItems.first {
            let base = localized(
                language: language,
                hinglish: "\(expired.localizedName(for: language)) expired hai. Pehle remove karo, phir \(urgent.localizedName(for: language)) se kuch cook karo.",
                english: "\(expired.localizedName(for: language)) is expired. Remove it first, then cook with \(urgent.localizedName(for: language)).",
                spanish: "\(expired.localizedName(for: language)) está caducado. Elimínalo primero y luego cocina con \(urgent.localizedName(for: language))."
            )
            return AIRecipeAssistantInsight(
                headline: localizedHeadline(language: language, isRemote: false),
                message: appendOfflineNudge(
                    base: base,
                    language: language,
                    refreshSeed: refreshSeed,
                    includesExpired: true
                ),
                source: .offline
            )
        }

        let base = localized(
            language: language,
            hinglish: "Waste bachane ke liye pehle \(urgent.localizedName(for: language)) se kuch cook karo.",
            english: "Cook anything using \(urgent.localizedName(for: language)) first to avoid waste.",
            spanish: "Cocina primero algo con \(urgent.localizedName(for: language)) para evitar desperdicio."
        )
        return AIRecipeAssistantInsight(
            headline: localizedHeadline(language: language, isRemote: false),
            message: appendOfflineNudge(
                base: base,
                language: language,
                refreshSeed: refreshSeed,
                includesExpired: false
            ),
            source: .offline
        )
    }

    private func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func prompt(
        language: AppLanguage,
        foods: [FoodItem],
        suggestions: [RecipeSuggestion],
        refreshSeed: Int
    ) -> String {
        let inventory = foods
            .sorted(by: { $0.expiryDate < $1.expiryDate })
            .prefix(6)
            .map { item in
                let freshness = item.expiryStage == .expired
                ? localized(language: language, hinglish: "expired", english: "expired", spanish: "caducado")
                : "\(max(item.daysLeft, 0))d"
                return "\(item.localizedName(for: language)) (\(freshness))"
            }
            .joined(separator: ", ")
        let recipes = suggestions
            .prefix(3)
            .map { "\($0.localizedTitle(for: language)) (\($0.cookMinutes)m)" }
            .joined(separator: ", ")

        return """
        Language style: \(languageStyleInstruction(language))
        Inventory: \(inventory)
        Suggested recipes: \(recipes)
        Tip variation seed: \(refreshSeed)
        Never recommend cooking expired ingredients.
        If an item is expired, advise removing it from fridge tracking first.
        Give one practical tip to reduce food waste today.
        """
    }

    private func appendOfflineNudge(
        base: String,
        language: AppLanguage,
        refreshSeed: Int,
        includesExpired: Bool
    ) -> String {
        let options: [String]
        if includesExpired {
            options = [
                localized(
                    language: language,
                    hinglish: "Tip: expired item pehle remove karo, phir recipe planning easy hogi.",
                    english: "Tip: remove expired items first, then recipe planning becomes accurate.",
                    spanish: "Consejo: elimina primero los caducados y tus recetas serán más precisas."
                ),
                localized(
                    language: language,
                    hinglish: "Tip: fridge list clean rakho, tab AI suggestions better aayengi.",
                    english: "Tip: keep your fridge list clean so AI suggestions stay useful.",
                    spanish: "Consejo: mantén limpia tu lista del refri para mejores sugerencias."
                ),
                localized(
                    language: language,
                    hinglish: "Tip: expired item remove/discard karke score tracking bhi sahi rahega.",
                    english: "Tip: removing/discarding expired items keeps score tracking honest.",
                    spanish: "Consejo: eliminar los caducados mantiene tu puntaje más real."
                )
            ]
        } else {
            options = [
                localized(
                    language: language,
                    hinglish: "Tip: sabse jaldi expire hone wala ingredient pehle use karo.",
                    english: "Tip: start with the ingredient that expires first.",
                    spanish: "Consejo: empieza por el ingrediente que caduca primero."
                ),
                localized(
                    language: language,
                    hinglish: "Tip: 10-15 min ki quick recipe se waste fast control hota hai.",
                    english: "Tip: a quick 10-15 minute meal helps prevent waste fast.",
                    spanish: "Consejo: una comida rápida de 10-15 min evita desperdicio."
                ),
                localized(
                    language: language,
                    hinglish: "Tip: next grocery se pehle ek rescue meal finish karo.",
                    english: "Tip: finish one rescue meal before your next grocery run.",
                    spanish: "Consejo: prepara una comida de rescate antes de comprar más."
                )
            ]
        }

        let index = seededIndex(for: refreshSeed, count: options.count)
        return "\(base) \(options[index])"
    }

    private func seededIndex(for seed: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return Int(seed.magnitude % UInt(count))
    }

    private func localizedHeadline(language: AppLanguage, isRemote: Bool) -> String {
        if isRemote {
            return localized(
                language: language,
                hinglish: "AI Rasoi Coach",
                english: "AI Kitchen Coach",
                spanish: "Coach de cocina IA"
            )
        }
        return localized(
            language: language,
            hinglish: "Smart Rasoi Coach",
            english: "Smart Kitchen Coach",
            spanish: "Coach inteligente de cocina"
        )
    }

    private func localized(language: AppLanguage, hinglish: String, english: String, spanish: String) -> String {
        switch language {
        case .hinglish:
            return hinglish
        case .english:
            return english
        case .spanish:
            return spanish
        }
    }

    private func openAIConfig() -> OpenAIConfig? {
        let key = cleanedSecret(ProcessInfo.processInfo.environment["OPENAI_API_KEY"])
            ?? cleanedSecret(bundleString("OPENAI_API_KEY"))
        guard let key else { return nil }
        let model = cleanedValue(ProcessInfo.processInfo.environment["OPENAI_MODEL"])
            ?? cleanedValue(bundleString("OPENAI_MODEL"))
            ?? "gpt-4o-mini"
        return OpenAIConfig(apiKey: key, model: model)
    }

    private func geminiConfig() -> GeminiConfig? {
        let key = cleanedSecret(ProcessInfo.processInfo.environment["GEMINI_API_KEY"])
            ?? cleanedSecret(bundleString("GEMINI_API_KEY"))
        guard let key else { return nil }
        let model = cleanedValue(ProcessInfo.processInfo.environment["GEMINI_MODEL"])
            ?? cleanedValue(bundleString("GEMINI_MODEL"))
            ?? "gemini-1.5-flash"
        return GeminiConfig(apiKey: key, model: model)
    }

    private func bundleString(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    private func providerPreference() -> AIProviderPreference {
        let raw = cleanedValue(
            ProcessInfo.processInfo.environment["AI_PROVIDER"]
            ?? bundleString("AI_PROVIDER")
        )?.lowercased()
        return AIProviderPreference(rawValue: raw ?? "auto") ?? .auto
    }

    private func providerOrder(for preference: AIProviderPreference) -> [AIProviderPreference] {
        switch preference {
        case .auto:
            return [.gemini, .openAI]
        case .gemini:
            // Explicit provider selection should stay strict for predictable behavior.
            return [.gemini]
        case .openAI:
            // Explicit provider selection should stay strict for predictable behavior.
            return [.openAI]
        case .offline:
            return [.offline]
        }
    }

    private func cleanedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.contains("$(") else { return nil }
        return trimmed
    }

    private func cleanedSecret(_ value: String?) -> String? {
        guard let cleaned = cleanedValue(value) else { return nil }
        guard cleaned.count >= 10 else { return nil }
        return cleaned
    }

    private func languageStyleInstruction(_ language: AppLanguage) -> String {
        switch language {
        case .hinglish:
            return "Hinglish (mix Hindi + English, casual Indian tone)"
        case .english:
            return "English"
        case .spanish:
            return "Spanish"
        }
    }

    private func loadDataWithRetry(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            guard isRetriableNetworkError(error) else { throw error }
            try? await Task.sleep(nanoseconds: 500_000_000)
            return try await session.data(for: request)
        }
    }

    private func isRetriableNetworkError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .networkConnectionLost, .timedOut, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    private func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown API error"
            throw AIServiceError.http(statusCode: http.statusCode, body: body)
        }
    }
}

private struct OpenAIConfig {
    let apiKey: String
    let model: String
}

private struct GeminiConfig {
    let apiKey: String
    let model: String
}

private enum AIServiceError: Error {
    case emptyResponse
    case http(statusCode: Int, body: String)
}

private enum AIProviderPreference: String {
    case auto
    case openAI = "openai"
    case gemini
    case offline
}

private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let max_tokens: Int

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct GeminiRequest: Encodable {
    let contents: [Content]

    struct Content: Encodable {
        let parts: [Part]
    }

    struct Part: Encodable {
        let text: String
    }
}

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }

            let parts: [Part]
        }

        let content: Content
    }

    let candidates: [Candidate]
}
