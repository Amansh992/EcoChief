import SwiftUI

struct HomeDashboardView: View {
    @ObservedObject var viewModel: EcoChefViewModel
    let theme: EcoTheme
    let onOpenQuickAdd: () -> Void
    let onOpenSettings: () -> Void
    let onHeroTap: () -> Void
    let onFoodTap: (FoodItem) -> Void
    let onFoodDelete: (FoodItem) -> Void

    private var foodsByUrgency: [FoodItem] {
        viewModel.foods.sorted(by: { $0.expiryDate < $1.expiryDate })
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("EcoChef")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(theme.accentGradient)

                    Spacer()

                    HStack(spacing: 10) {
                        roundedHeaderButton(
                            icon: "+",
                            size: 26,
                            accessibilityLabel: viewModel.localized(
                                hinglish: "Add item",
                                english: "Add item",
                                spanish: "Agregar item"
                            ),
                            accessibilityHint: viewModel.localized(
                                hinglish: "Quick log kholne ke liye double tap karo",
                                english: "Double tap to open quick add",
                                spanish: "Doble toque para abrir agregado rápido"
                            ),
                            action: onOpenQuickAdd
                        )
                        roundedHeaderButton(
                            icon: "⚙️",
                            size: 15,
                            accessibilityLabel: viewModel.localized(
                                hinglish: "Settings",
                                english: "Settings",
                                spanish: "Ajustes"
                            ),
                            accessibilityHint: viewModel.localized(
                                hinglish: "Settings screen kholne ke liye double tap karo",
                                english: "Double tap to open settings",
                                spanish: "Doble toque para abrir ajustes"
                            ),
                            action: onOpenSettings
                        )
                    }
                }

                statusCard

                HeroSuggestionCardView(
                    emoji: viewModel.heroEmoji,
                    title: viewModel.heroRecipeTitle,
                    subtitle: viewModel.heroSubtitle,
                    message: viewModel.heroSuggestionText,
                    cookTimeText: "\(viewModel.heroCookMinutes)m",
                    haveText: "\(viewModel.heroHavePercent)%",
                    needText: "\(viewModel.heroNeedCount)",
                    theme: theme,
                    onTap: onHeroTap
                )

                Text("🥬 Your Fridge")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(theme.primaryText)

                VStack(spacing: 12) {
                    ForEach(foodsByUrgency) { food in
                        FreshnessCardView(
                            food: food,
                            language: viewModel.selectedLanguage,
                            theme: theme,
                            onTap: {
                                onFoodTap(food)
                            },
                            onDelete: {
                                onFoodDelete(food)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 46)
            .padding(.bottom, 124)
        }
    }

    private func roundedHeaderButton(
        icon: String,
        size: CGFloat,
        accessibilityLabel: String,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticsService.tap()
            action()
        } label: {
            Text(icon)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(theme.accent)
                .frame(width: 42, height: 42)
                .ecoCardStyle(theme: theme, cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var statusCard: some View {
        VStack(spacing: 16) {
            EcoScoreRingView(
                score: viewModel.ecoScorePercent,
                title: viewModel.localized(
                    hinglish: "Kitchen Score",
                    english: "Kitchen Score",
                    spanish: "Puntaje de cocina"
                ),
                subtitle: viewModel.localized(
                    hinglish: "WEIGHTED ECO SCORE",
                    english: "WEIGHTED ECO SCORE",
                    spanish: "ECO SCORE PONDERADO"
                ),
                theme: theme
            )

            HStack(spacing: 10) {
                statusPill(
                    icon: "🍽️",
                    value: "\(viewModel.mealsFromRescuedFood)",
                    label: viewModel.localized(hinglish: "Meals", english: "Meals", spanish: "Comidas")
                )
                statusPill(
                    icon: "💰",
                    value: "₹\(viewModel.monthlyMoneySaved)",
                    label: viewModel.localized(hinglish: "Saved", english: "Saved", spanish: "Ahorro")
                )
                statusPill(
                    icon: "🌍",
                    value: String(format: "%.1fkg", viewModel.monthlyCO2SavedKg),
                    label: "CO₂"
                )
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .ecoCardStyle(theme: theme, cornerRadius: 28)
    }

    private func statusPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 20))
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.primaryText)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(theme.backgroundBottom)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: theme.shadowDarkSoft, radius: 3, x: 2, y: 2)
        .shadow(color: theme.shadowLightSoft, radius: 3, x: -2, y: -2)
    }
}
