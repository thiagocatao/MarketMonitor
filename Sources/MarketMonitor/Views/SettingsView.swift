import SwiftUI

enum SettingsTab: String, CaseIterable {
    case watchlist, notifications, general

    var label: String {
        switch self {
        case .watchlist: return "Watchlist"
        case .notifications: return "Notifications"
        case .general: return "General"
        }
    }

    var icon: String {
        switch self {
        case .watchlist: return "list.bullet"
        case .notifications: return "bell"
        case .general: return "gearshape"
        }
    }
}

struct SettingsView: View {
    @State private var tab: SettingsTab = .watchlist

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            Divider()
            Group {
                switch tab {
                case .watchlist: WatchlistTab()
                case .notifications: NotificationsTab()
                case .general: GeneralTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 580, height: 520)
        .background(Theme.paper)
    }

    private var settingsHeader: some View {
        HStack(spacing: 0) {
            Text("Settings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.ink)

            Spacer()

            HStack(spacing: 2) {
                ForEach(SettingsTab.allCases, id: \.self) { t in
                    Button(action: { withAnimation(.easeInOut(duration: 0.12)) { tab = t } }) {
                        HStack(spacing: 5) {
                            Image(systemName: t.icon)
                                .font(.system(size: 10.5))
                            Text(t.label)
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(tab == t ? Theme.paper : Theme.ink3)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(tab == t ? Theme.ink : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Theme.paper3)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM + 2))
        }
        .padding(.horizontal, Theme.spaceXL)
        .padding(.vertical, 14)
    }
}
