import Foundation

struct FoodItem: Identifiable, Hashable, Codable {
    let id: UUID
    let key: String
    var emoji: String
    var sfSymbol: String
    var localizedNames: [AppLanguage: String]
    var quantity: Int
    var addedAt: Date
    var expiryDate: Date
    var shelfLifeDays: Int

    init(
        id: UUID = UUID(),
        key: String,
        emoji: String,
        sfSymbol: String,
        localizedNames: [AppLanguage: String],
        quantity: Int = 1,
        addedAt: Date = .now,
        expiryDate: Date,
        shelfLifeDays: Int
    ) {
        self.id = id
        self.key = key
        self.emoji = emoji
        self.sfSymbol = sfSymbol
        self.localizedNames = localizedNames
        self.quantity = quantity
        self.addedAt = addedAt
        self.expiryDate = expiryDate
        self.shelfLifeDays = shelfLifeDays
    }

    func localizedName(for language: AppLanguage) -> String {
        localizedNames[language] ?? localizedNames[.english] ?? key.capitalized
    }

    var daysLeft: Int {
        let days = Calendar.current.dateComponents([.day], from: .now, to: expiryDate).day ?? 0
        return max(days, 0)
    }

    var rawHoursLeft: Int {
        Calendar.current.dateComponents([.hour], from: .now, to: expiryDate).hour ?? 0
    }

    var hoursLeft: Int {
        max(rawHoursLeft, 0)
    }

    var freshnessProgress: Double {
        let totalHours = max(Double(shelfLifeDays * 24), 1)
        let remaining = min(max(Double(hoursLeft), 0), totalHours)
        return remaining / totalHours
    }

    var expiryStage: ExpiryStage {
        if rawHoursLeft < 0 { return .expired }
        if rawHoursLeft <= 24 { return .oneDay }
        if rawHoursLeft <= 72 { return .threeDays }
        return .fresh
    }

    var freshnessState: FreshnessState {
        switch expiryStage {
        case .expired, .oneDay:
            return .critical
        case .threeDays:
            return .warning
        case .fresh:
            break
        }
        return .safe
    }
}

enum FreshnessState: Codable {
    case safe
    case warning
    case critical
}

enum ExpiryStage: String, Codable {
    case fresh
    case threeDays
    case oneDay
    case expired
}
