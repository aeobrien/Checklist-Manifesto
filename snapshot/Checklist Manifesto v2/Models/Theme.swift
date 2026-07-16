import SwiftUI

struct Theme {
    static let background = Color(hex: "FAFAF8")
    static let surface = Color(hex: "FFFFFF")
    static let primary = Color(hex: "2C3E50")
    static let secondary = Color(hex: "7F8C8D")
    static let accent = Color(hex: "3498DB")
    static let success = Color(hex: "27AE60")
    static let warning = Color(hex: "F39C12")
    static let error = Color(hex: "E74C3C")
    static let textPrimary = Color(hex: "2C3E50")
    static let textSecondary = Color(hex: "7F8C8D")
    static let divider = Color(hex: "ECF0F1")
    static let checkboxBorder = Color(hex: "BDC3C7")
    static let checkboxFilled = Color(hex: "27AE60")
    
    static let cornerRadius: CGFloat = 12
    static let smallCornerRadius: CGFloat = 8
    static let spacing: CGFloat = 16
    static let smallSpacing: CGFloat = 8
    
    static let shadowColor = Color.black.opacity(0.08)
    static let shadowRadius: CGFloat = 8
    static let shadowY: CGFloat = 2
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct Typography {
    static let largeTitle = Font.custom("Avenir Next", size: 34).weight(.semibold)
    static let title = Font.custom("Avenir Next", size: 28).weight(.semibold)
    static let title2 = Font.custom("Avenir Next", size: 22).weight(.medium)
    static let title3 = Font.custom("Avenir Next", size: 20).weight(.medium)
    static let headline = Font.custom("Avenir Next", size: 17).weight(.semibold)
    static let body = Font.custom("Avenir Next", size: 17)
    static let callout = Font.custom("Avenir Next", size: 16)
    static let subheadline = Font.custom("Avenir Next", size: 15)
    static let footnote = Font.custom("Avenir Next", size: 13)
    static let caption = Font.custom("Avenir Next", size: 12)
    static let caption2 = Font.custom("Avenir Next", size: 11)
}