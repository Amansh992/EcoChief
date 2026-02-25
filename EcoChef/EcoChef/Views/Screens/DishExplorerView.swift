import SwiftUI

struct DishExplorerView: View {
    @ObservedObject var viewModel: EcoChefViewModel
    let theme: EcoTheme
    let onBack: () -> Void
    let onRecipeTap: (RecipeSuggestion) -> Void

    @State private var selectedRecipeID: String?

    private var displayedRecipes: [RecipeSuggestion] {
        Array(viewModel.recipeSuggestions.prefix(3))
    }

    private var selectedRecipe: RecipeSuggestion? {
        if let selectedRecipeID,
           let match = displayedRecipes.first(where: { $0.id == selectedRecipeID }) {
            return match
        }
        return displayedRecipes.first
    }

    private var canCookSelectedRecipe: Bool {
        guard let selectedRecipe else { return false }
        return !selectedRecipe.availableIngredientKeys.isEmpty
    }

    private var expiringBackground: LinearGradient {
        LinearGradient(
            colors: theme.isDark
            ? [Color(hex: 0x3A2B1F), Color(hex: 0x2D2219)]
            : [Color(hex: 0xFFE8D1), Color(hex: 0xFFD7B5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var expiringTitleColor: Color {
        theme.isDark ? Color(hex: 0xFFCC8A) : Color(hex: 0xE65100)
    }

    private var expiringBodyColor: Color {
        theme.isDark ? Color(hex: 0xFFBC6D) : Color(hex: 0xF57C00)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    HapticsService.tap()
                    onBack()
                } label: {
                    Text("←")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 44, height: 44)
                        .ecoCardStyle(theme: theme, cornerRadius: 12)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    viewModel.localized(
                        hinglish: "Back",
                        english: "Back",
                        spanish: "Atrás"
                    )
                )
                .accessibilityHint(
                    viewModel.localized(
                        hinglish: "Home screen par wapas jao",
                        english: "Return to home screen",
                        spanish: "Volver a la pantalla principal"
                    )
                )

                Spacer()

                Text(
                    viewModel.localized(
                        hinglish: "Dish Explorer",
                        english: "Dish Explorer",
                        spanish: "Explorador de platos"
                    )
                )
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(theme.primaryText)

                Spacer()

                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 42)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    aiAssistantCard
                    expiringAlert

                    ForEach(displayedRecipes) { recipe in
                        recipeCard(recipe)
                    }

                    cookButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 122)
            }
        }
        .onAppear {
            viewModel.requestAIRecipeInsight()
            if selectedRecipeID == nil {
                selectedRecipeID = displayedRecipes.first?.id
            }
        }
        .onChange(of: displayedRecipes.map(\.id)) {
            let ids = displayedRecipes.map(\.id)
            guard let selectedRecipeID else {
                self.selectedRecipeID = ids.first
                return
            }
            if !ids.contains(selectedRecipeID) {
                self.selectedRecipeID = ids.first
            }
        }
    }

    private var aiAssistantCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("✨ \(viewModel.aiInsight.headline)")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Text(viewModel.aiInsight.source.badge)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.backgroundBottom)
                    .clipShape(Capsule())
            }

            Text(viewModel.aiInsight.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if viewModel.isAIInsightLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button {
                    HapticsService.tap()
                    viewModel.requestAIRecipeInsight()
                } label: {
                    Label(
                        viewModel.localized(
                            hinglish: "New Tip",
                            english: "New Tip",
                            spanish: "Nuevo consejo"
                        ),
                        systemImage: "arrow.clockwise"
                    )
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    viewModel.localized(
                        hinglish: "New tip",
                        english: "New tip",
                        spanish: "Nuevo consejo"
                    )
                )
                .accessibilityHint(
                    viewModel.localized(
                        hinglish: "AI coach se naya tip lo",
                        english: "Fetch a new kitchen tip",
                        spanish: "Obtener un nuevo consejo"
                    )
                )
            }
        }
        .padding(16)
        .ecoCardStyle(theme: theme, cornerRadius: 16)
    }

    private var expiringAlert: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("⚠️")
                Text(
                    viewModel.localized(
                        hinglish: "Jaldi Expire Hone Wala",
                        english: "Expiring Soon",
                        spanish: "Caduca pronto"
                    )
                )
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(expiringTitleColor)

            let expired = Array(viewModel.expiredItems.prefix(2))
            let expiring = Array(viewModel.topCriticalItems.prefix(3))

            if expired.isEmpty && expiring.isEmpty {
                Text(
                    viewModel.localized(
                        hinglish: "No urgent items right now.",
                        english: "No urgent items right now.",
                        spanish: "No hay items urgentes por ahora."
                    )
                )
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(expiringBodyColor)
            } else {
                ForEach(expired) { item in
                    Text("⛔️ \(item.localizedName(for: viewModel.selectedLanguage)): \(expiredActionText)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(expiringBodyColor)
                }

                ForEach(expiring) { item in
                    Text("\(item.emoji) \(item.localizedName(for: viewModel.selectedLanguage)): \(countdownText(item))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(expiringBodyColor)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(expiringBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: theme.shadowDarkSoft, radius: 8, x: 4, y: 4)
        .shadow(color: theme.shadowLightSoft, radius: 8, x: -4, y: -4)
    }

    private var cookButton: some View {
        Button {
            viewModel.markCooked(using: selectedRecipe)
        } label: {
            Text(cookButtonTitle)
                .font(.headline.weight(.bold))
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .ecoCardStyle(theme: theme, cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .opacity(canCookSelectedRecipe ? 1 : 0.55)
        .disabled(!canCookSelectedRecipe)
        .padding(.top, 2)
        .accessibilityLabel(cookButtonTitle)
        .accessibilityHint(
            canCookSelectedRecipe
            ? viewModel.localized(
                hinglish: "Selected recipe ko cooked mark karega",
                english: "Marks selected recipe as cooked",
                spanish: "Marca la receta seleccionada como cocinada"
            )
            : viewModel.localized(
                hinglish: "Pehle expired items cleanup karo",
                english: "Remove expired items first",
                spanish: "Primero elimina los caducados"
            )
        )
    }

    private var cookButtonTitle: String {
        guard let selectedRecipe else {
            return viewModel.localized(
                hinglish: "Maine Yeh Cook Kiya! ✓",
                english: "I Cooked This! ✓",
                spanish: "¡Ya lo cociné! ✓"
            )
        }
        if selectedRecipe.availableIngredientKeys.isEmpty {
            return viewModel.localized(
                hinglish: "Cleanup first: remove expired items",
                english: "Cleanup first: remove expired items",
                spanish: "Primero limpia: elimina caducados"
            )
        }
        return viewModel.localized(
            hinglish: "\(viewModel.recipeTitle(selectedRecipe)) cook ho gaya ✓",
            english: "Cooked \(viewModel.recipeTitle(selectedRecipe)) ✓",
            spanish: "Cocinado: \(viewModel.recipeTitle(selectedRecipe)) ✓"
        )
    }

    private func countdownText(_ item: FoodItem) -> String {
        if item.expiryStage == .expired {
            return viewModel.localized(
                hinglish: "expired - remove now",
                english: "expired - remove now",
                spanish: "caducado - elimínalo ahora"
            )
        }
        let days = max(item.daysLeft, 1)
        switch viewModel.selectedLanguage {
        case .hinglish:
            return days == 1 ? "1 din bacha" : "\(days) din bache"
        case .english:
            return days == 1 ? "1 day left" : "\(days) days left"
        case .spanish:
            return days == 1 ? "1 día restante" : "\(days) días restantes"
        }
    }

    private var expiredActionText: String {
        viewModel.localized(
            hinglish: "remove from fridge list",
            english: "remove from fridge list",
            spanish: "elimínalo de la lista"
        )
    }

    private func recipeCard(_ recipe: RecipeSuggestion) -> some View {
        let isSelected = recipe.id == selectedRecipe?.id
        return Button {
            HapticsService.tap()
            selectedRecipeID = recipe.id
            onRecipeTap(recipe)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    Text(recipe.emoji)
                        .font(.system(size: 38))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.recipeTitle(recipe))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(theme.primaryText)
                            .multilineTextAlignment(.leading)

                        Text("⏱️ \(recipe.cookMinutes) minutes")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.tertiaryText)
                    }
                }

                ForEach(recipe.availableIngredients, id: \.self) { ingredient in
                    Text("✓ \(ingredient) (you have)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x66BB6A))
                }

                ForEach(recipe.missingIngredients, id: \.self) { ingredient in
                    Text("○ \(ingredient) (you need)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.tertiaryText)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ecoCardStyle(theme: theme, cornerRadius: 24)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isSelected ? theme.accent : theme.borderColor,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.recipeTitle(recipe))
        .accessibilityValue(
            "Cook time \(recipe.cookMinutes) minutes. Have \(recipe.availableIngredients.count) ingredients, need \(recipe.missingIngredients.count)."
        )
        .accessibilityHint("Double tap to select this recipe")
    }
}
