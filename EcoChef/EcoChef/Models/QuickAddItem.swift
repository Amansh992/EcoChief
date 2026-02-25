import Foundation

struct QuickAddItem: Identifiable, Hashable {
    let key: String
    let emoji: String
    let sfSymbol: String
    let localizedNames: [AppLanguage: String]
    let defaultFreshnessDays: Int

    var id: String { key }

    func localizedName(for language: AppLanguage) -> String {
        localizedNames[language] ?? localizedNames[.english] ?? key.capitalized
    }
}
