import SwiftUI

struct GeneralTab: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var appDelegate: AppDelegate

    let intervals = [5, 10, 15, 30, 60]
    let defaultModels: [LLMProvider: String] = [
        .gemini: "gemini-2.0-flash",
        .openai: "gpt-4o-mini",
        .anthropic: "claude-sonnet-4-6",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    scheduleSection
                    Divider()
                    llmSection
                    Divider()
                    pythonSection
                }
                .padding(.horizontal, Theme.spaceXL)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
        }
        .onDisappear { configManager.save() }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SCHEDULE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Theme.ink4)

            HStack(spacing: 8) {
                Text("Check every")
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.ink2)

                HStack(spacing: 2) {
                    ForEach(intervals, id: \.self) { min in
                        Button(action: {
                            configManager.config.general.checkIntervalMinutes = min
                            configManager.save()
                            appDelegate.startPeriodicChecks()
                        }) {
                            Text("\(min)m")
                                .font(Theme.mono(size: 11.5, weight: .medium))
                                .foregroundColor(configManager.config.general.checkIntervalMinutes == min ? Theme.paper : Theme.ink3)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(configManager.config.general.checkIntervalMinutes == min ? Theme.ink : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusXS))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Theme.paper3)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
            }
        }
    }

    // MARK: - LLM

    private var llmSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AI ANALYSIS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundColor(Theme.ink4)

                Spacer()

                Button(action: {
                    configManager.config.llm.enabled.toggle()
                    configManager.save()
                }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(configManager.config.llm.enabled ? Theme.up : Theme.inkFaint)
                            .frame(width: 6, height: 6)
                        Text(configManager.config.llm.enabled ? "On" : "Off")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(configManager.config.llm.enabled ? Theme.up : Theme.ink4)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(configManager.config.llm.enabled ? Theme.upTint : Theme.paper3)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if configManager.config.llm.enabled {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Provider")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.ink3)
                            .frame(width: 60, alignment: .trailing)

                        HStack(spacing: 2) {
                            ForEach(LLMProvider.allCases, id: \.self) { provider in
                                Button(action: {
                                    configManager.config.llm.provider = provider
                                    configManager.config.llm.model = defaultModels[provider] ?? ""
                                    configManager.save()
                                }) {
                                    Text(provider.rawValue.capitalized)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundColor(configManager.config.llm.provider == provider ? Theme.paper : Theme.ink3)
                                        .padding(.horizontal, 10)
                                        .frame(height: 24)
                                        .background(configManager.config.llm.provider == provider ? Theme.ink : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusXS))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(2)
                        .background(Theme.paper3)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                    }

                    HStack(spacing: 8) {
                        Text("Model")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.ink3)
                            .frame(width: 60, alignment: .trailing)
                        TextField("", text: $configManager.config.llm.model)
                            .font(Theme.mono(size: 13))
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 8) {
                        Text("API Key")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.ink3)
                            .frame(width: 60, alignment: .trailing)
                        SecureField("", text: $configManager.config.llm.apiKey)
                            .font(Theme.mono(size: 13))
                            .textFieldStyle(.roundedBorder)
                    }
                }
            } else {
                Text("Enrich crash alerts with AI-generated analysis when triggered.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.ink4)
            }
        }
    }

    // MARK: - Python

    private var pythonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PYTHON")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Theme.ink4)

            HStack(spacing: 8) {
                Text("Path")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.ink3)
                    .frame(width: 60, alignment: .trailing)
                TextField("/opt/homebrew/bin/python3", text: $configManager.config.general.pythonPath)
                    .font(Theme.mono(size: 13))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}
