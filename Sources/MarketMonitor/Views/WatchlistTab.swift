import SwiftUI

struct WatchlistTab: View {
    @EnvironmentObject var configManager: ConfigManager
    @State private var selection: String?
    @State private var showingAddSheet = false
    @State private var editingItem: WatchlistItem?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    watchlistSection("INDICES", category: .index)
                    sectionDivider
                    watchlistSection("FUTURES", category: .futures)
                    sectionDivider
                    watchlistSection("VOLATILITY", category: .vix)
                    sectionDivider
                    watchlistSection("HOLDINGS", category: .stock)
                }
                .padding(.top, Theme.spaceSM)
            }

            Divider()

            HStack(spacing: 6) {
                Button(action: { showingAddSheet = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text("Add symbol")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.paper)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                }
                .buttonStyle(.plain)

                if selection != nil {
                    Button(action: { editSelected() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10.5))
                            Text("Edit")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.ink2)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Theme.paper3)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                    }
                    .buttonStyle(.plain)

                    Button(action: { removeSelected() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 10.5))
                            Text("Remove")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.down)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Theme.downTint)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text("\(configManager.config.watchlist.count) symbols")
                    .font(Theme.mono(size: 11))
                    .foregroundColor(Theme.ink4)
            }
            .padding(.horizontal, Theme.spaceLG)
            .padding(.vertical, 10)
            .background(Theme.paper2)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSymbolSheet(existingSymbols: Set(configManager.config.watchlist.map(\.symbol))) { newItem in
                configManager.config.watchlist.append(newItem)
                configManager.save()
            }
        }
        .sheet(item: $editingItem) { item in
            EditSymbolSheet(item: item) { updated in
                if let idx = configManager.config.watchlist.firstIndex(where: { $0.symbol == updated.symbol }) {
                    configManager.config.watchlist[idx] = updated
                    configManager.save()
                }
            }
        }
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(Theme.ink.opacity(0.2))
            .padding(.horizontal, Theme.spaceLG)
    }

    private func watchlistSection(_ title: String, category: ItemCategory) -> some View {
        let items = configManager.config.watchlist.filter { $0.category == category }
        return Group {
            if !items.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text(title)
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.4)
                            .foregroundColor(Theme.ink4)
                        Spacer()
                    }
                    .padding(.horizontal, Theme.spaceLG)
                    .padding(.vertical, 6)

                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        WatchlistSettingsRow(item: item, isSelected: selection == item.symbol) {
                            selection = selection == item.symbol ? nil : item.symbol
                        } onToggle: {
                            toggleItem(item.symbol)
                        }
                        if index < items.count - 1 {
                            Divider()
                                .overlay(Theme.ink.opacity(0.12))
                                .padding(.leading, 42)
                        }
                    }
                }
                .padding(.bottom, Theme.spaceSM)
            }
        }
    }

    private func toggleItem(_ symbol: String) {
        if let idx = configManager.config.watchlist.firstIndex(where: { $0.symbol == symbol }) {
            configManager.config.watchlist[idx].enabled.toggle()
            configManager.save()
        }
    }

    private func removeSelected() {
        guard let sel = selection else { return }
        configManager.config.watchlist.removeAll { $0.symbol == sel }
        configManager.save()
        selection = nil
    }

    private func editSelected() {
        guard let sel = selection,
              let item = configManager.config.watchlist.first(where: { $0.symbol == sel }) else { return }
        editingItem = item
    }
}

// MARK: - Watchlist Settings Row

struct WatchlistSettingsRow: View {
    let item: WatchlistItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(item.enabled ? Theme.up : Theme.inkFaint, lineWidth: 1.25)
                        .frame(width: 12, height: 12)
                    if item.enabled {
                        Circle()
                            .fill(Theme.up)
                            .frame(width: 12, height: 12)
                        Circle()
                            .fill(Theme.paper)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(width: 16)

            Text(item.symbol)
                .font(Theme.mono(size: 12, weight: .medium))
                .foregroundColor(Theme.up)
                .frame(width: 80, alignment: .leading)

            Text(item.name)
                .font(.system(size: 12.5))
                .foregroundColor(Theme.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            thresholdLabel
                .font(Theme.mono(size: 10.5))
                .foregroundColor(Theme.up.opacity(0.6))

            if let shares = item.shares {
                Text("\(shares) sh")
                    .font(Theme.mono(size: 10.5))
                    .foregroundColor(Theme.up.opacity(0.6))
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, Theme.spaceLG)
        .background(isSelected ? Theme.paper3 : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .opacity(item.enabled ? 1.0 : 0.42)
    }

    @ViewBuilder
    private var thresholdLabel: some View {
        if item.category == .vix {
            Text("panic ≥ \(Int(item.panicLevel ?? 35))")
        } else {
            HStack(spacing: 6) {
                Text("d \(Int(item.dailyThreshold ?? 0))%")
                if let w = item.weeklyThreshold {
                    Text("w \(Int(w))%")
                }
            }
        }
    }
}

// MARK: - Add Sheet

struct AddSymbolSheet: View {
    let existingSymbols: Set<String>
    let onAdd: (WatchlistItem) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var symbol = ""
    @State private var name = ""
    @State private var category: ItemCategory = .stock
    @State private var dailyThreshold = -10.0
    @State private var weeklyThreshold = -7.0
    @State private var panicLevel = 35.0
    @State private var shares = 0

    private var isDuplicate: Bool {
        existingSymbols.contains(symbol.uppercased())
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Symbol")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Spacer()
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            VStack(spacing: 14) {
                fieldRow("Ticker") {
                    TextField("e.g. AAPL", text: $symbol)
                        .font(Theme.mono(size: 13))
                        .textFieldStyle(.roundedBorder)
                }
                if isDuplicate {
                    HStack {
                        Spacer().frame(width: 90)
                        Text("Symbol already in watchlist")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.down)
                    }
                }
                fieldRow("Name") {
                    TextField("e.g. Apple Inc", text: $name)
                        .font(.system(size: 13))
                        .textFieldStyle(.roundedBorder)
                }
                fieldRow("Category") {
                    Picker("", selection: $category) {
                        ForEach(ItemCategory.allCases, id: \.self) { Text($0.rawValue.capitalized) }
                    }
                    .labelsHidden()
                }

                if category == .vix {
                    fieldRow("Panic Level") {
                        TextField("35", value: $panicLevel, format: .number)
                            .font(Theme.mono(size: 13))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                } else {
                    fieldRow("Daily %") {
                        TextField("-10", value: $dailyThreshold, format: .number)
                            .font(Theme.mono(size: 13))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    if category == .index {
                        fieldRow("Weekly %") {
                            TextField("-7", value: $weeklyThreshold, format: .number)
                                .font(Theme.mono(size: 13))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                    }
                    if category == .stock {
                        fieldRow("Shares") {
                            TextField("0", value: $shares, format: .number)
                                .font(Theme.mono(size: 13))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, 16)

            Spacer()

            Divider()

            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(Theme.ink2)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Theme.paper3)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: {
                    let item = WatchlistItem(
                        symbol: symbol.uppercased(),
                        name: name,
                        category: category,
                        enabled: true,
                        dailyThreshold: category == .vix ? nil : dailyThreshold,
                        weeklyThreshold: category == .index ? weeklyThreshold : nil,
                        panicLevel: category == .vix ? panicLevel : nil,
                        shares: category == .stock && shares > 0 ? shares : nil
                    )
                    onAdd(item)
                    dismiss()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text("Add")
                    }
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(Theme.paper)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(symbol.isEmpty || name.isEmpty || isDuplicate ? Theme.ink.opacity(0.3) : Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(symbol.isEmpty || name.isEmpty || isDuplicate)
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.vertical, 12)
        }
        .frame(width: 380, height: 360)
        .background(Theme.paper)
    }

    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.ink3)
                .frame(width: 80, alignment: .trailing)
            content()
        }
    }
}

// MARK: - Edit Sheet

struct EditSymbolSheet: View {
    let item: WatchlistItem
    let onSave: (WatchlistItem) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var enabled: Bool
    @State private var name: String
    @State private var dailyThreshold: Double
    @State private var weeklyThreshold: Double
    @State private var panicLevel: Double
    @State private var shares: Int

    init(item: WatchlistItem, onSave: @escaping (WatchlistItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _enabled = State(initialValue: item.enabled)
        _name = State(initialValue: item.name)
        _dailyThreshold = State(initialValue: item.dailyThreshold ?? -10.0)
        _weeklyThreshold = State(initialValue: item.weeklyThreshold ?? -7.0)
        _panicLevel = State(initialValue: item.panicLevel ?? 35.0)
        _shares = State(initialValue: item.shares ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit \(item.symbol)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Spacer()
                togglePill
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            VStack(spacing: 14) {
                fieldRow("Name") {
                    TextField("Name", text: $name)
                        .font(.system(size: 13))
                        .textFieldStyle(.roundedBorder)
                }

                if item.category == .vix {
                    fieldRow("Panic Level") {
                        TextField("35", value: $panicLevel, format: .number)
                            .font(Theme.mono(size: 13))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                } else {
                    fieldRow("Daily %") {
                        TextField("-10", value: $dailyThreshold, format: .number)
                            .font(Theme.mono(size: 13))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    if item.category == .index {
                        fieldRow("Weekly %") {
                            TextField("-7", value: $weeklyThreshold, format: .number)
                                .font(Theme.mono(size: 13))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                    }
                    if item.category == .stock {
                        fieldRow("Shares") {
                            TextField("0", value: $shares, format: .number)
                                .font(Theme.mono(size: 13))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, 16)

            Spacer()

            Divider()

            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(Theme.ink2)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Theme.paper3)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: {
                    var updated = item
                    updated.enabled = enabled
                    updated.name = name
                    updated.dailyThreshold = item.category == .vix ? nil : dailyThreshold
                    updated.weeklyThreshold = item.category == .index ? weeklyThreshold : nil
                    updated.panicLevel = item.category == .vix ? panicLevel : nil
                    updated.shares = item.category == .stock && shares > 0 ? shares : nil
                    onSave(updated)
                    dismiss()
                }) {
                    Text("Save")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(Theme.paper)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Theme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.vertical, 12)
        }
        .frame(width: 380, height: 320)
        .background(Theme.paper)
    }

    private var togglePill: some View {
        Button(action: { enabled.toggle() }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(enabled ? Theme.up : Theme.inkFaint)
                    .frame(width: 6, height: 6)
                Text(enabled ? "Enabled" : "Disabled")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(enabled ? Theme.up : Theme.ink4)
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(enabled ? Theme.upTint : Theme.paper3)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.ink3)
                .frame(width: 80, alignment: .trailing)
            content()
        }
    }
}
