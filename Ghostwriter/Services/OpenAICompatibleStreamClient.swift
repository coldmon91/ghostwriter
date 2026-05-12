import Foundation

/// OpenAI 호환 Chat Completions SSE 스트리밍.
/// `settings.openAIBaseURL` 에 `/chat/completions` 를 붙여 호출하므로
/// OpenAI / Azure OpenAI / OpenRouter / Ollama / LM Studio 등에 사용 가능.
struct OpenAICompatibleStreamClient {
    let session: URLSession

    func stream(
        prompt: String,
        settings: AppSettings,
        onDelta: @escaping (String) -> Void
    ) async throws {
        let url = try buildEndpoint(baseURL: settings.openAIBaseURL)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        var payload: [String: Any] = [
            "model": settings.openAIModel,
            "max_tokens": settings.maxTokens,
            "temperature": settings.temperature,
            "stream": true,
            "messages": [
                ["role": "system", "content": AIPrompt.resolved(custom: settings.customSystemPrompt)],
                ["role": "user", "content": prompt]
            ]
        ]
        if settings.openAIReasoningEffort != .unset {
            payload["reasoning_effort"] = settings.openAIReasoningEffort.rawValue
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            var body = ""
            for try await line in bytes.lines { body += line + "\n" }
            throw AIServiceError.http(status: http.statusCode, body: body)
        }

        do {
            for try await line in bytes.lines {
                try Task.checkCancellation()
                guard line.hasPrefix("data:") else { continue }
                let raw = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if raw.isEmpty { continue }
                if raw == "[DONE]" { return }
                guard let data = raw.data(using: .utf8) else { continue }
                guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                if let err = obj["error"] as? [String: Any],
                   let message = err["message"] as? String {
                    throw AIServiceError.http(status: 0, body: message)
                }

                guard
                    let choices = obj["choices"] as? [[String: Any]],
                    let first = choices.first
                else { continue }

                if let delta = first["delta"] as? [String: Any],
                   let text = delta["content"] as? String,
                   !text.isEmpty {
                    onDelta(text)
                }

                // finish_reason이 nil이 아니면 종료 신호
                if let finish = first["finish_reason"] as? String, !finish.isEmpty {
                    return
                }
            }
        } catch is CancellationError {
            return
        } catch {
            throw AIServiceError.stream(error)
        }
    }

    private func buildEndpoint(baseURL: String) throws -> URL {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIServiceError.invalidBaseURL }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }

        // 사용자가 이미 /chat/completions 를 포함시킨 경우 그대로 사용
        let suffix = "/chat/completions"
        let endpoint = trimmed.hasSuffix(suffix) ? trimmed : trimmed + suffix
        guard let url = URL(string: endpoint) else { throw AIServiceError.invalidBaseURL }
        return url
    }
}
