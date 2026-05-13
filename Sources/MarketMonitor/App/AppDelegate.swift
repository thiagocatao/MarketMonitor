import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    let configManager = ConfigManager()
    private var checkTask: Task<Void, Never>?
    private var alertedToday: [String: Date] = [:]
    private var settingsWindow: NSWindow?
    private var popover: NSPopover!

    @Published var lastCheckTime: String = "Never"
    @Published var lastCheckDate: Date?
    @Published var activeAlerts: [MarketAlert] = []
    @Published var marketData: [MarketDataItem] = []
    @Published var lastError: String?
    @Published var isChecking = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        startPeriodicChecks()
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon(hasAlerts: false)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        setupPopover()
    }

    private func setupPopover() {
        let view = PopoverView()
            .environmentObject(configManager)
            .environmentObject(self)
        let controller = NSHostingController(rootView: view)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 560)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = controller
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateIcon(hasAlerts: Bool) {
        guard let button = statusItem.button else { return }
        if hasAlerts {
            button.attributedTitle = NSAttributedString(
                string: "$",
                attributes: [
                    .foregroundColor: NSColor.systemRed,
                    .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold),
                ]
            )
        } else {
            button.attributedTitle = NSAttributedString(
                string: "$",
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .medium),
                ]
            )
        }
    }

    // MARK: - Scheduling

    func startPeriodicChecks() {
        checkTask?.cancel()
        checkTask = Task {
            await performCheck()
            while !Task.isCancelled {
                let seconds = configManager.config.general.checkIntervalMinutes * 60
                try? await Task.sleep(for: .seconds(seconds))
                if !Task.isCancelled {
                    await performCheck()
                }
            }
        }
    }

    // MARK: - Market Check

    func performCheck() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        let result = await MarketChecker.check(watchlist: configManager.config.watchlist)

        lastCheckTime = result.timestamp
        lastCheckDate = Date()
        lastError = result.errors.isEmpty ? nil : result.errors.joined(separator: "; ")
        marketData = result.marketData

        let today = Calendar.current.startOfDay(for: Date())
        alertedToday = alertedToday.filter { $0.value >= today }

        activeAlerts = result.alerts

        if !result.alerts.isEmpty {
            updateIcon(hasAlerts: true)
            let newAlerts = result.alerts.filter { alertedToday[$0.symbol] == nil }
            for alert in newAlerts {
                alertedToday[alert.symbol] = Date()
            }
            if !newAlerts.isEmpty {
                await sendNotifications(for: newAlerts)
            }
        } else {
            updateIcon(hasAlerts: false)
        }
    }

    private func sendNotifications(for alerts: [MarketAlert]) async {
        let alertsText = alerts.map { "[\($0.type)] \($0.detail)" }.joined(separator: "\n")
        var message = "*MARKET CRASH ALERT*\n_\(lastCheckTime)_\n\n\(alertsText)"

        if configManager.config.llm.enabled, !configManager.config.llm.apiKey.isEmpty {
            if let analysis = try? await LLMAnalyzer.analyze(
                alertsText: alertsText,
                config: configManager.config.llm,
                holdings: configManager.config.watchlist.filter { $0.category == .stock }.map(\.symbol)
            ) {
                message += "\n\n*Analysis:*\n\(analysis)"
            }
        }

        message += "\n\nReview your portfolio positions."

        try? await NotificationService.send(
            message: message,
            config: configManager.config.notifications
        )
    }

    // MARK: - Actions

    func openSettings() {
        popover?.performClose(nil)

        if settingsWindow == nil {
            let view = SettingsView()
                .environmentObject(configManager)
                .environmentObject(self)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = "MarketMonitor Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 580, height: 460))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func quitApp() {
        NSApp.terminate(nil)
    }
}
