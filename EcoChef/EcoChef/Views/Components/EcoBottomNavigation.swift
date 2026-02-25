import SwiftUI

struct EcoBottomNavigation: View {
    let selection: AppScreen?
    let theme: EcoTheme
    let onSelect: (AppScreen) -> Void

    private let navItems: [(emoji: String, title: String, screen: AppScreen)] = [
        ("🏠", "Home", .home),
        ("🍳", "Recipes", .dishExplorer),
        ("📊", "Impact", .impactSettings),
        ("🔔", "Alerts", .alerts)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(navItems, id: \.title) { item in
                navButton(emoji: item.emoji, title: item.title, screen: item.screen)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
        .padding(.horizontal, 8)
        .background(theme.backgroundTop.opacity(theme.isDark ? 0.82 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        )
        .shadow(color: theme.shadowDarkSoft, radius: 8, x: 0, y: -1)
    }

    private func navButton(emoji: String, title: String, screen: AppScreen) -> some View {
        let isActive = screen == selection
        return Button {
            onSelect(screen)
            HapticsService.tap()
        } label: {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 20))
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                isActive
                                ? AnyShapeStyle(theme.accentGradient)
                                : AnyShapeStyle(theme.cardBackground)
                            )
                    )
                    .shadow(color: theme.shadowDarkSoft, radius: 4, x: 4, y: 4)
                    .shadow(color: theme.shadowLightSoft, radius: 4, x: -4, y: -4)
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isActive ? theme.primaryText : theme.tertiaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
