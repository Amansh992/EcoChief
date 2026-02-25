import Foundation

struct RecipeSuggestion: Identifiable, Hashable {
    let id: String
    let emoji: String
    let localizedTitles: [AppLanguage: String]
    let cookMinutes: Int
    let availableIngredientKeys: [String]
    let missingIngredientKeys: [String]
    let availableIngredients: [String]
    let missingIngredients: [String]

    func localizedTitle(for language: AppLanguage) -> String {
        localizedTitles[language] ?? localizedTitles[.english] ?? "Recipe"
    }
}
