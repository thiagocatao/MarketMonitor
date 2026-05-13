# Security Review

**Reviewed:** 2026-05-13
**Scope:** Full source audit of MarketMonitor v1.0
**Reviewer:** Claude Opus 4.6

---

## Summary

MarketMonitor is a local-only macOS menu bar app with no inbound attack surface — it makes outbound HTTP requests and stores configuration locally. The primary security concern is **plaintext storage of API keys and tokens** on disk. The overall risk profile is low for a personal-use desktop tool, but there are concrete improvements worth making.

| Severity | Count | Key theme |
|----------|-------|-----------|
| Critical | 1 | Secrets stored in plaintext |
| High | 1 | API key leaked in URL query parameter |
| Medium | 3 | File permissions, URL validation, unsanitized URL interpolation |
| Low | 4 | Missing HTTPS enforcement, no response validation, prompt injection surface, no rate limiting |
| Info | 2 | No App Sandbox, no code signing |

---

## Findings

### [C-01] Secrets stored in plaintext JSON on disk

**Severity:** Critical
**File:** `Sources/MarketMonitor/Services/ConfigManager.swift:28-33`

All secrets — Telegram bot tokens, Slack/Discord webhook URLs, and LLM API keys (OpenAI, Anthropic, Gemini) — are written to `~/Library/Application Support/MarketMonitor/config.json` as plaintext JSON using default file permissions.

Any process running as the current user can read this file. A malicious app, browser extension with filesystem access, or compromised tool in the user's PATH could exfiltrate these credentials silently.

**Recommendation:** Store secrets in macOS Keychain via the Security framework. Keep non-sensitive config (watchlist, thresholds, intervals) in the JSON file, but move `botToken`, `chatId`, `webhookUrl`, and `apiKey` to Keychain items keyed by a service identifier like `com.thiago.MarketMonitor`.

---

### [H-01] Gemini API key passed as URL query parameter

**Severity:** High
**File:** `Sources/MarketMonitor/Services/LLMAnalyzer.swift:23`

```swift
let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
```

The Gemini API key is embedded in the URL as a query parameter. While this is Google's documented API pattern, query parameters can leak through:
- Proxy server logs
- Network monitoring tools
- macOS `nsurlsessiond` logs
- Crash reports containing URL strings

**Recommendation:** This is a limitation of Google's API design. Document it as a known tradeoff. For users concerned about key exposure, recommend using the OpenAI or Anthropic providers, which both send keys via HTTP headers.

---

### [M-01] Config file written with default permissions

**Severity:** Medium
**File:** `Sources/MarketMonitor/Services/ConfigManager.swift:32`

```swift
try? data.write(to: configFileURL)
```

`Data.write(to:)` uses default file permissions (typically `0644`), meaning other user accounts on a shared Mac could read the config file containing secrets.

**Recommendation:** Set restrictive permissions when writing:

```swift
try? data.write(to: configFileURL, options: [.atomic])
FileManager.default.setAttributes(
    [.posixPermissions: 0o600],
    ofItemAtPath: configFileURL.path
)
```

---

### [M-02] No HTTPS enforcement on webhook URLs

**Severity:** Medium
**File:** `Sources/MarketMonitor/Services/NotificationService.swift:58,76`

Slack and Discord webhook URLs are accepted from user config without scheme validation. A user could accidentally configure `http://` instead of `https://`, causing alert data (including portfolio details and holdings) to be sent in cleartext.

**Recommendation:** Validate that webhook URLs use the `https` scheme before sending. Reject or warn on `http://` URLs.

---

### [M-03] LLM model name interpolated into URL without validation

**Severity:** Medium
**File:** `Sources/MarketMonitor/Services/LLMAnalyzer.swift:23`

```swift
let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
```

The `model` string from user config is interpolated directly into the URL path. A crafted model name containing path separators or query characters could alter the target endpoint.

**Recommendation:** Validate the model name against an allowlist or sanitize it with `addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)`.

---

### [L-01] No response body validation on notification sends

**Severity:** Low
**File:** `Sources/MarketMonitor/Services/NotificationService.swift`

All three notification methods (Telegram, Slack, Discord) check only the HTTP status code and discard the response body. Error details from the API (rate limits, invalid tokens, malformed payloads) are silently lost.

**Recommendation:** Log or surface response body details on non-2xx responses so users can diagnose configuration issues.

---

### [L-02] LLM prompt injection surface

**Severity:** Low
**File:** `Sources/MarketMonitor/Services/LLMAnalyzer.swift:8`

Alert text (including symbol names and price data) is interpolated directly into the LLM prompt:

```swift
let prompt = "... Based on these crash alerts, provide a 2-3 sentence analysis ... \(alertsText)"
```

Since all data originates from Yahoo Finance API responses and user-configured symbol names, the practical risk is negligible. However, if Yahoo Finance returned manipulated data in the `shortName` field, it could influence LLM output.

**Recommendation:** Acceptable risk for current use case. No action needed.

---

### [L-03] No rate limiting on manual checks

**Severity:** Low
**File:** `Sources/MarketMonitor/App/AppDelegate.swift:100-101`

The `isChecking` guard prevents overlapping checks, but rapid sequential taps of "Check now" could trigger many requests to Yahoo Finance in quick succession, potentially triggering IP-based rate limits.

**Recommendation:** Add a minimum cooldown (e.g., 30 seconds) between manual checks, or debounce the button.

---

### [L-04] User-Agent spoofing

**Severity:** Low
**File:** `Sources/MarketMonitor/Services/MarketChecker.swift:19`

```swift
config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0"]
```

The app spoofs a browser User-Agent when calling Yahoo Finance. This works around bot detection but could violate Yahoo Finance's Terms of Service.

**Recommendation:** Acceptable tradeoff for personal use. Be aware that Yahoo may change their detection and break this approach.

---

### [I-01] No App Sandbox

**Severity:** Info

The app runs without macOS App Sandbox entitlements, giving it full access to the user's filesystem and network. This is standard for developer-built menu bar tools and necessary for writing to Application Support, but it means the app cannot be distributed via the Mac App Store without changes.

---

### [I-02] No code signing

**Severity:** Info
**File:** `Scripts/build.sh`

The build script produces an unsigned `.app` bundle. Users must bypass Gatekeeper on first launch. This is expected for personal/developer builds but should be addressed before any distribution.

---

## Threat Model

| Threat | Likelihood | Impact | Mitigation |
|--------|-----------|--------|------------|
| Local process reads config.json secrets | Medium | High | Keychain storage (C-01), file permissions (M-01) |
| Network observer reads API key | Low | Medium | Keys sent via HTTPS; Gemini key in URL is the exception (H-01) |
| Webhook data sent over HTTP | Low | Medium | Enforce HTTPS (M-02) |
| Yahoo Finance API abuse detection | Low | Low | Rate limiting (L-03), honest User-Agent |
| Compromised LLM response | Very Low | Low | LLM output is display-only, not executed |

## Data Flow

```
User config (disk)
    │
    ├── Secrets: bot tokens, webhook URLs, API keys
    │       → Should be in Keychain
    │
    └── Non-sensitive: watchlist, thresholds, interval
            → JSON file is fine

Outbound requests:
    App ──GET──→  Yahoo Finance (chart API, no auth)
    App ──POST──→ Telegram / Slack / Discord (tokens/webhooks in request)
    App ──POST──→ Gemini / OpenAI / Anthropic (API keys in headers or URL)
```

No inbound network connections. No IPC. No file watchers on external paths. No JavaScript evaluation.

## Recommended Priority

1. **Move secrets to Keychain** — highest impact, eliminates the most realistic attack vector
2. **Set file permissions to 0600** — quick win, one line of code
3. **Validate webhook URLs use HTTPS** — simple guard, prevents user error
4. **Sanitize model name in Gemini URL** — defense in depth
