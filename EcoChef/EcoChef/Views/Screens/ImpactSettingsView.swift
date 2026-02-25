import SwiftUI

struct ImpactSettingsView: View {
    @ObservedObject var viewModel: EcoChefViewModel
    let theme: EcoTheme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("Your Impact")
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(theme.accentGradient)
                        Spacer()
                        Color.clear.frame(width: 50, height: 50)
                    }

                    statsHero
                    scoreBreakdownSection
                    streakCard
                    achievementsSection
                    monthlyImpactSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 46)
                .padding(.bottom, 122)
            }
        }
    }

    private var statsHero: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("\(viewModel.ecoScorePercent)%")
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0x66BB6A), Color(hex: 0x4CAF50)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("ECO SCORE")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(theme.secondaryText)
            }
            .frame(width: 160, height: 160)
            .background(theme.backgroundBottom)
            .clipShape(Circle())
            .shadow(color: theme.shadowDarkSoft, radius: 8, x: 8, y: 8)
            .shadow(color: theme.shadowLightSoft, radius: 8, x: -8, y: -8)

            Text("Outstanding!")
                .font(.title2.weight(.heavy))
                .foregroundStyle(theme.primaryText)
            Text("You're making a real difference")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.secondaryText)
            Text("Weighted score based on waste, freshness, streak, and impact")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.tertiaryText)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .ecoCardStyle(theme: theme, cornerRadius: 28)
    }

    private var scoreBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("🎯 Score Breakdown")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(theme.primaryText)

            VStack(spacing: 10) {
                ForEach(viewModel.ecoScoreComponents) { component in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(component.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(theme.primaryText)
                            Spacer()
                            Text("\(Int(component.score.rounded())) / 100")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.secondaryText)
                        }
                        GeometryReader { geo in
                            Capsule()
                                .fill(theme.backgroundBottom)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(theme.accentGradient)
                                        .frame(
                                            width: max(8, (component.score / 100.0) * geo.size.width),
                                            height: 8
                                        )
                                }
                        }
                        .frame(height: 8)
                        Text(component.detail)
                            .font(.caption)
                            .foregroundStyle(theme.tertiaryText)
                    }
                }
            }

            Text(viewModel.ecoScoreSummary)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .padding(.top, 4)
        }
        .padding(18)
        .ecoCardStyle(theme: theme, cornerRadius: 18)
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text("🔥")
                    .font(.system(size: 32))
                Text("\(viewModel.currentStreakDays) Day Streak!")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(theme.primaryText)
            }

            HStack(spacing: 8) {
                ForEach(Array(viewModel.streakWeekProgress.enumerated()), id: \.offset) { entry in
                    let isActive = entry.element
                    Text(isActive ? "✓" : "•")
                        .font(.body.weight(.bold))
                        .foregroundStyle(isActive ? Color.white : theme.tertiaryText)
                        .frame(width: 36, height: 36)
                        .background(
                            LinearGradient(
                                colors: isActive
                                ? [Color(hex: 0x66BB6A), Color(hex: 0x4CAF50)]
                                : [theme.backgroundBottom, theme.backgroundBottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(20)
        .ecoCardStyle(theme: theme, cornerRadius: 20)
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("🏆 Achievements")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(theme.primaryText)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(viewModel.achievements) { achievement in
                    badge(achievement)
                }
            }
        }
    }

    private var monthlyImpactSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📊 This Month")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(theme.primaryText)

            impactStatCard("🍽️", "\(viewModel.mealsFromRescuedFood)", "Meals Saved")
            impactStatCard("💰", "₹\(viewModel.monthlyMoneySaved)", "Money Saved")
            impactStatCard("🌍", String(format: "%.1fkg", viewModel.monthlyCO2SavedKg), "CO₂ Reduced")
        }
    }

    private func badge(_ achievement: Achievement) -> some View {
        VStack(spacing: 8) {
            Text(achievement.emoji)
                .font(.system(size: 34))
                .opacity(achievement.isUnlocked ? 1 : 0.35)
            Text(achievement.title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.accent)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            achievement.isUnlocked
            ? AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: 0xFFF9C4), Color(hex: 0xFFF59D)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            : AnyShapeStyle(theme.backgroundBottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: theme.shadowDarkSoft, radius: 4, x: 4, y: 4)
        .shadow(color: theme.shadowLightSoft, radius: 4, x: -4, y: -4)
    }

    private func impactStatCard(_ icon: String, _ value: String, _ label: String) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(theme.accent)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
        }
        .padding(20)
        .ecoCardStyle(theme: theme, cornerRadius: 16)
    }
}
