import SwiftUI

struct HeroSuggestionCardView: View {
    let emoji: String
    let title: String
    let subtitle: String
    let message: String
    let cookTimeText: String
    let haveText: String
    let needText: String
    let theme: EcoTheme
    let onTap: () -> Void

    @State private var pulse = false
    @State private var shimmer = false
    @State private var emojiLift = false

    var body: some View {
        Button {
            HapticsService.tap()
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Text(emoji)
                        .font(.system(size: 42))
                        .offset(y: emojiLift ? -6 : 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(theme.primaryText)
                        Text(subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.tertiaryText)
                    }
                }

                Text(message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 10) {
                    statCard(cookTimeText, "Cook Time")
                    statCard(haveText, "You Have")
                    statCard(needText, "To Buy")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color(hex: 0x7C4DFF, opacity: theme.isDark ? 0.05 : 0.08),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: proxy.size.width * 0.46)
                        .rotationEffect(.degrees(24))
                        .offset(x: shimmer ? proxy.size.width * 1.15 : -proxy.size.width * 0.85)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .shadow(color: theme.shadowDark, radius: 12, x: 10, y: 10)
            .shadow(color: theme.shadowLight, radius: 12, x: -10, y: -10)
            .shadow(
                color: Color(hex: 0x7C4DFF, opacity: pulse ? 0.2 : 0.09),
                radius: pulse ? 26 : 16
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(emoji) \(title). \(subtitle)")
        .accessibilityValue("Cook time \(cookTimeText). You have \(haveText). Need \(needText).")
        .accessibilityHint("Double tap to open recipe suggestions")
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: false)) {
                shimmer = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                emojiLift = true
            }
        }
    }

    private func statCard(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 23, weight: .heavy))
                .foregroundStyle(theme.accent)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(theme.backgroundBottom)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: theme.shadowDarkSoft, radius: 3, x: 2, y: 2)
        .shadow(color: theme.shadowLightSoft, radius: 3, x: -2, y: -2)
    }
}
