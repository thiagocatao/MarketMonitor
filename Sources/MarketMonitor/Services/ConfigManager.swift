import Foundation

@MainActor
final class ConfigManager: ObservableObject {
    @Published var config: AppConfig

    let configFileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MarketMonitor")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        configFileURL = appDir.appendingPathComponent("config.json")

        if let data = try? Data(contentsOf: configFileURL) {
            if let loaded = try? JSONDecoder().decode(AppConfig.self, from: data) {
                config = loaded
            } else {
                config = AppConfig.defaultConfig
                print("WARNING: config.json is malformed — using defaults. Fix or delete the file to regenerate.")
            }
        } else {
            config = AppConfig.defaultConfig
            save()
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: configFileURL)
    }
}
