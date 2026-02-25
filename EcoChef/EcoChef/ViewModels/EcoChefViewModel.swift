import Combine
import Foundation

enum AppScreen: String, CaseIterable, Identifiable {
    case home
    case dishExplorer
    case impactSettings
    case alerts

    var id: String { rawValue }
}

struct BarcodeAddResult {
    let success: Bool
    let item: QuickAddItem?
    let message: String
}

struct EcoScoreComponent: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let weight: Double
    let score: Double

    var weightedScore: Double {
        score * weight
    }
}

@MainActor
final class EcoChefViewModel: ObservableObject {
    @Published var currentScreen: AppScreen = .home
    @Published var foods: [FoodItem] {
        didSet { persistStateIfReady() }
    }
    @Published var selectedLanguage: AppLanguage = .english {
        didSet { persistStateIfReady() }
    }
    @Published var notificationsEnabled: Bool = true {
        didSet { persistStateIfReady() }
    }
    @Published var prefersDarkMode: Bool = false {
        didSet { persistStateIfReady() }
    }

    @Published var showQuickLogSheet = false
    @Published var showShelfLifeEditor = false
    @Published var showCookedSuccess = false

    @Published var recentLogs: [String] = [] {
        didSet { persistStateIfReady() }
    }

    @Published private(set) var totalSavedItems: Int = 18 {
        didSet { persistStateIfReady() }
    }
    @Published private(set) var totalWastedItems: Int = 3 {
        didSet { persistStateIfReady() }
    }
    @Published var monthlyCO2SavedKg: Double = 2.4 {
        didSet { persistStateIfReady() }
    }
    @Published var monthlyMoneySaved: Int = 840 {
        didSet { persistStateIfReady() }
    }
    @Published var mealsFromRescuedFood: Int = 12 {
        didSet { persistStateIfReady() }
    }
    @Published private(set) var aiInsight = AIRecipeAssistantInsight(
        headline: "Smart Kitchen Coach",
        message: "Add items to get recipe guidance.",
        source: .offline
    )
    @Published private(set) var isAIInsightLoading = false
    @Published private(set) var lastEcoScoreDelta: Int = 0
    @Published private(set) var currentStreakDays: Int = 7 {
        didSet { persistStateIfReady() }
    }

    @Published var customShelfLives: [String: Int] {
        didSet { persistStateIfReady() }
    }

    let quickAddItems: [QuickAddItem]

    private var cancellables = Set<AnyCancellable>()
    private let persistence: EcoChefPersistenceService
    private let aiAssistant: AIRecipeAssistantService
    private var persistenceReady = false
    private var aiInsightTask: Task<Void, Never>?
    private var aiInsightRefreshSeed = 0
    private var lastCookedDay: Date? {
        didSet { persistStateIfReady() }
    }

    convenience init(loadPersistedState: Bool = true) {
        self.init(
            persistence: .shared,
            aiAssistant: .shared,
            loadPersistedState: loadPersistedState
        )
    }

    init(
        persistence: EcoChefPersistenceService,
        aiAssistant: AIRecipeAssistantService,
        loadPersistedState: Bool = true
    ) {
        self.persistence = persistence
        self.aiAssistant = aiAssistant
        self.quickAddItems = Self.seedQuickAddItems
        let defaultShelfLives = Dictionary(
            uniqueKeysWithValues: Self.seedQuickAddItems.map { ($0.key, $0.defaultFreshnessDays) }
        )
        let defaultFoods = Self.seedFoods(using: Self.seedQuickAddItems)

        let snapshot: EcoChefStateSnapshot
        if loadPersistedState {
            snapshot = persistence.loadState(defaultFoods: defaultFoods, defaultShelfLives: defaultShelfLives)
        } else {
            snapshot = EcoChefStateSnapshot(
                foods: defaultFoods,
                selectedLanguage: .english,
                notificationsEnabled: true,
                prefersDarkMode: false,
                recentLogs: [],
                totalSavedItems: 18,
                totalWastedItems: 3,
                monthlyCO2SavedKg: 2.4,
                monthlyMoneySaved: 840,
                mealsFromRescuedFood: 12,
                currentStreakDays: 7,
                customShelfLives: defaultShelfLives,
                lastCookedDay: nil
            )
        }

        self.foods = snapshot.foods
        self.selectedLanguage = .english
        self.notificationsEnabled = snapshot.notificationsEnabled
        self.prefersDarkMode = snapshot.prefersDarkMode
        self.recentLogs = snapshot.recentLogs
        self.totalSavedItems = snapshot.totalSavedItems
        self.totalWastedItems = snapshot.totalWastedItems
        self.monthlyCO2SavedKg = snapshot.monthlyCO2SavedKg
        self.monthlyMoneySaved = snapshot.monthlyMoneySaved
        self.mealsFromRescuedFood = snapshot.mealsFromRescuedFood
        self.aiInsight = Self.placeholderInsight(language: .english)
        self.currentStreakDays = snapshot.currentStreakDays
        self.customShelfLives = snapshot.customShelfLives
        self.lastCookedDay = snapshot.lastCookedDay

        setupBindings()
        refreshNotifications()
        requestAIRecipeInsight()
        persistenceReady = true
        persistStateIfReady()
    }

    func refreshExpiryMonitoring() {
        refreshNotifications()
    }

    func requestAIRecipeInsight() {
        aiInsightTask?.cancel()
        let foodsSnapshot = foods
        let suggestionSnapshot = recipeSuggestions
        let language = selectedLanguage
        aiInsightRefreshSeed += 1
        let refreshSeed = aiInsightRefreshSeed
        isAIInsightLoading = true

        aiInsightTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let insight = await aiAssistant.generateInsight(
                language: language,
                foods: foodsSnapshot,
                suggestions: suggestionSnapshot,
                refreshSeed: refreshSeed
            )
            guard !Task.isCancelled else { return }
            self.aiInsight = insight
            self.isAIInsightLoading = false
        }
    }

    var ecoScorePercent: Int {
        let weightedScore = ecoScoreComponents.reduce(0) { partialResult, component in
            partialResult + component.weightedScore
        }
        return Int(min(max(weightedScore, 0), 100).rounded())
    }

    var ecoScoreComponents: [EcoScoreComponent] {
        [
            EcoScoreComponent(
                id: "waste",
                title: localized(
                    hinglish: "Waste Prevention",
                    english: "Waste Prevention",
                    spanish: "Prevención de desperdicio"
                ),
                detail: localized(
                    hinglish: "Saved vs wasted items",
                    english: "Saved vs wasted items",
                    spanish: "Items salvados vs desperdiciados"
                ),
                weight: 0.45,
                score: wastePreventionScore
            ),
            EcoScoreComponent(
                id: "freshness",
                title: localized(
                    hinglish: "Freshness Health",
                    english: "Freshness Health",
                    spanish: "Salud de frescura"
                ),
                detail: localized(
                    hinglish: "How fresh your current fridge is",
                    english: "How fresh your current fridge is",
                    spanish: "Qué tan fresco está tu refrigerador"
                ),
                weight: 0.25,
                score: freshnessHealthScore
            ),
            EcoScoreComponent(
                id: "streak",
                title: localized(
                    hinglish: "Consistency",
                    english: "Consistency",
                    spanish: "Consistencia"
                ),
                detail: localized(
                    hinglish: "Daily cooking streak progress",
                    english: "Daily cooking streak progress",
                    spanish: "Progreso de racha diaria"
                ),
                weight: 0.15,
                score: streakConsistencyScore
            ),
            EcoScoreComponent(
                id: "impact",
                title: localized(
                    hinglish: "Impact",
                    english: "Impact",
                    spanish: "Impacto"
                ),
                detail: localized(
                    hinglish: "CO₂, meals, and money impact",
                    english: "CO₂, meals, and money impact",
                    spanish: "Impacto de CO₂, comidas y ahorro"
                ),
                weight: 0.15,
                score: impactPerformanceScore
            )
        ]
    }

    var ecoScoreSummary: String {
        guard let weakest = ecoScoreComponents.min(by: { $0.score < $1.score }) else {
            return localized(
                hinglish: "Score balanced and healthy.",
                english: "Score balanced and healthy.",
                spanish: "Puntaje equilibrado y saludable."
            )
        }
        return localized(
            hinglish: "Focus area: \(weakest.title). Improve this to boost your score faster.",
            english: "Focus area: \(weakest.title). Improve this to boost your score faster.",
            spanish: "Área clave: \(weakest.title). Mejorarla subirá tu puntaje más rápido."
        )
    }

    var expiredItems: [FoodItem] {
        foods
            .filter { $0.expiryStage == .expired }
            .sorted { $0.expiryDate < $1.expiryDate }
    }

    var topCriticalItems: [FoodItem] {
        let urgent = cookableFoodsByUrgency
            .filter { $0.freshnessState != .safe }
        if !urgent.isEmpty {
            return Array(urgent.prefix(3))
        }

        return Array(cookableFoodsByUrgency.prefix(3))
    }

    var alertItems: [FoodItem] {
        foods
            .filter { $0.freshnessState != .safe }
            .sorted { $0.expiryDate < $1.expiryDate }
    }

    var recipeSuggestions: [RecipeSuggestion] {
        buildRecipeSuggestions()
    }

    var monthlyImpact: [ImpactSnapshot] {
        let savedDistribution: [Double] = [0.2, 0.24, 0.26, 0.3]
        let wastedDistribution: [Double] = [0.3, 0.25, 0.25, 0.2]
        return (0..<4).map { index in
            ImpactSnapshot(
                weekLabel: "W\(index + 1)",
                saved: Double(totalSavedItems) * savedDistribution[index],
                wasted: Double(totalWastedItems) * wastedDistribution[index]
            )
        }
    }

    var achievements: [Achievement] {
        [
            Achievement(
                id: "first-week",
                title: "First Week",
                subtitle: "Keep a 7 day cooking streak.",
                emoji: "🌟",
                sfSymbol: "sparkles",
                isUnlocked: currentStreakDays >= 7
            ),
            Achievement(
                id: "eco-warrior",
                title: "Eco Warrior",
                subtitle: "Save 2kg CO₂ in a month.",
                emoji: "💚",
                sfSymbol: "leaf.fill",
                isUnlocked: monthlyCO2SavedKg >= 2
            ),
            Achievement(
                id: "hot-streak",
                title: "Hot Streak",
                subtitle: "Cook 5 days in a row.",
                emoji: "🔥",
                sfSymbol: "flame.fill",
                isUnlocked: currentStreakDays >= 5
            ),
            Achievement(
                id: "master-chef",
                title: "Master Chef",
                subtitle: "Rescue 25 meals.",
                emoji: "👨‍🍳",
                sfSymbol: "fork.knife",
                isUnlocked: mealsFromRescuedFood >= 25
            ),
            Achievement(
                id: "planet-hero",
                title: "Planet Hero",
                subtitle: "Reduce 5kg CO₂.",
                emoji: "🌍",
                sfSymbol: "globe.europe.africa.fill",
                isUnlocked: monthlyCO2SavedKg >= 5
            ),
            Achievement(
                id: "perfect-score",
                title: "100% Score",
                subtitle: "Reach a perfect eco score.",
                emoji: "⭐",
                sfSymbol: "star.fill",
                isUnlocked: ecoScorePercent >= 100
            )
        ]
    }

    var streakWeekProgress: [Bool] {
        let active = min(max(currentStreakDays, 0), 7)
        return (0..<7).map { $0 < active }
    }

    private var wastePreventionScore: Double {
        let total = max(totalSavedItems + totalWastedItems, 1)
        return (Double(totalSavedItems) / Double(total)) * 100
    }

    private var freshnessHealthScore: Double {
        guard !foods.isEmpty else { return 100 }
        let scoreByStage: [ExpiryStage: Double] = [
            .fresh: 100,
            .threeDays: 72,
            .oneDay: 42,
            .expired: 0
        ]
        let totalUnits = foods.reduce(0) { partialResult, item in
            partialResult + max(item.quantity, 1)
        }
        guard totalUnits > 0 else { return 100 }

        let weighted = foods.reduce(0.0) { partialResult, item in
            let units = Double(max(item.quantity, 1))
            let stageScore = scoreByStage[item.expiryStage] ?? 0
            return partialResult + (stageScore * units)
        }
        return weighted / Double(totalUnits)
    }

    private var streakConsistencyScore: Double {
        min((Double(currentStreakDays) / 14.0) * 100.0, 100)
    }

    private var impactPerformanceScore: Double {
        let co2Score = min((monthlyCO2SavedKg / 6.0) * 100.0, 100)
        let mealScore = min((Double(mealsFromRescuedFood) / 40.0) * 100.0, 100)
        let moneyScore = min((Double(monthlyMoneySaved) / 2_500.0) * 100.0, 100)
        return (co2Score * 0.45) + (mealScore * 0.35) + (moneyScore * 0.20)
    }

    var heroSuggestionText: String {
        if let expired = expiredItems.first {
            let expiredName = expired.localizedName(for: selectedLanguage)
            if let topCookable = topCriticalItems.first {
                let cookableName = topCookable.localizedName(for: selectedLanguage)
                return localized(
                    hinglish: "\(expired.emoji) \(expiredName) expire ho chuka hai. Isko fridge list se remove karo, phir \(cookableName) use karke waste bachao.",
                    english: "\(expired.emoji) \(expiredName) has expired. Remove it from your fridge list first, then cook \(cookableName) to reduce waste.",
                    spanish: "\(expired.emoji) \(expiredName) ya caducó. Elimínalo de tu lista y luego cocina \(cookableName) para evitar desperdicio."
                )
            }
            return localized(
                hinglish: "\(expired.emoji) \(expiredName) expire ho chuka hai. Isko fridge list se remove karo taki suggestions sahi rahein.",
                english: "\(expired.emoji) \(expiredName) has expired. Remove it from your fridge list so suggestions stay accurate.",
                spanish: "\(expired.emoji) \(expiredName) ya caducó. Elimínalo de tu lista para mantener sugerencias correctas."
            )
        }

        guard let top = topCriticalItems.first else {
            return localized(
                hinglish: "Sab set hai! Add more items to get smart suggestions.",
                english: "All set! Add more items to unlock smart suggestions.",
                spanish: "¡Todo listo! Agrega más items para sugerencias inteligentes."
            )
        }
        let name = top.localizedName(for: selectedLanguage)
        let dish = heroRecipeTitle
        return localized(
            hinglish: "Use your \(top.emoji) \(name) before it expires. \(dish) is a great fit for today.",
            english: "Use your \(top.emoji) \(name) before it expires. \(dish) is a great fit for today.",
            spanish: "Usa tu \(top.emoji) \(name) antes de que caduque. \(dish) encaja perfecto hoy."
        )
    }

    var heroTitle: String {
        localized(
            hinglish: "AI Smart Suggestion",
            english: "AI Smart Suggestion",
            spanish: "Sugerencia Inteligente IA"
        )
    }

    var recipeHeaderTitle: String {
        localized(
            hinglish: "Based on Your Expiring Items",
            english: "Based on Your Expiring Items",
            spanish: "Basado en tus items por vencer"
        )
    }

    var heroRecipe: RecipeSuggestion? {
        recipeSuggestions.first
    }

    var heroEmoji: String {
        heroRecipe?.emoji ?? "🍲"
    }

    var heroRecipeTitle: String {
        guard let heroRecipe else {
            return localized(
                hinglish: "Smart Recipe",
                english: "Smart Recipe",
                spanish: "Receta Inteligente"
            )
        }
        return heroRecipe.localizedTitle(for: selectedLanguage)
    }

    var heroSubtitle: String {
        if !expiredItems.isEmpty {
            return localized(
                hinglish: "Remove expired first",
                english: "Remove expired first",
                spanish: "Elimina caducados primero"
            )
        }
        localized(
            hinglish: "Perfect for today!",
            english: "Perfect for today!",
            spanish: "Perfecto para hoy"
        )
    }

    var heroCookMinutes: Int {
        heroRecipe?.cookMinutes ?? 0
    }

    var heroHavePercent: Int {
        guard let heroRecipe else { return 0 }
        let total = heroRecipe.availableIngredients.count + heroRecipe.missingIngredients.count
        guard total > 0 else { return 0 }
        return Int((Double(heroRecipe.availableIngredients.count) / Double(total) * 100).rounded())
    }

    var heroNeedCount: Int {
        heroRecipe?.missingIngredients.count ?? 0
    }

    func openQuickLog() {
        showQuickLogSheet = true
    }

    func addQuickItem(_ item: QuickAddItem, quantity: Int = 1, customDays: Int? = nil) {
        let days = max(1, customDays ?? customShelfLives[item.key] ?? item.defaultFreshnessDays)
        let food = makeFood(from: item, quantity: quantity, shelfLifeDays: days)
        foods.insert(food, at: 0)

        let log = localized(
            hinglish: "✓ \(item.localizedName(for: selectedLanguage)) added (\(days) days)",
            english: "✓ \(item.localizedName(for: selectedLanguage)) added (\(days) days)",
            spanish: "✓ \(item.localizedName(for: selectedLanguage)) agregado (\(days) días)"
        )
        recentLogs.insert(log, at: 0)
        recentLogs = Array(recentLogs.prefix(3))

        HapticsService.tap()
        refreshNotifications()
    }

    func addManualItem(name: String, quantity: Int, shelfLifeDays: Int) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        let expiry = Calendar.current.date(byAdding: .day, value: shelfLifeDays, to: .now) ?? .now
        let localizedNameMap: [AppLanguage: String] = [
            .hinglish: cleanName,
            .english: cleanName,
            .spanish: cleanName
        ]
        let customFood = FoodItem(
            key: cleanName.lowercased(),
            emoji: "🥗",
            sfSymbol: "leaf",
            localizedNames: localizedNameMap,
            quantity: quantity,
            addedAt: .now,
            expiryDate: expiry,
            shelfLifeDays: max(1, shelfLifeDays)
        )
        foods.insert(customFood, at: 0)

        let log = localized(
            hinglish: "✓ \(cleanName) added (\(shelfLifeDays) days)",
            english: "✓ \(cleanName) added (\(shelfLifeDays) days)",
            spanish: "✓ \(cleanName) agregado (\(shelfLifeDays) días)"
        )
        recentLogs.insert(log, at: 0)
        recentLogs = Array(recentLogs.prefix(3))

        HapticsService.tap()
        refreshNotifications()
    }

    func addItemFromBarcode(_ rawCode: String) -> BarcodeAddResult {
        guard let resolved = BarcodeCatalogService.shared.resolveBarcode(rawCode, availableItems: quickAddItems) else {
            HapticsService.tap()
            return BarcodeAddResult(
                success: false,
                item: nil,
                message: localized(
                    hinglish: "Barcode not recognized. Try manual add.",
                    english: "Barcode not recognized. Try manual add.",
                    spanish: "No se reconoció el código. Intenta agregar manualmente."
                )
            )
        }

        addQuickItem(resolved.item)
        let itemName = resolved.item.localizedName(for: selectedLanguage)
        switch resolved.confidence {
        case .exact:
            return BarcodeAddResult(
                success: true,
                item: resolved.item,
                message: localized(
                    hinglish: "Scanned and added: \(itemName) \(resolved.item.emoji)",
                    english: "Scanned and added: \(itemName) \(resolved.item.emoji)",
                    spanish: "Escaneado y agregado: \(itemName) \(resolved.item.emoji)"
                )
            )
        case .inferred:
            return BarcodeAddResult(
                success: true,
                item: resolved.item,
                message: localized(
                    hinglish: "Mapped barcode to \(itemName) \(resolved.item.emoji)",
                    english: "Mapped barcode to \(itemName) \(resolved.item.emoji)",
                    spanish: "Código mapeado a \(itemName) \(resolved.item.emoji)"
                )
            )
        }
    }

    func deleteFood(_ food: FoodItem) {
        guard let index = foods.firstIndex(where: { $0.id == food.id }) else { return }
        let removed = foods.remove(at: index)
        let name = removed.localizedName(for: selectedLanguage)
        let didWaste = removed.freshnessState == .critical
        if didWaste {
            totalWastedItems += max(removed.quantity, 1)
        }
        let log = localized(
            hinglish: didWaste ? "✗ \(name) removed (counted as waste)" : "✗ \(name) removed",
            english: didWaste ? "✗ \(name) removed (counted as waste)" : "✗ \(name) removed",
            spanish: didWaste ? "✗ \(name) eliminado (contado como desperdicio)" : "✗ \(name) eliminado"
        )
        recentLogs.insert(log, at: 0)
        recentLogs = Array(recentLogs.prefix(3))

        if didWaste {
            HapticsService.tap()
        } else {
            HapticsService.success()
        }
        refreshNotifications()
    }

    func markCooked(using recipe: RecipeSuggestion? = nil) {
        let oldScore = ecoScorePercent
        let consumedItems = consumeIngredients(preferredKeys: recipe?.availableIngredientKeys ?? [])
        guard consumedItems > 0 else { return }

        totalSavedItems += consumedItems
        mealsFromRescuedFood += 1
        monthlyMoneySaved += 45 * consumedItems
        monthlyCO2SavedKg += 0.22 * Double(consumedItems)
        lastEcoScoreDelta = max(ecoScorePercent - oldScore, 0)
        updateCookingStreak()

        showCookedSuccess = true
        HapticsService.celebrate()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            showCookedSuccess = false
        }

        refreshNotifications()
    }

    func updateShelfLife(for itemKey: String, days: Int) {
        customShelfLives[itemKey] = max(1, days)
    }

    func removeAllExpiredItems() -> Int {
        let expired = foods.filter { $0.expiryStage == .expired }
        guard !expired.isEmpty else { return 0 }

        let removedItems = expired.count
        let removedUnits = expired.reduce(0) { partialResult, item in
            partialResult + max(item.quantity, 1)
        }

        foods.removeAll { $0.expiryStage == .expired }
        totalWastedItems += removedUnits

        let log = localized(
            hinglish: "✗ Removed \(removedItems) expired item(s)",
            english: "✗ Removed \(removedItems) expired item(s)",
            spanish: "✗ Se eliminaron \(removedItems) item(s) caducados"
        )
        recentLogs.insert(log, at: 0)
        recentLogs = Array(recentLogs.prefix(3))

        HapticsService.tap()
        refreshNotifications()
        return removedItems
    }

    func resetDemoData() {
        let defaultShelfLives = Dictionary(
            uniqueKeysWithValues: quickAddItems.map { ($0.key, $0.defaultFreshnessDays) }
        )

        foods = Self.seedFoods(using: quickAddItems)
        selectedLanguage = .english
        notificationsEnabled = true
        prefersDarkMode = false
        recentLogs = []
        totalSavedItems = 18
        totalWastedItems = 3
        monthlyCO2SavedKg = 2.4
        monthlyMoneySaved = 840
        mealsFromRescuedFood = 12
        currentStreakDays = 7
        customShelfLives = defaultShelfLives
        lastCookedDay = nil
        showCookedSuccess = false
        lastEcoScoreDelta = 0
        aiInsightRefreshSeed = 0

        HapticsService.success()
        refreshNotifications()
        requestAIRecipeInsight()
    }

    func localized(hinglish: String, english: String, spanish: String) -> String {
        // Swift Student Challenge policy requires English content.
        _ = hinglish
        _ = spanish
        return english
    }

    func recipeTitle(_ recipe: RecipeSuggestion) -> String {
        recipe.localizedTitle(for: selectedLanguage)
    }

    private func ingredientName(for key: String, language: AppLanguage? = nil) -> String {
        let lang = language ?? selectedLanguage
        if let food = foods.first(where: { $0.key == key }) {
            return food.localizedName(for: lang)
        }
        if let item = quickAddItems.first(where: { $0.key == key }) {
            return item.localizedName(for: lang)
        }
        return key.capitalized
    }

    private func consumeIngredients(preferredKeys: [String]) -> Int {
        var consumed = 0
        var seen = Set<String>()
        let keys = preferredKeys
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
        let keysToTry = keys.isEmpty ? [topCriticalItems.first?.key].compactMap { $0 } : keys

        for key in keysToTry.prefix(2) {
            let sortedIndices = foods.indices
                .filter { foods[$0].key == key }
                .sorted { foods[$0].expiryDate < foods[$1].expiryDate }
            guard let index = sortedIndices.first else { continue }

            if foods[index].quantity > 1 {
                foods[index].quantity -= 1
            } else {
                foods.remove(at: index)
            }
            consumed += 1
        }

        return consumed
    }

    private func updateCookingStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        guard let lastCookedDay else {
            currentStreakDays = max(currentStreakDays, 1)
            self.lastCookedDay = today
            return
        }

        let dayDiff = calendar.dateComponents([.day], from: lastCookedDay, to: today).day ?? 0
        switch dayDiff {
        case ..<0:
            currentStreakDays = max(currentStreakDays, 1)
        case 0, 1:
            currentStreakDays += 1
        default:
            currentStreakDays = 1
        }

        self.lastCookedDay = today
    }

    private var cookableFoodsByUrgency: [FoodItem] {
        foods
            .filter { $0.expiryStage != .expired }
            .sorted { $0.expiryDate < $1.expiryDate }
    }

    private func buildRecipeSuggestions() -> [RecipeSuggestion] {
        let inventory = cookableFoodsByUrgency.reduce(into: [String: Int]()) { partialResult, item in
            partialResult[item.key, default: 0] += max(item.quantity, 1)
        }
        let urgentKeys = Set(topCriticalItems.map(\.key))

        if inventory.isEmpty {
            if !expiredItems.isEmpty {
                return [expiredCleanupSuggestion(expired: expiredItems)]
            }
            let emptyRecipe = RecipeSuggestion(
                id: "empty-fridge",
                emoji: "🥗",
                localizedTitles: [
                    .hinglish: "Start by adding ingredients",
                    .english: "Start by adding ingredients",
                    .spanish: "Empieza agregando ingredientes"
                ],
                cookMinutes: 10,
                availableIngredientKeys: [],
                missingIngredientKeys: [],
                availableIngredients: [],
                missingIngredients: ["Any fresh ingredient"]
            )
            return [emptyRecipe]
        }

        var scored: [(recipe: RecipeSuggestion, score: Double)] = []
        for template in Self.recipeTemplates {
            let availableRequired = template.requiredKeys.filter { inventory[$0, default: 0] > 0 }
            let missingRequired = template.requiredKeys.filter { inventory[$0, default: 0] == 0 }
            let availableOptional = template.optionalKeys.filter { inventory[$0, default: 0] > 0 }

            var seen = Set<String>()
            let availableKeys = (availableRequired + availableOptional).filter { key in
                seen.insert(key).inserted
            }
            guard !availableKeys.isEmpty else { continue }

            let availableIngredients = availableKeys
                .sorted { ingredientName(for: $0) < ingredientName(for: $1) }
                .map { ingredientName(for: $0) }
            let missingIngredients = missingRequired.map { ingredientName(for: $0) } + template.pantryNeeds

            let recipe = RecipeSuggestion(
                id: template.id,
                emoji: template.emoji,
                localizedTitles: template.localizedTitles,
                cookMinutes: template.cookMinutes,
                availableIngredientKeys: availableKeys,
                missingIngredientKeys: missingRequired,
                availableIngredients: availableIngredients,
                missingIngredients: missingIngredients
            )

            let requiredCoverage = Double(availableRequired.count) / Double(max(template.requiredKeys.count, 1))
            let urgencyBoost = Double(availableKeys.filter { urgentKeys.contains($0) }.count) * 1.8
            let missingPenalty = Double(missingRequired.count) * 0.9
            let score = (requiredCoverage * 5.0) + (Double(availableKeys.count) * 0.45) + urgencyBoost - missingPenalty

            scored.append((recipe, score))
        }

        if let urgent = topCriticalItems.first {
            let fallback = fallbackRecipe(for: urgent)
            let containsUrgent = scored.contains { entry in
                entry.recipe.availableIngredientKeys.contains(urgent.key)
            }
            if !containsUrgent {
                scored.append((fallback, 100))
            }
        }

        if scored.isEmpty {
            if let first = cookableFoodsByUrgency.first {
                scored = [(fallbackRecipe(for: first), 100)]
            } else {
                if !expiredItems.isEmpty {
                    return [expiredCleanupSuggestion(expired: expiredItems)]
                }
                let emptyRecipe = RecipeSuggestion(
                    id: "empty-fridge",
                    emoji: "🥗",
                    localizedTitles: [
                        .hinglish: "Start by adding ingredients",
                        .english: "Start by adding ingredients",
                        .spanish: "Empieza agregando ingredientes"
                    ],
                    cookMinutes: 10,
                    availableIngredientKeys: [],
                    missingIngredientKeys: [],
                    availableIngredients: [],
                    missingIngredients: ["Any fresh ingredient"]
                )
                return [emptyRecipe]
            }
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(3)
            .map(\.recipe)
    }

    private func fallbackRecipe(for food: FoodItem) -> RecipeSuggestion {
        let nameHinglish = food.localizedName(for: .hinglish)
        let nameEnglish = food.localizedName(for: .english)
        let nameSpanish = food.localizedName(for: .spanish)
        let ingredient = food.localizedName(for: selectedLanguage)

        return RecipeSuggestion(
            id: "rescue-\(food.key)",
            emoji: food.emoji,
            localizedTitles: [
                .hinglish: "\(nameHinglish) Rescue Bowl",
                .english: "\(nameEnglish) Rescue Bowl",
                .spanish: "Bowl rescate de \(nameSpanish)"
            ],
            cookMinutes: 12,
            availableIngredientKeys: [food.key],
            missingIngredientKeys: [],
            availableIngredients: [ingredient],
            missingIngredients: ["Oil", "Salt", "Spices"]
        )
    }

    private func expiredCleanupSuggestion(expired: [FoodItem]) -> RecipeSuggestion {
        let highlighted = expired
            .prefix(2)
            .map { $0.localizedName(for: selectedLanguage) }
            .joined(separator: ", ")
        let removeText = localized(
            hinglish: highlighted.isEmpty
                ? "Remove expired items from fridge list"
                : "Remove expired: \(highlighted)",
            english: highlighted.isEmpty
                ? "Remove expired items from fridge list"
                : "Remove expired: \(highlighted)",
            spanish: highlighted.isEmpty
                ? "Elimina los items caducados de tu lista"
                : "Elimina caducados: \(highlighted)"
        )

        return RecipeSuggestion(
            id: "cleanup-expired-items",
            emoji: "🧹",
            localizedTitles: [
                .hinglish: "Fridge Cleanup First",
                .english: "Fridge Cleanup First",
                .spanish: "Primero limpia el refri"
            ],
            cookMinutes: 0,
            availableIngredientKeys: [],
            missingIngredientKeys: [],
            availableIngredients: [],
            missingIngredients: [removeText]
        )
    }

    private func setupBindings() {
        Publishers.CombineLatest3($foods, $notificationsEnabled, $selectedLanguage)
            .sink { foods, enabled, language in
                LocalNotificationService.shared.updateExpiryReminders(
                    items: foods,
                    language: language,
                    isEnabled: enabled
                )
            }
            .store(in: &cancellables)

        Publishers.CombineLatest($foods, $selectedLanguage)
            .debounce(for: .milliseconds(650), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.requestAIRecipeInsight()
            }
            .store(in: &cancellables)
    }

    private func refreshNotifications() {
        LocalNotificationService.shared.updateExpiryReminders(
            items: foods,
            language: selectedLanguage,
            isEnabled: notificationsEnabled
        )
    }

    private func persistStateIfReady() {
        guard persistenceReady else { return }
        let snapshot = EcoChefStateSnapshot(
            foods: foods,
            selectedLanguage: selectedLanguage,
            notificationsEnabled: notificationsEnabled,
            prefersDarkMode: prefersDarkMode,
            recentLogs: recentLogs,
            totalSavedItems: totalSavedItems,
            totalWastedItems: totalWastedItems,
            monthlyCO2SavedKg: monthlyCO2SavedKg,
            monthlyMoneySaved: monthlyMoneySaved,
            mealsFromRescuedFood: mealsFromRescuedFood,
            currentStreakDays: currentStreakDays,
            customShelfLives: customShelfLives,
            lastCookedDay: lastCookedDay
        )
        persistence.saveState(snapshot)
    }

    private func makeFood(from item: QuickAddItem, quantity: Int, shelfLifeDays: Int) -> FoodItem {
        let expiry = Calendar.current.date(byAdding: .day, value: shelfLifeDays, to: .now) ?? .now
        return FoodItem(
            key: item.key,
            emoji: item.emoji,
            sfSymbol: item.sfSymbol,
            localizedNames: item.localizedNames,
            quantity: quantity,
            addedAt: .now,
            expiryDate: expiry,
            shelfLifeDays: shelfLifeDays
        )
    }

    private static func placeholderInsight(language: AppLanguage) -> AIRecipeAssistantInsight {
        switch language {
        case .hinglish:
            return AIRecipeAssistantInsight(
                headline: "Smart Kitchen Coach",
                message: "Add items to get recipe guidance.",
                source: .offline
            )
        case .english:
            return AIRecipeAssistantInsight(
                headline: "Smart Kitchen Coach",
                message: "Add items to get recipe guidance.",
                source: .offline
            )
        case .spanish:
            return AIRecipeAssistantInsight(
                headline: "Coach inteligente de cocina",
                message: "Agrega ingredientes para recibir sugerencias.",
                source: .offline
            )
        }
    }
}

private extension EcoChefViewModel {
    static let seedQuickAddItems: [QuickAddItem] = [
        .init(
            key: "carrot",
            emoji: "🥕",
            sfSymbol: "carrot.fill",
            localizedNames: [.hinglish: "Carrot", .english: "Carrot", .spanish: "Zanahoria"],
            defaultFreshnessDays: 7
        ),
        .init(
            key: "spinach",
            emoji: "🥬",
            sfSymbol: "leaf.fill",
            localizedNames: [.hinglish: "Spinach", .english: "Spinach", .spanish: "Espinaca"],
            defaultFreshnessDays: 3
        ),
        .init(
            key: "tomato",
            emoji: "🍅",
            sfSymbol: "takeoutbag.and.cup.and.straw.fill",
            localizedNames: [.hinglish: "Tomato", .english: "Tomato", .spanish: "Tomate"],
            defaultFreshnessDays: 2
        ),
        .init(
            key: "potato",
            emoji: "🥔",
            sfSymbol: "shippingbox.fill",
            localizedNames: [.hinglish: "Potato", .english: "Potato", .spanish: "Patata"],
            defaultFreshnessDays: 10
        ),
        .init(
            key: "onion",
            emoji: "🧅",
            sfSymbol: "circle.grid.cross.fill",
            localizedNames: [.hinglish: "Onion", .english: "Onion", .spanish: "Cebolla"],
            defaultFreshnessDays: 9
        ),
        .init(
            key: "milk",
            emoji: "🥛",
            sfSymbol: "drop.fill",
            localizedNames: [.hinglish: "Milk", .english: "Milk", .spanish: "Leche"],
            defaultFreshnessDays: 4
        ),
        .init(
            key: "paneer",
            emoji: "🧀",
            sfSymbol: "square.stack.3d.up.fill",
            localizedNames: [.hinglish: "Paneer", .english: "Cheese", .spanish: "Queso"],
            defaultFreshnessDays: 5
        ),
        .init(
            key: "bread",
            emoji: "🍞",
            sfSymbol: "birthday.cake.fill",
            localizedNames: [.hinglish: "Bread", .english: "Bread", .spanish: "Pan"],
            defaultFreshnessDays: 4
        ),
        .init(
            key: "eggs",
            emoji: "🥚",
            sfSymbol: "circle.fill",
            localizedNames: [.hinglish: "Eggs", .english: "Eggs", .spanish: "Huevos"],
            defaultFreshnessDays: 9
        ),
        .init(
            key: "pepper",
            emoji: "🫑",
            sfSymbol: "flame.fill",
            localizedNames: [.hinglish: "Pepper", .english: "Pepper", .spanish: "Pimiento"],
            defaultFreshnessDays: 5
        ),
        .init(
            key: "cucumber",
            emoji: "🥒",
            sfSymbol: "capsule.fill",
            localizedNames: [.hinglish: "Cucumber", .english: "Cucumber", .spanish: "Pepino"],
            defaultFreshnessDays: 6
        ),
        .init(
            key: "chili",
            emoji: "🌶️",
            sfSymbol: "bolt.fill",
            localizedNames: [.hinglish: "Chili", .english: "Chili", .spanish: "Chile"],
            defaultFreshnessDays: 6
        )
    ]

    static func seedFoods(using quickItems: [QuickAddItem]) -> [FoodItem] {
        func item(_ key: String, qty: Int, days: Int) -> FoodItem {
            guard let base = quickItems.first(where: { $0.key == key }) else {
                fatalError("Missing seed key: \(key)")
            }
            let expiry = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
            return FoodItem(
                key: base.key,
                emoji: base.emoji,
                sfSymbol: base.sfSymbol,
                localizedNames: base.localizedNames,
                quantity: qty,
                addedAt: .now,
                expiryDate: expiry,
                shelfLifeDays: max(days, 1)
            )
        }

        return [
            item("tomato", qty: 1, days: 1),
            item("spinach", qty: 1, days: 2),
            item("milk", qty: 1, days: 3),
            item("carrot", qty: 3, days: 5)
        ]
    }

    struct RecipeTemplate {
        let id: String
        let emoji: String
        let localizedTitles: [AppLanguage: String]
        let cookMinutes: Int
        let requiredKeys: [String]
        let optionalKeys: [String]
        let pantryNeeds: [String]
    }

    static let recipeTemplates: [RecipeTemplate] = [
        RecipeTemplate(
            id: "palak-paneer",
            emoji: "🍲",
            localizedTitles: [
                .hinglish: "Palak Paneer",
                .english: "Spinach Paneer Curry",
                .spanish: "Curry de espinaca y queso"
            ],
            cookMinutes: 25,
            requiredKeys: ["spinach", "onion"],
            optionalKeys: ["tomato", "paneer"],
            pantryNeeds: ["Spices"]
        ),
        RecipeTemplate(
            id: "quick-stir-fry",
            emoji: "🥗",
            localizedTitles: [
                .hinglish: "Quick Stir-Fry",
                .english: "Quick Stir-Fry",
                .spanish: "Salteado Rápido"
            ],
            cookMinutes: 15,
            requiredKeys: ["tomato", "onion"],
            optionalKeys: ["spinach", "pepper", "chili", "carrot"],
            pantryNeeds: ["Garlic", "Oil"]
        ),
        RecipeTemplate(
            id: "veggie-sandwich",
            emoji: "🥪",
            localizedTitles: [
                .hinglish: "Veg Sandwich",
                .english: "Veggie Sandwich",
                .spanish: "Sándwich vegetal"
            ],
            cookMinutes: 12,
            requiredKeys: ["bread", "tomato"],
            optionalKeys: ["onion", "cucumber", "paneer"],
            pantryNeeds: ["Butter", "Salt"]
        ),
        RecipeTemplate(
            id: "masala-omelette",
            emoji: "🍳",
            localizedTitles: [
                .hinglish: "Masala Omelette",
                .english: "Masala Omelette",
                .spanish: "Tortilla masala"
            ],
            cookMinutes: 14,
            requiredKeys: ["eggs", "onion"],
            optionalKeys: ["tomato", "chili", "pepper"],
            pantryNeeds: ["Spices", "Oil"]
        ),
        RecipeTemplate(
            id: "aloo-skillet",
            emoji: "🥔",
            localizedTitles: [
                .hinglish: "Aloo Skillet",
                .english: "Potato Skillet",
                .spanish: "Sartén de papa"
            ],
            cookMinutes: 20,
            requiredKeys: ["potato", "onion"],
            optionalKeys: ["tomato", "chili"],
            pantryNeeds: ["Oil", "Salt"]
        ),
        RecipeTemplate(
            id: "cool-salad",
            emoji: "🥒",
            localizedTitles: [
                .hinglish: "Fresh Salad Bowl",
                .english: "Fresh Salad Bowl",
                .spanish: "Ensalada fresca"
            ],
            cookMinutes: 10,
            requiredKeys: ["cucumber", "tomato"],
            optionalKeys: ["onion", "pepper", "carrot"],
            pantryNeeds: ["Lemon", "Salt"]
        ),
        RecipeTemplate(
            id: "milk-toast",
            emoji: "🥛",
            localizedTitles: [
                .hinglish: "Milk Toast",
                .english: "Milk Toast",
                .spanish: "Tostada con leche"
            ],
            cookMinutes: 8,
            requiredKeys: ["milk", "bread"],
            optionalKeys: ["eggs"],
            pantryNeeds: ["Sugar", "Cinnamon"]
        )
    ]
}
