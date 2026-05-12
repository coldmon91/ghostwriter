import Foundation

/// Anthropic Messages API SSE 스트리밍.
struct AnthropicStreamClient {
    let session: URLSession

    func stream(
        prompt: String,
        settings: AppSettings,
        onDelta: @escaping (String) -> Void
    ) async throws {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(settings.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let payload: [String: Any] = [
            "model": settings.model,
            "max_tokens": settings.maxTokens,
            "temperature": settings.temperature,
            "stream": true,
            "system": AIPrompt.resolved(custom: settings.customSystemPrompt),
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
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
                guard let data = raw.data(using: .utf8) else { continue }
                guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                let type = obj["type"] as? String ?? ""
                if type == "content_block_delta",
                   let delta = obj["delta"] as? [String: Any],
                   let text = delta["text"] as? String {
                    onDelta(text)
                } else if type == "message_stop" {
                    return
                } else if type == "error",
                          let err = obj["error"] as? [String: Any],
                          let message = err["message"] as? String {
                    throw AIServiceError.http(status: 0, body: message)
                }
            }
        } catch is CancellationError {
            return
        } catch {
            throw AIServiceError.stream(error)
        }
    }
}
