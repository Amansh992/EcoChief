import SwiftUI

struct EcoTheme {
    let isDark: Bool

    // MARK: - Palette

    var backgroundBase: Color {
        isDark ? Color(hex: 0x1A1D2E) : Color(hex: 0xE8EAF6)
    }

    var backgroundElevated: Color {
        isDark ? Color(hex: 0x23283A) : Color(hex: 0xE8EAF6)
    }

    var backgroundTop: Color {
        isDark ? Color(hex: 0x1E2335) : Color(hex: 0xE9EBF7)
    }

    var backgroundBottom: Color {
        isDark ? Color(hex: 0x181C2B) : Color(hex: 0xE7E9F5)
    }

    var cardBackground: Color { backgroundElevated }
    var elevatedBackground: Color { backgroundElevated }

    var primaryText: Color {
        isDark ? Color(hex: 0xE7ECFF) : Color(hex: 0x3F51B5)
    }

    var secondaryText: Color {
        isDark ? Color(hex: 0xB7BFDF) : Color(hex: 0x7986CB)
    }

    var tertiaryText: Color {
        isDark ? Color(hex: 0x8D97C7) : Color(hex: 0x9FA8DA)
    }

    var borderColor: Color {
        isDark ? Color.white.opacity(0.08) : Color(hex: 0xA3B1C6, opacity: 0.2)
    }

    var accent: Color {
        Color(hex: 0x5C6BC0)
    }

    var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x5C6BC0), Color(hex: 0x7E57C2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var shadowDark: Color {
        isDark ? Color.black.opacity(0.35) : Color(hex: 0xA3B1C6, opacity: 0.6)
    }

    var shadowLight: Color {
        isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.8)
    }

    var shadowDarkSoft: Color {
        isDark ? Color.black.opacity(0.24) : Color(hex: 0xA3B1C6, opacity: 0.4)
    }

    var shadowLightSoft: Color {
        isDark ? Color.white.opacity(0.04) : Color.white.opacity(0.6)
    }

    var success: Color { Color(hex: 0x2EAF62) }
    var warning: Color { Color(hex: 0xF4A300) }
    var danger: Color { Color(hex: 0xE74C3C) }

    var screenGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    func ecoCardStyle(theme: EcoTheme, cornerRadius: CGFloat = 24) -> some View {
        self
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: theme.shadowDark, radius: 12, x: 10, y: 10)
            .shadow(color: theme.shadowLight, radius: 12, x: -10, y: -10)
    }

    func ecoInsetStyle(theme: EcoTheme, cornerRadius: CGFloat = 16) -> some View {
        self
            .background(theme.backgroundTop)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: theme.shadowDarkSoft, radius: 4, x: 3, y: 3)
            .shadow(color: theme.shadowLightSoft, radius: 4, x: -3, y: -3)
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
