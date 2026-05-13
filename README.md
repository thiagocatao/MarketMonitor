# MarketMonitor

A native macOS menu bar app that watches global markets and alerts you only when things go seriously wrong.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)
![Swift](https://img.shields.io/badge/Swift-5.10-orange)
![Python](https://img.shields.io/badge/Python-3.x-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## What it does

MarketMonitor lives in your menu bar as a **$** icon. It periodically checks stock indices, futures, VIX, and individual holdings against crash-level thresholds you define. If nothing is wrong, it does nothing. If a threshold is breached, it turns red and sends you a notification.

**This app is designed to almost never fire.** It's not a trading terminal or a ticker — it's a silent watchdog for tail-risk events.

## Features

- **Menu bar popover** with live market data, portfolio summary, and expandable detail rows
- **Per-symbol thresholds** — daily drop %, weekly drop %, VIX panic level
- **Multi-platform notifications** — Telegram, Slack, or Discord
- **Optional AI analysis** — enrich crash alerts with context from Gemini, OpenAI, or Anthropic
- **Custom design system** — clean black/white/green/red aesthetic with monospaced data display
- **Configurable check interval** — 5 to 60 minutes
- **Zero external Swift dependencies** — pure SwiftUI + Foundation

## Screenshot

```
┌─────────────────────────────────┐
│  ● All clear                    │
│  last check 2 min ago · next 28m│
├─────────────────────────────────┤
│  PORTFOLIO    DAY P/L    VIX    │
│  $56,606      +$1,030    17.79  │
├─────────────────────────────────┤
│  All  Alerts  Indices  Futures  │
├─────────────────────────────────┤
│  INDICES          daily -4%     │
│  ● ^GSPC  S&P 500    +0.58%    │
│  ● ^IXIC  NASDAQ     +1.20%    │
│  ● ^N225  Nikkei     +0.52%    │
│                                 │
│  HOLDINGS         daily -10%    │
│  ● GOOGL  Alphabet   +3.94%    │
│  ● NVDA   NVIDIA     +2.29%    │
│  ● SHOP   Shopify    -4.45%    │
├─────────────────────────────────┤
│  [Check now]    Settings   Quit │
└─────────────────────────────────┘
```

## Architecture

```
Swift (UI + orchestration)          Python (data)
┌──────────────────────┐           ┌──────────────────┐
│  AppDelegate         │──spawn──▶ │  market_monitor.py │
│  PopoverView         │◀──JSON──  │  (yfinance)        │
│  SettingsView        │           └──────────────────┘
│  NotificationService │──POST──▶  Telegram / Slack / Discord
│  LLMAnalyzer         │──POST──▶  Gemini / OpenAI / Anthropic
└──────────────────────┘
```

- **Swift** handles all UI, scheduling, notifications, and LLM calls
- **Python** is called as a subprocess purely for market data fetching via [yfinance](https://github.com/ranaroussi/yfinance)
- Shared config at `~/Library/Application Support/MarketMonitor/config.json`

## Getting started

### Prerequisites

- macOS 14 (Sonoma) or later
- Swift 5.10+ (included with Xcode 15.3+)
- Python 3 with yfinance: `pip3 install yfinance`

### Build and run

```bash
git clone https://github.com/tcatao/MarketMonitor.git
cd MarketMonitor

# Development
swift build && swift run

# Production .app bundle
chmod +x Scripts/build.sh
./Scripts/build.sh
open build/MarketMonitor.app

# Install to Applications
cp -R build/MarketMonitor.app /Applications/
```

The app runs as a menu bar agent (no Dock icon). Click the **$** to open the popover.

### Default watchlist

| Symbol | Name | Category | Threshold |
|--------|------|----------|-----------|
| ^GSPC | S&P 500 | Index | Daily -4%, Weekly -7% |
| ^IXIC | NASDAQ | Index | Daily -4%, Weekly -7% |
| ^VIX | VIX | Volatility | Panic >= 35 |
| ^N225 | Nikkei 225 | Index | Daily -4% |
| ^HSI | Hang Seng | Index | Daily -4% |
| 000001.SS | Shanghai | Index | Daily -4% |
| ES=F | S&P Futures | Futures | Daily -3% |
| NQ=F | NASDAQ Futures | Futures | Daily -3% |
| GOOGL | Alphabet | Stock | Daily -10% |
| NVDA | NVIDIA | Stock | Daily -10% |
| SHOP | Shopify | Stock | Daily -10% |

All symbols, thresholds, and share counts are fully configurable in Settings.

## Configuration

Everything is managed through the Settings window (click Settings in the popover footer):

- **Watchlist** — Add/remove symbols, set per-symbol daily/weekly thresholds, VIX panic levels, share counts
- **Notifications** — Choose Telegram, Slack, or Discord. Enter credentials. Send a test notification.
- **General** — Check interval, AI analysis provider + API key, Python path

Config is stored as JSON at `~/Library/Application Support/MarketMonitor/config.json`.

## How alerts work

Every check cycle, MarketMonitor fetches current prices and calculates percentage changes:

1. **Daily drop** — current price vs previous close
2. **Weekly drop** — current price vs 5-day-ago close
3. **VIX panic** — absolute level above threshold

If any symbol breaches its threshold, the **$** turns red, an alert banner appears in the popover, and a notification is sent to your configured platform. Duplicate alerts are suppressed for the same trading day.

When AI analysis is enabled, crash alerts are enriched with a brief LLM-generated assessment before being sent.

## Project structure

```
MarketMonitor/
├── Package.swift
├── Sources/MarketMonitor/
│   ├── App/
│   │   ├── MarketMonitorApp.swift    # @main entry point
│   │   └── AppDelegate.swift         # Menu bar, popover, scheduling
│   ├── Design/
│   │   └── DesignTokens.swift        # Theme colors, spacing, typography
│   ├── Models/
│   │   └── AppConfig.swift           # Codable config, alerts, market data
│   ├── Services/
│   │   ├── ConfigManager.swift       # Load/save config.json
│   │   ├── MarketChecker.swift       # Python subprocess bridge
│   │   ├── NotificationService.swift # Telegram, Slack, Discord
│   │   └── LLMAnalyzer.swift         # Gemini, OpenAI, Anthropic
│   └── Views/
│       ├── PopoverView.swift         # Main popover UI
│       ├── SettingsView.swift         # Settings window
│       ├── WatchlistTab.swift         # Symbol management
│       ├── NotificationsTab.swift     # Notification config
│       └── GeneralTab.swift           # Interval, AI, Python path
└── Scripts/
    ├── market_monitor.py             # yfinance data engine
    └── build.sh                      # .app bundle builder
```

## License

MIT
