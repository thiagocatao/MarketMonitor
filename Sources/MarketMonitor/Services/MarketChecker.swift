import Foundation

enum MarketCheckerError: Error, LocalizedError {
    case fetchFailed(String, String)
    case noData(String)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let symbol, let reason): return "Failed to fetch \(symbol): \(reason)"
        case .noData(let symbol): return "No price data for \(symbol)"
        }
    }
}

enum MarketChecker {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0"]
        return URLSession(configuration: config)
    }()

    static func check(watchlist: [WatchlistItem]) async -> CheckResult {
        let timestamp = {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd HH:mm"
            fmt.timeZone = TimeZone(identifier: "UTC")
            return fmt.string(from: Date()) + " UTC"
        }()

        var allAlerts: [MarketAlert] = []
        var marketData: [MarketDataItem] = []
        var errors: [String] = []

        await withTaskGroup(of: (WatchlistItem, PriceData?, String?).self) { group in
            for item in watchlist {
                group.addTask {
                    guard item.enabled else { return (item, nil, nil) }
                    do {
                        let data = try await fetchPrice(symbol: item.symbol, category: item.category)
                        return (item, data, nil)
                    } catch {
                        return (item, nil, "\(item.symbol): \(error.localizedDescription)")
                    }
                }
            }

            for await (item, data, error) in group {
                if let error { errors.append(error) }

                let alerts = evaluateAlerts(item: item, data: data)
                allAlerts.append(contentsOf: alerts)

                marketData.append(MarketDataItem(
                    symbol: item.symbol,
                    name: item.name,
                    category: item.category,
                    enabled: item.enabled,
                    price: data?.price,
                    dailyPct: data?.dailyPct,
                    weeklyPct: data?.weeklyPct,
                    shares: item.shares,
                    dailyThreshold: item.dailyThreshold,
                    weeklyThreshold: item.weeklyThreshold,
                    panicLevel: item.panicLevel,
                    isAlert: !alerts.isEmpty
                ))
            }
        }

        let order = Dictionary(uniqueKeysWithValues: watchlist.enumerated().map { ($1.symbol, $0) })
        marketData.sort { (order[$0.symbol] ?? 0) < (order[$1.symbol] ?? 0) }

        return CheckResult(
            timestamp: timestamp,
            mode: "full",
            alertCount: allAlerts.count,
            alerts: allAlerts,
            marketData: marketData,
            errors: errors
        )
    }

    // MARK: - Yahoo Finance API

    private struct PriceData {
        var price: Double
        var dailyPct: Double?
        var weeklyPct: Double?
    }

    private static func fetchPrice(symbol: String, category: ItemCategory) async throws -> PriceData {
        let range = category == .futures ? "2d" : "5d"
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?range=\(range)&interval=1d")!

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw MarketCheckerError.fetchFailed(symbol, "HTTP \(code)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let result = results.first,
              let indicators = result["indicators"] as? [String: Any],
              let quotes = (indicators["quote"] as? [[String: Any]])?.first,
              let closes = quotes["close"] as? [Any]
        else {
            throw MarketCheckerError.noData(symbol)
        }

        let prices = closes.compactMap { ($0 as? NSNumber)?.doubleValue }
        guard let current = prices.last, !current.isNaN else {
            throw MarketCheckerError.noData(symbol)
        }

        var dailyPct: Double?
        if prices.count >= 2 {
            let prev = prices[prices.count - 2]
            if !prev.isNaN && prev != 0 {
                dailyPct = (current - prev) / prev * 100
            }
        }

        var weeklyPct: Double?
        if prices.count >= 5 {
            let weekOpen = prices[0]
            if !weekOpen.isNaN && weekOpen != 0 {
                weeklyPct = (current - weekOpen) / weekOpen * 100
            }
        }

        return PriceData(
            price: (current * 100).rounded() / 100,
            dailyPct: dailyPct.map { ($0 * 100).rounded() / 100 },
            weeklyPct: weeklyPct.map { ($0 * 100).rounded() / 100 }
        )
    }

    // MARK: - Alert Evaluation

    private static func evaluateAlerts(item: WatchlistItem, data: PriceData?) -> [MarketAlert] {
        guard let data, item.enabled else { return [] }
        var alerts: [MarketAlert] = []

        if item.category == .vix {
            let panic = item.panicLevel ?? 35
            if data.price >= panic {
                alerts.append(MarketAlert(
                    type: "VIX_PANIC",
                    symbol: item.symbol,
                    name: item.name,
                    detail: "\(item.name) at \(String(format: "%.2f", data.price)) — above \(Int(panic))",
                    dailyPct: data.dailyPct,
                    weeklyPct: data.weeklyPct,
                    price: data.price
                ))
            }
        } else {
            if let threshold = item.dailyThreshold, let pct = data.dailyPct, pct <= threshold {
                let sharesInfo = item.shares.map { " — you hold \($0) shares" } ?? ""
                alerts.append(MarketAlert(
                    type: "\(item.category.rawValue.uppercased())_CRASH",
                    symbol: item.symbol,
                    name: item.name,
                    detail: "\(item.name) (\(item.symbol)) dropped \(String(format: "%.1f", pct))% today (price: \(String(format: "%.2f", data.price)))\(sharesInfo)",
                    dailyPct: data.dailyPct,
                    weeklyPct: data.weeklyPct,
                    price: data.price
                ))
            }

            if let threshold = item.weeklyThreshold, let pct = data.weeklyPct, pct <= threshold {
                alerts.append(MarketAlert(
                    type: "SUSTAINED_DECLINE",
                    symbol: item.symbol,
                    name: item.name,
                    detail: "\(item.name) (\(item.symbol)) down \(String(format: "%.1f", pct))% this week (price: \(String(format: "%.2f", data.price)))",
                    dailyPct: data.dailyPct,
                    weeklyPct: data.weeklyPct,
                    price: data.price
                ))
            }
        }

        return alerts
    }
}
