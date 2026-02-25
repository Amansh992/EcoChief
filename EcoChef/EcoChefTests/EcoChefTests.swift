//
//  EcoChefTests.swift
//  EcoChefTests
//
//  Created by AMAN SHARMA on 15/02/26.
//

import Testing
import Foundation
@testable import EcoChef

struct EcoChefTests {
    @Test
    @MainActor
    func quickAddInsertsFoodAndLog() async throws {
        let viewModel = EcoChefViewModel(
            persistence: EcoChefPersistenceService(inMemory: true),
            loadPersistedState: false
        )
        let initialCount = viewModel.foods.count
        let item = try #require(viewModel.quickAddItems.first)

        viewModel.addQuickItem(item)

        #expect(viewModel.foods.count == initialCount + 1)
        #expect((viewModel.recentLogs.first ?? "").contains("✓"))
    }

    @Test
    @MainActor
    func cookedActionImprovesImpact() async throws {
        let viewModel = EcoChefViewModel(
            persistence: EcoChefPersistenceService(inMemory: true),
            loadPersistedState: false
        )
        let initialScore = viewModel.ecoScorePercent
        let initialMeals = viewModel.mealsFromRescuedFood

        viewModel.markCooked(using: viewModel.recipeSuggestions.first)

        #expect(viewModel.ecoScorePercent >= initialScore)
        #expect(viewModel.mealsFromRescuedFood == initialMeals + 1)
    }

    @Test
    @MainActor
    func recipeSuggestionsReactToInventory() async throws {
        let viewModel = EcoChefViewModel(
            persistence: EcoChefPersistenceService(inMemory: true),
            loadPersistedState: false
        )
        let eggs = try #require(viewModel.quickAddItems.first(where: { $0.key == "eggs" }))

        viewModel.addQuickItem(eggs)
        let suggestions = viewModel.recipeSuggestions

        #expect(!suggestions.isEmpty)
        #expect(suggestions.contains(where: { $0.availableIngredientKeys.contains("eggs") }))
    }

    @Test
    @MainActor
    func cookedActionConsumesSomeIngredientsOnly() async throws {
        let viewModel = EcoChefViewModel(
            persistence: EcoChefPersistenceService(inMemory: true),
            loadPersistedState: false
        )
        let initialFoodCount = viewModel.foods.count
        let recipe = try #require(viewModel.recipeSuggestions.first)

        viewModel.markCooked(using: recipe)

        #expect(!viewModel.foods.isEmpty)
        #expect(viewModel.foods.count >= max(0, initialFoodCount - 2))
    }

    @Test
    @MainActor
    func barcodeScanMapsAndAddsItem() async throws {
        let viewModel = EcoChefViewModel(
            persistence: EcoChefPersistenceService(inMemory: true),
            loadPersistedState: false
        )
        let initial = viewModel.foods.count

        let result = viewModel.addItemFromBarcode("8901030895451")

        #expect(result.success)
        #expect(viewModel.foods.count == initial + 1)
    }

    @Test
    @MainActor
    func ecoScoreUsesWeightedComponents() async throws {
        let viewModel = EcoChefViewModel(
            persistence: EcoChefPersistenceService(inMemory: true),
            loadPersistedState: false
        )
        let components = viewModel.ecoScoreComponents
        let weightSum = components.reduce(0.0) { $0 + $1.weight }

        #expect(components.count == 4)
        #expect(abs(weightSum - 1.0) < 0.0001)
        #expect((0...100).contains(viewModel.ecoScorePercent))
    }

    @Test
    @MainActor
    func aiFallbackInsightWorksOffline() async throws {
        let service = AIRecipeAssistantService(allowRemote: false)
        let viewModel = EcoChefViewModel(
            persistence: EcoChefPersistenceService(inMemory: true),
            aiAssistant: service,
            loadPersistedState: false
        )

        let insight = await service.generateInsight(
            language: .english,
            foods: viewModel.foods,
            suggestions: viewModel.recipeSuggestions
        )

        #expect(!insight.message.isEmpty)
        #expect(insight.source == .offline)
    }

    @Test
    @MainActor
    func aiOfflineInsightDiffersForHinglishAndEnglish() async throws {
        let service = AIRecipeAssistantService(allowRemote: false)
        let viewModel = EcoChefViewModel(
            persistence: EcoChefPersistenceService(inMemory: true),
            aiAssistant: service,
            loadPersistedState: false
        )

        let hinglish = await service.generateInsight(
            language: .hinglish,
            foods: viewModel.foods,
            suggestions: viewModel.recipeSuggestions
        )
        let english = await service.generateInsight(
            language: .english,
            foods: viewModel.foods,
            suggestions: viewModel.recipeSuggestions
        )

        #expect(hinglish.message != english.message)
        #expect(hinglish.headline != english.headline)
    }

    @Test
    @MainActor
    func aiOfflineRefreshSeedChangesTipCopy() async throws {
        let service = AIRecipeAssistantService(allowRemote: false)
        let viewModel = EcoChefViewModel(
            persistence: EcoChefPersistenceService(inMemory: true),
            aiAssistant: service,
            loadPersistedState: false
        )

        let tipOne = await service.generateInsight(
            language: .english,
            foods: viewModel.foods,
            suggestions: viewModel.recipeSuggestions,
            refreshSeed: 1
        )
        let tipTwo = await service.generateInsight(
            language: .english,
            foods: viewModel.foods,
            suggestions: viewModel.recipeSuggestions,
            refreshSeed: 2
        )

        #expect(tipOne.message != tipTwo.message)
    }

    @Test
    @MainActor
    func recipeSuggestionsIgnoreExpiredIngredients() async throws {
        let viewModel = EcoChefViewModel(
            persistence: EcoChefPersistenceService(inMemory: true),
            loadPersistedState: false
        )
        let spinach = try #require(viewModel.quickAddItems.first(where: { $0.key == "spinach" }))
        let onion = try #require(viewModel.quickAddItems.first(where: { $0.key == "onion" }))

        viewModel.foods = [
            makeFood(from: spinach, daysOffset: -1),
            makeFood(from: onion, daysOffset: 1)
        ]

        let suggestions = viewModel.recipeSuggestions
        #expect(!viewModel.expiredItems.isEmpty)
        #expect(suggestions.allSatisfy { !$0.availableIngredientKeys.contains("spinach") })
        #expect(viewModel.topCriticalItems.allSatisfy { $0.expiryStage != .expired })
    }

    @Test
    @MainActor
    func expiredOnlyInventoryShowsCleanupSuggestion() async throws {
        let viewModel = EcoChefViewModel(
            persistence: EcoChefPersistenceService(inMemory: true),
            loadPersistedState: false
        )
        let tomato = try #require(viewModel.quickAddItems.first(where: { $0.key == "tomato" }))

        viewModel.foods = [makeFood(from: tomato, daysOffset: -2)]
        let suggestion = try #require(viewModel.recipeSuggestions.first)

        #expect(suggestion.id == "cleanup-expired-items")
        #expect(suggestion.availableIngredientKeys.isEmpty)
    }

    @Test
    @MainActor
    func aiOfflineInsightForExpiredOnlyInventorySuggestsRemoval() async throws {
        let service = AIRecipeAssistantService(allowRemote: false)
        let fallbackItem = QuickAddItem(
            key: "spinach",
            emoji: "🥬",
            sfSymbol: "leaf.fill",
            localizedNames: [.hinglish: "Spinach", .english: "Spinach", .spanish: "Espinaca"],
            defaultFreshnessDays: 3
        )
        let expiredFood = makeFood(from: fallbackItem, daysOffset: -1)

        let insight = await service.generateInsight(
            language: .english,
            foods: [expiredFood],
            suggestions: []
        )

        #expect(insight.source == .offline)
        #expect(insight.message.localizedCaseInsensitiveContains("remove"))
    }

    @Test
    @MainActor
    func removeAllExpiredItemsClearsOnlyExpiredInventory() async throws {
        let viewModel = EcoChefViewModel(
            persistence: EcoChefPersistenceService(inMemory: true),
            loadPersistedState: false
        )
        let tomato = try #require(viewModel.quickAddItems.first(where: { $0.key == "tomato" }))
        let onion = try #require(viewModel.quickAddItems.first(where: { $0.key == "onion" }))

        viewModel.foods = [
            makeFood(from: tomato, daysOffset: -1, quantity: 2),
            makeFood(from: onion, daysOffset: 2)
        ]
        let wastedBefore = viewModel.totalWastedItems

        let removedCount = viewModel.removeAllExpiredItems()

        #expect(removedCount == 1)
        #expect(viewModel.foods.count == 1)
        #expect(viewModel.foods.allSatisfy { $0.expiryStage != .expired })
        #expect(viewModel.totalWastedItems == wastedBefore + 2)
    }

    @Test
    @MainActor
    func resetDemoDataRestoresSeedState() async throws {
        let viewModel = EcoChefViewModel(
            persistence: EcoChefPersistenceService(inMemory: true),
            loadPersistedState: false
        )
        let eggs = try #require(viewModel.quickAddItems.first(where: { $0.key == "eggs" }))
        viewModel.addQuickItem(eggs)
        viewModel.notificationsEnabled = false
        viewModel.prefersDarkMode = true
        viewModel.selectedLanguage = .spanish
        viewModel.monthlyMoneySaved = 1700

        viewModel.resetDemoData()

        #expect(viewModel.foods.count == 4)
        #expect(viewModel.selectedLanguage == .english)
        #expect(viewModel.notificationsEnabled)
        #expect(!viewModel.prefersDarkMode)
        #expect(viewModel.monthlyMoneySaved == 840)
        #expect(viewModel.currentStreakDays == 7)
        #expect(viewModel.customShelfLives["carrot"] == 7)
    }
}

private extension EcoChefTests {
    func makeFood(from item: QuickAddItem, daysOffset: Int, quantity: Int = 1) -> FoodItem {
        let expiry = Calendar.current.date(byAdding: .day, value: daysOffset, to: .now) ?? .now
        return FoodItem(
            key: item.key,
            emoji: item.emoji,
            sfSymbol: item.sfSymbol,
            localizedNames: item.localizedNames,
            quantity: quantity,
            addedAt: .now,
            expiryDate: expiry,
            shelfLifeDays: max(item.defaultFreshnessDays, 1)
        )
    }
}
