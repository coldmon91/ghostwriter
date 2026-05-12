import Foundation

enum AIServiceError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case invalidBaseURL
    case http(status: Int, body: String)
    case stream(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "API key is not configured."
        case .invalidResponse: return "Invalid response from server."
        case .invalidBaseURL: return "Invalid base URL."
        case .http(let status, let body): return "HTTP \(status): \(body.prefix(200))"
        case .stream(let error): return "Stream error: \(error.localizedDescription)"
        }
    }
}

/// 공통 system prompt — provider 간 동일.
enum AIPrompt {
    static let baseSystem = """
    You are an inline writing completion engine.
    Return only the next natural continuation for the user's text.

    Rules:
    - Do not repeat or rewrite existing text.
    - Consider both the text before and after the cursor.
    - Do not explain, greet, format, quote, or add lists.
    - Keep the completion short: usually 1 ~ 12 words, at most one sentence.
    - If the current sentence is incomplete, finish it naturally.
    - If the current sentence is complete, continue the same paragraph briefly.
    - Match the input language, tone, tense, and style.
    - If no confident continuation is possible, return an empty string.
    """

    /// customSystemPrompt가 있으면 baseSystem 뒤에 추가해 반환한다.
    static func resolved(custom: String) -> String {
        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return baseSystem }
        return baseSystem + "\n\nAdditional instructions:\n" + trimmed
    }
}

/// Provider별 스트리밍 클라이언트의 facade.
/// 실제 요청은 `AnthropicStreamClient` / `OpenAICompatibleStreamClient` 가 수행한다.
actor AIService {
    private let session: URLSession
    private let anthropic: AnthropicStreamClient
    private let openAI: OpenAICompatibleStreamClient

    init(session: URLSession = .shared) {
        self.session = session
        self.anthropic = AnthropicStreamClient(session: session)
        self.openAI = OpenAICompatibleStreamClient(session: session)
    }

    func streamCompletion(
        prompt: String,
        settings: AppSettings,
        onDelta: @escaping (String) -> Void
    ) async throws {
        guard !prompt.isEmpty else { return }
        guard !settings.activeAPIKey.isEmpty else { throw AIServiceError.missingAPIKey }

        switch settings.provider {
        case .anthropic:
            try await anthropic.stream(prompt: prompt, settings: settings, onDelta: onDelta)
        case .openAICompatible:
            try await openAI.stream(prompt: prompt, settings: settings, onDelta: onDelta)
        }
    }
}
