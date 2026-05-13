import Foundation

enum LLMAnalyzer {
    static func analyze(alertsText: String, config: LLMConfig, holdings: [String]) async throws -> String? {
        guard config.enabled, !config.apiKey.isEmpty else { return nil }

        let holdingsList = holdings.joined(separator: ", ")
        let prompt = "You are a concise market analyst. Based on these crash alerts, provide a 2-3 sentence analysis of what might be happening and what an investor holding \(holdingsList) should consider:\n\n\(alertsText)"

        switch config.provider {
        case .gemini:
            return try await callGemini(prompt: prompt, apiKey: config.apiKey, model: config.model)
        case .openai:
            return try await callOpenAI(prompt: prompt, apiKey: config.apiKey, model: config.model)
        case .anthropic:
            return try await callAnthropic(prompt: prompt, apiKey: config.apiKey, model: config.model)
        }
    }

    // MARK: - Gemini

    private static func callGemini(prompt: String, apiKey: String, model: String) async throws -> String? {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else { return nil }
        return text
    }

    // MARK: - OpenAI

    private static func callOpenAI(prompt: String, apiKey: String, model: String) async throws -> String? {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 300,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else { return nil }
        return text
    }

    // MARK: - Anthropic

    private static func callAnthropic(prompt: String, apiKey: String, model: String) async throws -> String? {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "messages": [["role": "user", "content": prompt]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else { return nil }
        return text
    }
}
