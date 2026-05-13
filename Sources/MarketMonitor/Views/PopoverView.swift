import SwiftUI

// MARK: - Filter

enum WatchlistFilter: CaseIterable {
    case all, alert, index, futures, vix, stock

    var label: String {
        switch self {
        case .all: return "All"
        case .alert: return "Alerts"
        case .index: return "Indices"
        case .futures: return "Futures"
        case .vix: return "VIX"
        case .stock: return "Stocks"
        }
    }

    func count(in data: [MarketDataItem]) -> Int {
        switch self {
        case .all: return data.count
        case .alert: return data.filter(\.isAlert).count
        case .index: return data.filter { $0.category == .index }.count
        case .futures: return data.filter { $0.category == .futures }.count
        case .vix: return data.filter { $0.category == .vix }.count
        case .stock: return data.filter { $0.category == .stock }.count
        }
    }
}

// MARK: - Main Popover

struct PopoverView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @EnvironmentObject var configManager: ConfigManager
    @State private var filter: WatchlistFilter = .all
    @State private var expandedSymbols: Set<String> = []

    private var alertCount: Int { appDelegate.activeAlerts.count }
    private var data: [MarketDataItem] { appDelegate.marketData }

    private var portfolioValue: Double {
        data.filter { $0.category == .stock && $0.shares != nil && $0.price != nil }
            .reduce(0) { $0 + Double($1.shares!) * $1.price! }
    }

    private var dayPL: Double {
        data.filter { $0.category == .stock && $0.shares != nil && $0.price != nil && $0.dailyPct != nil }
            .reduce(0) { total, item in
                let prev = item.price! / (1 + item.dailyPct! / 100)
                return total + Double(item.shares!) * (item.price! - prev)
            }
    }

    private var vixItem: MarketDataItem? {
        data.first { $0.category == .vix }
    }

    private var titleText: String {
        if appDelegate.isChecking && data.isEmpty { return "Checking..." }
        if let _ = appDelegate.lastError, data.isEmpty { return "Check failed" }
        if alertCount > 0 { return "\(alertCount) alert\(alertCount == 1 ? "" : "s")" }
        return "All clear"
    }

    private var timeAgo: String {
        guard let date = appDelegate.lastCheckDate else { return "never" }
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 60 { return "just now" }
        let mins = secs / 60
        if mins < 60 { return "\(mins) min ago" }
        return "\(mins / 60)h ago"
    }

    private var nextIn: String {
        guard let date = appDelegate.lastCheckDate else { return "" }
        let interval = configManager.config.general.checkIntervalMinutes * 60
        let remaining = max(0, interval - Int(Date().timeIntervalSince(date))) / 60
        return "\(remaining)m"
    }

    var body: some View {
        VStack(spacing: 0) {
            popoverHeader
            if let firstAlert = appDelegate.activeAlerts.first {
                alertBanner(firstAlert)
            }
            summaryBand
            filterBar
            ScrollView {
                VStack(spacing: 0) {
                    if shouldShow(.index) {
                        section(category: .index, title: "INDICES", items: items(for: .index))
                    }
                    if shouldShow(.futures) {
                        section(category: .futures, title: "FUTURES", items: items(for: .futures))
                    }
                    if shouldShow(.vix) {
                        section(category: .vix, title: "VOLATILITY", items: items(for: .vix))
                    }
                    if shouldShow(.stock) {
                        section(category: .stock, title: "HOLDINGS", items: items(for: .stock))
                    }
                    if data.isEmpty {
                        emptyState
                    }
                }
            }
            .frame(maxHeight: 380)
            popoverFooter
        }
        .frame(width: Theme.popoverWidth)
        .background(Theme.paper)
    }

    private func shouldShow(_ cat: ItemCategory) -> Bool {
        switch filter {
        case .all: return !items(for: cat).isEmpty
        case .alert: return items(for: cat).contains(where: \.isAlert)
        case .index: return cat == .index && !items(for: cat).isEmpty
        case .futures: return cat == .futures && !items(for: cat).isEmpty
        case .vix: return cat == .vix && !items(for: cat).isEmpty
        case .stock: return cat == .stock && !items(for: cat).isEmpty
        }
    }

    private func items(for category: ItemCategory) -> [MarketDataItem] {
        let filtered = data.filter { $0.category == category }
        if filter == .alert { return filtered.filter(\.isAlert) }
        return filtered
    }

    // MARK: - Header

    private var popoverHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    statusDot
                    Text(titleText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.ink)
                }
                HStack(spacing: 0) {
                    Text("last check \(timeAgo)")
                    if !nextIn.isEmpty {
                        Text(" · ").foregroundColor(Theme.inkFaint)
                        Text("next in \(nextIn)")
                    }
                }
                .font(.system(size: 11.5))
                .foregroundColor(Theme.ink3)
                .monospacedDigit()
            }
            Spacer()
            Button(action: { Task { await appDelegate.performCheck() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.ink2)
                    .frame(width: 24, height: 24)
                    .background(Theme.paper3)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                    .rotationEffect(.degrees(appDelegate.isChecking ? 360 : 0))
                    .animation(
                        appDelegate.isChecking
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: appDelegate.isChecking
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.spaceLG)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Divider().foregroundColor(Theme.hairline) }
    }

    private var statusDot: some View {
        Circle()
            .fill(alertCount > 0 ? Theme.down : (data.isEmpty ? Theme.inkFaint : Theme.up))
            .frame(width: 7, height: 7)
            .shadow(color: (alertCount > 0 ? Theme.down : Theme.up).opacity(0.14), radius: 3)
    }

    // MARK: - Alert Banner

    private func alertBanner(_ alert: MarketAlert) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                Text("\(alert.type.replacingOccurrences(of: "_", with: " ").capitalized) · triggered \(timeAgo)")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
            .foregroundColor(Theme.downStrong)

            Text(alert.detail)
                .font(.system(size: 13))
                .foregroundColor(Theme.ink2)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.spaceLG)
        .padding(.vertical, Theme.spaceMD)
        .background(
            LinearGradient(
                colors: [Color(red: 253/255, green: 243/255, blue: 241/255), Theme.downBg],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Summary Band

    private var summaryBand: some View {
        HStack(spacing: 0) {
            summaryCell(label: "PORTFOLIO", value: Theme.formatMoney(portfolioValue), isDown: dayPL < 0, sub: portfolioValue > 0 ? Theme.formatChange(dayPL / portfolioValue * 100) : nil)
            Divider().frame(height: 36)
            summaryCell(label: "DAY P/L", value: Theme.formatMoney(dayPL), isDown: dayPL < 0, sub: nil)
            Divider().frame(height: 36)
            summaryCell(label: "VIX", value: vixItem?.price.map { String(format: "%.1f", $0) } ?? "—", isDown: (vixItem?.dailyPct ?? 0) > 0, sub: vixItem?.dailyPct.map { Theme.formatChange($0) })
        }
        .overlay(alignment: .bottom) { Divider() }
    }

    private func summaryCell(label: String, value: String, isDown: Bool, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Theme.ink4)
            HStack(spacing: 4) {
                Text(value)
                    .font(Theme.mono(size: 15, weight: .medium))
                    .foregroundColor(isDown ? Theme.down : Theme.ink)
                if let sub {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.ink4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(WatchlistFilter.allCases, id: \.self) { f in
                    let count = f.count(in: data)
                    Button(action: { withAnimation(.easeInOut(duration: 0.15)) { filter = f } }) {
                        HStack(spacing: 4) {
                            Text(f.label)
                            Text("\(count)")
                                .font(Theme.mono(size: 10))
                                .foregroundColor(filter == f ? Theme.paper.opacity(0.55) : Theme.inkFaint)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(filter == f ? Theme.paper : Theme.ink3)
                        .padding(.horizontal, 10)
                        .frame(height: 22)
                        .background(filter == f ? Theme.ink : Color.clear)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.top, 8)
    }

    // MARK: - Section

    private func section(category: ItemCategory, title: String, items: [MarketDataItem]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundColor(Theme.ink4)
                Spacer()
                Text(sectionMeta(for: category))
                    .font(Theme.mono(size: 10.5))
                    .foregroundColor(Theme.ink4)
            }
            .padding(.horizontal, Theme.spaceLG)
            .padding(.vertical, 6)

            ForEach(items) { item in
                MarketRow(
                    item: item,
                    isExpanded: expandedSymbols.contains(item.symbol),
                    onTap: { toggleExpand(item.symbol) }
                )
            }
        }
        .padding(.vertical, Theme.spaceSM)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func sectionMeta(for category: ItemCategory) -> String {
        switch category {
        case .index:
            let item = data.first { $0.category == .index }
            let d = item?.dailyThreshold.map { "daily \(Int($0))%" } ?? ""
            let w = item?.weeklyThreshold.map { " · weekly \(Int($0))%" } ?? ""
            return d + w
        case .futures:
            let item = data.first { $0.category == .futures }
            return item?.dailyThreshold.map { "daily \(Int($0))%" } ?? ""
        case .vix:
            let item = data.first { $0.category == .vix }
            return item?.panicLevel.map { "panic ≥ \(Int($0))" } ?? ""
        case .stock:
            let item = data.first { $0.category == .stock }
            return item?.dailyThreshold.map { "daily \(Int($0))%" } ?? ""
        }
    }

    private func toggleExpand(_ symbol: String) {
        if expandedSymbols.contains(symbol) {
            expandedSymbols.remove(symbol)
        } else {
            expandedSymbols.insert(symbol)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(appDelegate.isChecking ? "Checking markets..." : "Waiting for first check")
                .font(.system(size: 13))
                .foregroundColor(Theme.ink3)
            if appDelegate.isChecking {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Footer

    private var popoverFooter: some View {
        HStack(spacing: 6) {
            Button(action: { Task { await appDelegate.performCheck() } }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text("Check now")
                    Text("⌘R")
                        .font(Theme.mono(size: 10.5))
                        .foregroundColor(Theme.paper.opacity(0.5))
                }
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(Theme.paper)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: { appDelegate.openSettings() }) {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                    Text("Settings")
                }
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(Theme.ink2)
                .padding(.horizontal, 10)
                .frame(height: 28)
            }
            .buttonStyle(.plain)

            Button(action: { appDelegate.quitApp() }) {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 11))
                    Text("Quit")
                }
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(Theme.ink2)
                .padding(.horizontal, 10)
                .frame(height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.paper2)
        .overlay(alignment: .top) { Divider() }
    }
}

// MARK: - Market Row

struct MarketRow: View {
    let item: MarketDataItem
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                toggleCircle
                    .frame(width: 16)

                Text(item.symbol)
                    .font(Theme.mono(size: 12, weight: .medium))
                    .foregroundColor(Theme.ink)
                    .frame(width: 76, alignment: .leading)

                HStack(spacing: 0) {
                    Text(item.name)
                        .font(.system(size: 12.5))
                        .foregroundColor(Theme.ink2)
                    if let shares = item.shares {
                        Text(" · \(shares) sh")
                            .font(Theme.mono(size: 10.5))
                            .foregroundColor(Theme.ink4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

                if let price = item.price {
                    Text(Theme.formatPrice(price))
                        .font(Theme.mono(size: 12))
                        .monospacedDigit()
                        .foregroundColor(Theme.ink)
                }

                ChangePill(pct: item.dailyPct, isStrong: item.isAlert)
                    .frame(width: 64, alignment: .trailing)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, Theme.spaceLG)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .background(rowBackground)
            .overlay(alignment: .leading) {
                if item.isAlert {
                    Rectangle().fill(Theme.down).frame(width: 2)
                }
            }

            if isExpanded {
                RowDetail(item: item)
            }
        }
        .opacity(item.enabled ? 1.0 : 0.42)
    }

    private var toggleCircle: some View {
        ZStack {
            Circle()
                .strokeBorder(item.enabled ? Theme.ink : Theme.inkFaint, lineWidth: 1.25)
                .frame(width: 12, height: 12)
            if item.enabled {
                Circle()
                    .fill(Theme.ink)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Theme.paper)
                    .frame(width: 5, height: 5)
            }
        }
    }

    private var rowBackground: some View {
        Group {
            if item.isAlert {
                Theme.downTint
            } else if isExpanded {
                Theme.paper2
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - Change Pill

struct ChangePill: View {
    let pct: Double?
    var isStrong: Bool = false

    var body: some View {
        Text(Theme.formatChange(pct))
            .font(Theme.mono(size: 12, weight: .medium))
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(pillBackground)
            .foregroundColor(pillColor)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusXS))
    }

    private var pillBackground: some View {
        Group {
            if isStrong, let pct, pct < 0 {
                Theme.down
            } else if let pct {
                pct >= 0 ? Theme.up.opacity(0.08) : Theme.down.opacity(0.08)
            } else {
                Theme.paper3
            }
        }
    }

    private var pillColor: Color {
        if isStrong, let pct, pct < 0 { return Theme.paper }
        guard let pct else { return Theme.ink3 }
        return pct >= 0 ? Theme.up : Theme.down
    }
}

// MARK: - Row Detail

struct RowDetail: View {
    let item: MarketDataItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailGrid
            thresholdBar
        }
        .padding(.horizontal, Theme.spaceLG)
        .padding(.leading, 26)
        .padding(.vertical, Theme.spaceSM)
        .background(item.isAlert ? Theme.down.opacity(0.05) : Theme.paper2)
    }

    @ViewBuilder
    private var detailGrid: some View {
        if item.category == .vix {
            HStack(spacing: 16) {
                detailCell("LEVEL", value: item.price.map { String(format: "%.2f", $0) } ?? "—", isDown: (item.dailyPct ?? 0) > 10)
                detailCell("PANIC AT", value: item.panicLevel.map { String(format: "%.0f", $0) } ?? "—", isDown: false)
                detailCell("HEADROOM", value: headroom, isDown: false)
            }
        } else if item.shares != nil {
            HStack(spacing: 16) {
                detailCell("POSITION", value: positionValue, isDown: false)
                detailCell("DAY P/L", value: dayPLValue, isDown: (item.dailyPct ?? 0) < 0)
                detailCell("TRIGGER", value: item.dailyThreshold.map { String(format: "%.0f%%", $0) } ?? "—", isDown: item.isAlert)
            }
        } else {
            HStack(spacing: 16) {
                detailCell("TODAY", value: Theme.formatChange(item.dailyPct), isDown: (item.dailyPct ?? 0) < 0)
                detailCell("THIS WEEK", value: Theme.formatChange(item.weeklyPct), isDown: (item.weeklyPct ?? 0) < 0)
                detailCell("PRICE", value: item.price.map { Theme.formatPrice($0) } ?? "—", isDown: false)
            }
        }
    }

    private func detailCell(_ label: String, value: String, isDown: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Theme.ink4)
            Text(value)
                .font(Theme.mono(size: 12))
                .foregroundColor(isDown ? Theme.down : Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var thresholdBar: some View {
        if item.category == .vix, let price = item.price, let panic = item.panicLevel {
            let fill = min(price / panic, 1.0)
            ThresholdBar(label: "to panic", fillPct: fill, markPct: 1.0, remaining: "+\(Int((panic - price) / price * 100))%")
        } else if let pct = item.dailyPct, let threshold = item.dailyThreshold {
            if item.isAlert {
                let markPct = abs(threshold) / abs(pct)
                ThresholdBar(label: "past trigger", fillPct: 1.0, markPct: markPct, remaining: String(format: "%.1f over", abs(pct) - abs(threshold)))
            } else {
                let fill = min(abs(pct) / abs(threshold), 1.0)
                let remaining = abs(threshold) - abs(pct)
                ThresholdBar(label: "to trigger", fillPct: fill, markPct: 1.0, remaining: String(format: "−%.2f%%", remaining))
            }
        }
    }

    private var headroom: String {
        guard let price = item.price, let panic = item.panicLevel else { return "—" }
        return String(format: "%.1f", panic - price)
    }

    private var positionValue: String {
        guard let price = item.price, let shares = item.shares else { return "—" }
        return Theme.formatMoney(Double(shares) * price)
    }

    private var dayPLValue: String {
        guard let price = item.price, let shares = item.shares, let pct = item.dailyPct else { return "—" }
        let prev = price / (1 + pct / 100)
        return Theme.formatMoney(Double(shares) * (price - prev))
    }
}

// MARK: - Threshold Bar

struct ThresholdBar: View {
    let label: String
    let fillPct: Double
    let markPct: Double
    let remaining: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Theme.mono(size: 10.5))
                .foregroundColor(Theme.ink4)
                .fixedSize()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.paper3)
                        .frame(height: 4)
                    Capsule()
                        .fill(Theme.down)
                        .frame(width: geo.size.width * fillPct, height: 4)
                    Rectangle()
                        .fill(Theme.ink4)
                        .frame(width: 1, height: 8)
                        .offset(x: geo.size.width * markPct - 0.5)
                }
            }
            .frame(height: 8)

            Text(remaining)
                .font(Theme.mono(size: 10.5))
                .foregroundColor(Theme.ink4)
                .fixedSize()
        }
    }
}
