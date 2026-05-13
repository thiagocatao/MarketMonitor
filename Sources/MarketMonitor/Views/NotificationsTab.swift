import SwiftUI

private enum PlatformBrand {
    static func color(_ platform: NotificationPlatform) -> Color {
        switch platform {
        case .telegram: return Color(red: 38/255, green: 166/255, blue: 222/255)
        case .slack: return Color(red: 74/255, green: 21/255, blue: 75/255)
        case .discord: return Color(red: 88/255, green: 101/255, blue: 242/255)
        }
    }

    static func tint(_ platform: NotificationPlatform) -> Color {
        color(platform).opacity(0.08)
    }

    static func icon(_ platform: NotificationPlatform) -> String {
        switch platform {
        case .telegram: return "paperplane.fill"
        case .slack: return "number"
        case .discord: return "bubble.left.fill"
        }
    }

    static func description(_ platform: NotificationPlatform) -> String {
        switch platform {
        case .telegram: return "Alerts sent via Telegram Bot API"
        case .slack: return "Alerts sent via Slack incoming webhook"
        case .discord: return "Alerts sent via Discord webhook"
        }
    }
}

struct NotificationsTab: View {
    @EnvironmentObject var configManager: ConfigManager

    @State private var testStatus: String?
    @State private var isTesting = false

    private var platform: NotificationPlatform {
        configManager.config.notifications.platform
    }

    private var isConfigured: Bool {
        switch platform {
        case .telegram:
            return !configManager.config.notifications.telegram.botToken.isEmpty
                && !configManager.config.notifications.telegram.chatId.isEmpty
        case .slack:
            return !configManager.config.notifications.slack.webhookUrl.isEmpty
        case .discord:
            return !configManager.config.notifications.discord.webhookUrl.isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    platformPicker
                    platformCard
                    testSection
                }
                .padding(.horizontal, Theme.spaceXL)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }

            Spacer()
        }
        .onDisappear { configManager.save() }
    }

    // MARK: - Platform Picker

    private var platformPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PLATFORM")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Theme.ink4)

            HStack(spacing: 6) {
                ForEach(NotificationPlatform.allCases, id: \.self) { p in
                    let selected = platform == p
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            configManager.config.notifications.platform = p
                            configManager.save()
                            testStatus = nil
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: PlatformBrand.icon(p))
                                .font(.system(size: 11))
                                .foregroundColor(selected ? PlatformBrand.color(p) : Theme.ink4)
                            Text(p.rawValue.capitalized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(selected ? Theme.ink : Theme.ink3)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(selected ? PlatformBrand.tint(p) : Theme.paper3)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusSM)
                                .strokeBorder(selected ? PlatformBrand.color(p).opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Platform Card

    private var platformCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: PlatformBrand.icon(platform))
                    .font(.system(size: 14))
                    .foregroundColor(PlatformBrand.color(platform))

                Text(platform.rawValue.capitalized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.ink)

                Spacer()

                statusBadge
            }

            Text(PlatformBrand.description(platform))
                .font(.system(size: 11.5))
                .foregroundColor(Theme.ink4)

            Divider()
                .overlay(PlatformBrand.color(platform).opacity(0.15))

            platformFields
        }
        .padding(Theme.spaceLG)
        .background(PlatformBrand.tint(platform))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .strokeBorder(PlatformBrand.color(platform).opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConfigured ? Theme.up : Theme.inkFaint)
                .frame(width: 6, height: 6)
            Text(isConfigured ? "Configured" : "Not configured")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(isConfigured ? Theme.up : Theme.ink4)
        }
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background(isConfigured ? Theme.upTint : Theme.paper3)
        .clipShape(Capsule())
    }

    // MARK: - Platform Fields

    @ViewBuilder
    private var platformFields: some View {
        switch platform {
        case .telegram:
            VStack(alignment: .leading, spacing: 12) {
                settingsField("Bot Token", placeholder: "123456:ABC-DEF...", secure: true, text: $configManager.config.notifications.telegram.botToken)
                settingsField("Chat ID", placeholder: "-1001234567890", secure: false, text: $configManager.config.notifications.telegram.chatId)
            }
        case .slack:
            settingsField("Webhook URL", placeholder: "https://hooks.slack.com/services/...", secure: false, text: $configManager.config.notifications.slack.webhookUrl)
        case .discord:
            settingsField("Webhook URL", placeholder: "https://discord.com/api/webhooks/...", secure: false, text: $configManager.config.notifications.discord.webhookUrl)
        }
    }

    private func settingsField(_ label: String, placeholder: String, secure: Bool, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Theme.ink4)

            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(Theme.mono(size: 12.5))
            .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Test

    private var testSection: some View {
        HStack(spacing: 10) {
            Button(action: sendTest) {
                HStack(spacing: 6) {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "paperplane")
                            .font(.system(size: 10.5))
                    }
                    Text("Send test notification")
                }
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(Theme.paper)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(isConfigured && !isTesting ? PlatformBrand.color(platform) : PlatformBrand.color(platform).opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
            }
            .buttonStyle(.plain)
            .disabled(!isConfigured || isTesting)

            if let status = testStatus {
                HStack(spacing: 5) {
                    Image(systemName: status == "Sent!" ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 11))
                    Text(status)
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(status == "Sent!" ? Theme.up : Theme.down)
                .lineLimit(1)
            }
        }
    }

    private func sendTest() {
        testStatus = nil
        isTesting = true
        Task {
            do {
                configManager.save()
                try await NotificationService.sendTest(config: configManager.config.notifications)
                testStatus = "Sent!"
            } catch {
                testStatus = error.localizedDescription
            }
            isTesting = false
        }
    }
}
