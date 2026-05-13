import Foundation

enum ItemCategory: String, Codable, CaseIterable {
    case index, stock, futures, vix
}

enum NotificationPlatform: String, Codable, CaseIterable {
    case telegram, slack, discord
}

enum LLMProvider: String, Codable, CaseIterable {
    case gemini, openai, anthropic
}

struct WatchlistItem: Codable, Identifiable, Hashable {
    var id: String { symbol }
    var symbol: String
    var name: String
    var category: ItemCategory
    var enabled: Bool
    var dailyThreshold: Double?
    var weeklyThreshold: Double?
    var panicLevel: Double?
    var shares: Int?
}

struct NotificationConfig: Codable {
    var platform: NotificationPlatform
    var telegram: TelegramConfig
    var slack: WebhookConfig
    var discord: WebhookConfig

    struct TelegramConfig: Codable {
        var botToken: String
        var chatId: String
    }

    struct WebhookConfig: Codable {
        var webhookUrl: String
    }
}

struct LLMConfig: Codable {
    var enabled: Bool
    var provider: LLMProvider
    var apiKey: String
    var model: String
}

struct GeneralConfig: Codable {
    var checkIntervalMinutes: Int
    var pythonPath: String
}

struct AppConfig: Codable {
    var watchlist: [WatchlistItem]
    var notifications: NotificationConfig
    var llm: LLMConfig
    var general: GeneralConfig

    static let defaultConfig = AppConfig(
        watchlist: [
            WatchlistItem(symbol: "^GSPC", name: "S&P 500", category: .index, enabled: true, dailyThreshold: -4.0, weeklyThreshold: -7.0),
            WatchlistItem(symbol: "^IXIC", name: "NASDAQ", category: .index, enabled: true, dailyThreshold: -4.0, weeklyThreshold: -7.0),
            WatchlistItem(symbol: "^VIX", name: "VIX", category: .vix, enabled: true, panicLevel: 35.0),
            WatchlistItem(symbol: "^N225", name: "Nikkei 225", category: .index, enabled: true, dailyThreshold: -4.0),
            WatchlistItem(symbol: "^HSI", name: "Hang Seng", category: .index, enabled: true, dailyThreshold: -4.0),
            WatchlistItem(symbol: "000001.SS", name: "Shanghai", category: .index, enabled: true, dailyThreshold: -4.0),
            WatchlistItem(symbol: "ES=F", name: "S&P 500 Futures", category: .futures, enabled: true, dailyThreshold: -3.0),
            WatchlistItem(symbol: "NQ=F", name: "NASDAQ Futures", category: .futures, enabled: true, dailyThreshold: -3.0),
            WatchlistItem(symbol: "GOOGL", name: "Alphabet", category: .stock, enabled: true, dailyThreshold: -10.0, shares: 62),
            WatchlistItem(symbol: "NVDA", name: "NVIDIA", category: .stock, enabled: true, dailyThreshold: -10.0, shares: 119),
            WatchlistItem(symbol: "SHOP", name: "Shopify", category: .stock, enabled: true, dailyThreshold: -10.0, shares: 50),
        ],
        notifications: NotificationConfig(
            platform: .telegram,
            telegram: .init(botToken: "", chatId: ""),
            slack: .init(webhookUrl: ""),
            discord: .init(webhookUrl: "")
        ),
        llm: LLMConfig(enabled: false, provider: .gemini, apiKey: "", model: "gemini-2.0-flash"),
        general: GeneralConfig(checkIntervalMinutes: 30, pythonPath: "/opt/homebrew/bin/python3")
    )
}

// MARK: - Alert

struct MarketAlert: Codable {
    var type: String
    var symbol: String
    var name: String
    var detail: String
    var dailyPct: Double?
    var weeklyPct: Double?
    var price: Double?
}

// MARK: - Market Data (per-symbol live data from Python)

struct MarketDataItem: Codable, Identifiable {
    var id: String { symbol }
    var symbol: String
    var name: String
    var category: ItemCategory
    var enabled: Bool
    var price: Double?
    var dailyPct: Double?
    var weeklyPct: Double?
    var shares: Int?
    var dailyThreshold: Double?
    var weeklyThreshold: Double?
    var panicLevel: Double?
    var isAlert: Bool
}

// MARK: - Check Result

struct CheckResult: Codable {
    var timestamp: String
    var mode: String
    var alertCount: Int
    var alerts: [MarketAlert]
    var marketData: [MarketDataItem]
    var errors: [String]

    enum CodingKeys: String, CodingKey {
        case timestamp, mode, alerts, errors
        case alertCount = "alert_count"
        case marketData = "market_data"
    }
}
