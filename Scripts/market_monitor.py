#!/usr/bin/env python3
"""
Market Crash Monitor — data engine.
Called by the MarketMonitor.app as a subprocess.
Reads config.json, checks market data via yfinance, outputs JSON to stdout.

Usage:
    python3 market_monitor.py --config /path/to/config.json --mode full
"""

import argparse
import json
import math
import sys
from datetime import datetime, timezone

import yfinance as yf


def sanitize(value):
    """Convert NaN/Inf to None for valid JSON output."""
    if value is None:
        return None
    if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
        return None
    return value


MODE_CATEGORIES = {
    "asian": {"index"},
    "premarket": {"futures", "vix"},
    "close": {"index", "stock", "vix"},
    "full": None,
}


def get_price_data(ticker, period="5d"):
    try:
        data = yf.Ticker(ticker).history(period=period)
        if data.empty:
            return None
        current = float(data["Close"].iloc[-1])
        if math.isnan(current):
            return None
        result = {"price": round(current, 2), "daily_pct": None, "weekly_pct": None}
        if len(data) >= 2:
            prev = float(data["Close"].iloc[-2])
            if not math.isnan(prev) and prev != 0:
                result["daily_pct"] = round((current - prev) / prev * 100, 2)
        if len(data) >= 5:
            week_open = float(data["Close"].iloc[0])
            if not math.isnan(week_open) and week_open != 0:
                result["weekly_pct"] = round((current - week_open) / week_open * 100, 2)
        return result
    except Exception as e:
        print(f"WARNING: Failed to fetch {ticker}: {e}", file=sys.stderr)
        return None


def process_item(item):
    """Fetch data and check thresholds for a single watchlist item."""
    symbol = item["symbol"]
    name = item["name"]
    category = item.get("category", "stock")
    enabled = item.get("enabled", True)
    alerts = []

    data = None
    if enabled:
        period = "2d" if category == "futures" else "5d"
        data = get_price_data(symbol, period)

    if data and enabled:
        if category == "vix":
            panic_level = item.get("panicLevel", 35)
            if data["price"] >= panic_level:
                alerts.append({
                    "type": "VIX_PANIC",
                    "symbol": symbol,
                    "name": name,
                    "detail": f"{name} at {data['price']} — above {panic_level}",
                    "dailyPct": data["daily_pct"],
                    "weeklyPct": data["weekly_pct"],
                    "price": data["price"],
                })
        else:
            daily_threshold = item.get("dailyThreshold")
            if daily_threshold is not None and data["daily_pct"] is not None:
                if data["daily_pct"] <= daily_threshold:
                    shares_info = f" — you hold {item['shares']} shares" if item.get("shares") else ""
                    alerts.append({
                        "type": f"{category.upper()}_CRASH",
                        "symbol": symbol,
                        "name": name,
                        "detail": f"{name} ({symbol}) dropped {data['daily_pct']:.1f}% today (price: {data['price']}){shares_info}",
                        "dailyPct": data["daily_pct"],
                        "weeklyPct": data["weekly_pct"],
                        "price": data["price"],
                    })

            weekly_threshold = item.get("weeklyThreshold")
            if weekly_threshold is not None and data.get("weekly_pct") is not None:
                if data["weekly_pct"] <= weekly_threshold:
                    alerts.append({
                        "type": "SUSTAINED_DECLINE",
                        "symbol": symbol,
                        "name": name,
                        "detail": f"{name} ({symbol}) down {data['weekly_pct']:.1f}% this week (price: {data['price']})",
                        "dailyPct": data["daily_pct"],
                        "weeklyPct": data["weekly_pct"],
                        "price": data["price"],
                    })

    market_entry = {
        "symbol": symbol,
        "name": name,
        "category": category,
        "enabled": enabled,
        "price": data["price"] if data else None,
        "dailyPct": data["daily_pct"] if data else None,
        "weeklyPct": data.get("weekly_pct") if data else None,
        "shares": item.get("shares"),
        "dailyThreshold": item.get("dailyThreshold"),
        "weeklyThreshold": item.get("weeklyThreshold"),
        "panicLevel": item.get("panicLevel"),
        "isAlert": len(alerts) > 0,
    }

    return alerts, market_entry


def run(config, mode):
    watchlist = config.get("watchlist", [])
    allowed = MODE_CATEGORIES.get(mode)
    if allowed is not None:
        watchlist = [item for item in watchlist if item.get("category", "stock") in allowed]

    all_alerts = []
    market_data = []
    errors = []
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    for item in watchlist:
        try:
            alerts, entry = process_item(item)
            all_alerts.extend(alerts)
            market_data.append(entry)
        except Exception as e:
            errors.append(f"{item.get('symbol', '?')}: {e}")

    return {
        "timestamp": timestamp,
        "mode": mode,
        "alert_count": len(all_alerts),
        "alerts": all_alerts,
        "market_data": market_data,
        "errors": errors,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Market Crash Monitor")
    parser.add_argument("--config", required=True, help="Path to config.json")
    parser.add_argument("--mode", default="full", choices=["asian", "premarket", "close", "full"])
    args = parser.parse_args()

    with open(args.config) as f:
        config = json.load(f)

    result = run(config, args.mode)
    print(json.dumps(result))
