import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case hinglish
    case english
    case spanish

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hinglish:
            return "Hinglish 🇮🇳"
        case .english:
            return "English 🇺🇸"
        case .spanish:
            return "Spanish 🇪🇸"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .hinglish:
            return "en-IN"
        case .english:
            return "en"
        case .spanish:
            return "es"
        }
    }
}
