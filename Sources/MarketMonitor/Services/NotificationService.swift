import Foundation

enum NotificationError: Error, LocalizedError {
    case emptyConfig(String)
    case sendFailed(platform: String, statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .emptyConfig(let detail): return detail
        case .sendFailed(let platform, let code): return "\(platform) returned HTTP \(code)"
        }
    }
}

enum NotificationService {
    static func send(message: String, config: NotificationConfig) async throws {
        switch config.platform {
        case .telegram:
            try await sendTelegram(message: message, config: config.telegram)
        case .slack:
            try await sendSlack(message: message, config: config.slack)
        case .discord:
            try await sendDiscord(message: message, config: config.discord)
        }
    }

    static func sendTest(config: NotificationConfig) async throws {
        let message = "*MarketMonitor* — test notification.\nConnection verified. You will only hear from me if markets are crashing."
        try await send(message: message, config: config)
    }

    // MARK: - Telegram

    private static func sendTelegram(message: String, config: NotificationConfig.TelegramConfig) async throws {
        guard !config.botToken.isEmpty, !config.chatId.isEmpty else {
            throw NotificationError.emptyConfig("Telegram bot token and chat ID are required")
        }
        let url = URL(string: "https://api.telegram.org/bot\(config.botToken)/sendMessage")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "chat_id": config.chatId,
            "text": message,
            "parse_mode": "Markdown",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NotificationError.sendFailed(platform: "Telegram", statusCode: code)
        }
    }

    // MARK: - Slack

    private static func sendSlack(message: String, config: NotificationConfig.WebhookConfig) async throws {
        guard !config.webhookUrl.isEmpty, let url = URL(string: config.webhookUrl) else {
            throw NotificationError.emptyConfig("Slack webhook URL is required")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["text": message]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NotificationError.sendFailed(platform: "Slack", statusCode: code)
        }
    }

    // MARK: - Discord

    private static func sendDiscord(message: String, config: NotificationConfig.WebhookConfig) async throws {
        guard !config.webhookUrl.isEmpty, let url = URL(string: config.webhookUrl) else {
            throw NotificationError.emptyConfig("Discord webhook URL is required")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["content": message]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NotificationError.sendFailed(platform: "Discord", statusCode: code)
        }
    }
}
