import Foundation
import UserNotifications

final class LocalNotificationService {
    static let shared = LocalNotificationService()

    private let center = UNUserNotificationCenter.current()
    private let notificationPrefix = "ecochef.expiry."
    private let maxTrackedItems = 20

    private init() {}

    func requestAuthorizationIfNeeded() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func updateExpiryReminders(
        items: [FoodItem],
        language: AppLanguage,
        isEnabled: Bool
    ) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }

            let managedIDs = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(self.notificationPrefix) }
            if !managedIDs.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: managedIDs)
            }
            guard isEnabled else { return }

            let sorted = items
                .sorted(by: { $0.expiryDate < $1.expiryDate })
                .prefix(self.maxTrackedItems)

            for item in sorted {
                self.scheduleReminderIfNeeded(item: item, stage: .threeDays, language: language)
                self.scheduleReminderIfNeeded(item: item, stage: .oneDay, language: language)
                self.scheduleReminderIfNeeded(item: item, stage: .expired, language: language)
            }
        }
    }

    private func scheduleReminderIfNeeded(item: FoodItem, stage: ExpiryStage, language: AppLanguage) {
        guard let fireDate = fireDate(for: item, stage: stage) else { return }

        let content = UNMutableNotificationContent()
        content.title = reminderTitle(item: item, stage: stage, language: language)
        content.body = reminderBody(item: item, stage: stage, language: language)
        content.sound = .default
        content.userInfo = [
            "destination": "dishExplorer",
            "itemID": item.id.uuidString,
            "stage": stage.rawValue
        ]

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier(item: item, stage: stage),
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    private func fireDate(for item: FoodItem, stage: ExpiryStage) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        switch stage {
        case .fresh:
            return nil
        case .threeDays:
            guard let date = calendar.date(byAdding: .day, value: -3, to: item.expiryDate) else { return nil }
            let normalized = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
            return normalized > now ? normalized : nil
        case .oneDay:
            guard let date = calendar.date(byAdding: .day, value: -1, to: item.expiryDate) else { return nil }
            let normalized = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
            return normalized > now ? normalized : nil
        case .expired:
            let nominal = item.expiryDate.addingTimeInterval(30 * 60)
            return nominal > now ? nominal : nil
        }
    }

    private func notificationIdentifier(item: FoodItem, stage: ExpiryStage) -> String {
        "\(notificationPrefix)\(item.id.uuidString).\(stage.rawValue)"
    }

    private func reminderTitle(item: FoodItem, stage: ExpiryStage, language: AppLanguage) -> String {
        let name = item.localizedName(for: language)
        switch (language, stage) {
        case (.hinglish, .threeDays):
            return "\(item.emoji) \(name) expires in 3 days"
        case (.hinglish, .oneDay):
            return "Use \(name) tomorrow \(item.emoji)"
        case (.hinglish, .expired):
            return "\(name) has expired \(item.emoji)"
        case (.english, .threeDays):
            return "\(item.emoji) \(name) expires in 3 days"
        case (.english, .oneDay):
            return "Use \(name) tomorrow \(item.emoji)"
        case (.english, .expired):
            return "\(name) has expired \(item.emoji)"
        case (.spanish, .threeDays):
            return "\(item.emoji) \(name) caduca en 3 días"
        case (.spanish, .oneDay):
            return "Usa \(name) mañana \(item.emoji)"
        case (.spanish, .expired):
            return "\(name) ya caducó \(item.emoji)"
        case (_, .fresh):
            return "\(item.emoji) \(name)"
        }
    }

    private func reminderBody(item: FoodItem, stage: ExpiryStage, language: AppLanguage) -> String {
        switch (language, stage) {
        case (.hinglish, .threeDays):
            return "Add it to this week meal plan before it gets old."
        case (.hinglish, .oneDay):
            return "Quick recipe suggestion ready. Cook this today and avoid waste."
        case (.hinglish, .expired):
            return "Mark it used or remove it from your fridge list to keep score accurate."
        case (.english, .threeDays):
            return "Plan this ingredient in this week's meals before it gets old."
        case (.english, .oneDay):
            return "Quick recipe suggestion is ready. Cook it today and avoid waste."
        case (.english, .expired):
            return "Mark it used or remove it from your fridge list to keep your score accurate."
        case (.spanish, .threeDays):
            return "Inclúyelo en tus comidas de esta semana antes de que se eche a perder."
        case (.spanish, .oneDay):
            return "Hay una receta rápida lista. Cocínalo hoy para evitar desperdicio."
        case (.spanish, .expired):
            return "Márcalo como usado o elimínalo de tu lista para mantener el puntaje correcto."
        case (_, .fresh):
            return ""
        }
    }
}

extension Notification.Name {
    static let ecoChefOpenDishExplorer = Notification.Name("EcoChefOpenDishExplorer")
    static let ecoChefAppDidBecomeActive = Notification.Name("EcoChefAppDidBecomeActive")
}
