import SwiftUI

enum Theme {
    // MARK: - Ink (type, controls, primary surfaces)
    static let ink = Color(red: 10/255, green: 10/255, blue: 11/255)
    static let ink2 = Color(red: 26/255, green: 26/255, blue: 29/255)
    static let ink3 = Color(red: 90/255, green: 90/255, blue: 98/255)
    static let ink4 = Color(red: 139/255, green: 139/255, blue: 148/255)
    static let inkFaint = Color(red: 184/255, green: 184/255, blue: 191/255)

    // MARK: - Paper (surfaces)
    static let paper = Color.white
    static let paper2 = Color(red: 250/255, green: 250/255, blue: 250/255)
    static let paper3 = Color(red: 244/255, green: 244/255, blue: 245/255)
    static let hairline = Color(red: 10/255, green: 10/255, blue: 11/255).opacity(0.08)

    // MARK: - Up (gain, confirmation)
    static let up = Color(red: 15/255, green: 138/255, blue: 71/255)
    static let upTint = Color(red: 15/255, green: 138/255, blue: 71/255).opacity(0.08)

    // MARK: - Down (loss, alert)
    static let down = Color(red: 214/255, green: 49/255, blue: 26/255)
    static let downTint = Color(red: 214/255, green: 49/255, blue: 26/255).opacity(0.08)
    static let downStrong = Color(red: 182/255, green: 41/255, blue: 28/255)
    static let downBg = Color(red: 251/255, green: 237/255, blue: 234/255)

    // MARK: - Spacing (4px grid)
    static let spaceXS: CGFloat = 4
    static let spaceSM: CGFloat = 8
    static let spaceMD: CGFloat = 12
    static let spaceLG: CGFloat = 16
    static let spaceXL: CGFloat = 24

    // MARK: - Radii
    static let radiusXS: CGFloat = 4
    static let radiusSM: CGFloat = 6
    static let radiusMD: CGFloat = 10
    static let radiusLG: CGFloat = 14

    // MARK: - Popover
    static let popoverWidth: CGFloat = 420

    // MARK: - Fonts
    static func mono(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func label(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: - Formatting
    static func formatPrice(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        fmt.groupingSeparator = ","
        fmt.decimalSeparator = "."
        return fmt.string(from: NSNumber(value: value)) ?? "—"
    }

    static func formatChange(_ pct: Double?) -> String {
        guard let pct else { return "—" }
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", pct))%"
    }

    static func formatMoney(_ amount: Double) -> String {
        let sign = amount < 0 ? "−" : ""
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 0
        fmt.groupingSeparator = ","
        let str = fmt.string(from: NSNumber(value: abs(amount))) ?? "0"
        return "\(sign)$\(str)"
    }
}
