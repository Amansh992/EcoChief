import CoreData
import Foundation

struct EcoChefStateSnapshot {
    var foods: [FoodItem]
    var selectedLanguage: AppLanguage
    var notificationsEnabled: Bool
    var prefersDarkMode: Bool
    var recentLogs: [String]
    var totalSavedItems: Int
    var totalWastedItems: Int
    var monthlyCO2SavedKg: Double
    var monthlyMoneySaved: Int
    var mealsFromRescuedFood: Int
    var currentStreakDays: Int
    var customShelfLives: [String: Int]
    var lastCookedDay: Date?
}

@MainActor
final class EcoChefPersistenceService {
    static let shared = EcoChefPersistenceService()

    private enum Entity {
        static let food = "CDFood"
        static let appState = "CDAppState"
    }

    private let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = Self.makeModel()
        let container = NSPersistentContainer(name: "EcoChefStorage", managedObjectModel: model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        var loadError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        container.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }
        semaphore.wait()
        if let loadError {
            assertionFailure("Core Data store failed to load: \(loadError)")
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        self.container = container
    }

    func loadState(defaultFoods: [FoodItem], defaultShelfLives: [String: Int]) -> EcoChefStateSnapshot {
        let context = container.viewContext

        let appState = fetchAppState(context: context)
        let storedFoods = fetchFoods(context: context)
        let foods = storedFoods.isEmpty ? defaultFoods : storedFoods

        let selectedLanguage = AppLanguage(rawValue: appState?.value(forKey: "selectedLanguage") as? String ?? "") ?? .english
        let notificationsEnabled = appState?.value(forKey: "notificationsEnabled") as? Bool ?? true
        let prefersDarkMode = appState?.value(forKey: "prefersDarkMode") as? Bool ?? false
        let recentLogs: [String] = decodeJSON([String].self, from: appState?.value(forKey: "recentLogsJSON") as? String) ?? []
        let customShelfLives: [String: Int] =
            decodeJSON([String: Int].self, from: appState?.value(forKey: "customShelfLivesJSON") as? String)
            ?? defaultShelfLives

        let totalSavedItems = Int(appState?.value(forKey: "totalSavedItems") as? Int64 ?? 18)
        let totalWastedItems = Int(appState?.value(forKey: "totalWastedItems") as? Int64 ?? 3)
        let monthlyCO2SavedKg = appState?.value(forKey: "monthlyCO2SavedKg") as? Double ?? 2.4
        let monthlyMoneySaved = Int(appState?.value(forKey: "monthlyMoneySaved") as? Int64 ?? 840)
        let mealsFromRescuedFood = Int(appState?.value(forKey: "mealsFromRescuedFood") as? Int64 ?? 12)
        let currentStreakDays = Int(appState?.value(forKey: "currentStreakDays") as? Int64 ?? 7)
        let lastCookedDay = appState?.value(forKey: "lastCookedDay") as? Date

        return EcoChefStateSnapshot(
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
    }

    func saveState(_ snapshot: EcoChefStateSnapshot) {
        let context = container.viewContext

        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.food)
        let existingFoods = (try? context.fetch(request)) ?? []
        existingFoods.forEach(context.delete)

        let foodEntity = NSEntityDescription.entity(forEntityName: Entity.food, in: context)
        snapshot.foods.forEach { item in
            guard let foodEntity else { return }
            let object = NSManagedObject(entity: foodEntity, insertInto: context)
            let rawNames = Dictionary(uniqueKeysWithValues: item.localizedNames.map { ($0.key.rawValue, $0.value) })
            object.setValue(item.id, forKey: "id")
            object.setValue(item.key, forKey: "key")
            object.setValue(item.emoji, forKey: "emoji")
            object.setValue(item.sfSymbol, forKey: "sfSymbol")
            object.setValue(encodeJSON(rawNames), forKey: "localizedNamesJSON")
            object.setValue(Int64(item.quantity), forKey: "quantity")
            object.setValue(item.addedAt, forKey: "addedAt")
            object.setValue(item.expiryDate, forKey: "expiryDate")
            object.setValue(Int64(item.shelfLifeDays), forKey: "shelfLifeDays")
        }

        let appState = fetchAppState(context: context) ?? {
            guard let entity = NSEntityDescription.entity(forEntityName: Entity.appState, in: context) else { return nil }
            let object = NSManagedObject(entity: entity, insertInto: context)
            object.setValue("singleton", forKey: "id")
            return object
        }()

        appState?.setValue(snapshot.selectedLanguage.rawValue, forKey: "selectedLanguage")
        appState?.setValue(snapshot.notificationsEnabled, forKey: "notificationsEnabled")
        appState?.setValue(snapshot.prefersDarkMode, forKey: "prefersDarkMode")
        appState?.setValue(encodeJSON(snapshot.recentLogs), forKey: "recentLogsJSON")
        appState?.setValue(Int64(snapshot.totalSavedItems), forKey: "totalSavedItems")
        appState?.setValue(Int64(snapshot.totalWastedItems), forKey: "totalWastedItems")
        appState?.setValue(snapshot.monthlyCO2SavedKg, forKey: "monthlyCO2SavedKg")
        appState?.setValue(Int64(snapshot.monthlyMoneySaved), forKey: "monthlyMoneySaved")
        appState?.setValue(Int64(snapshot.mealsFromRescuedFood), forKey: "mealsFromRescuedFood")
        appState?.setValue(Int64(snapshot.currentStreakDays), forKey: "currentStreakDays")
        appState?.setValue(encodeJSON(snapshot.customShelfLives), forKey: "customShelfLivesJSON")
        appState?.setValue(snapshot.lastCookedDay, forKey: "lastCookedDay")

        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            assertionFailure("Failed saving Core Data state: \(error)")
        }
    }

    private func fetchAppState(context: NSManagedObjectContext) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.appState)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchFoods(context: NSManagedObjectContext) -> [FoodItem] {
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.food)
        let objects = (try? context.fetch(request)) ?? []
        return objects.compactMap { object in
            guard
                let id = object.value(forKey: "id") as? UUID,
                let key = object.value(forKey: "key") as? String,
                let emoji = object.value(forKey: "emoji") as? String,
                let sfSymbol = object.value(forKey: "sfSymbol") as? String,
                let localizedNamesJSON = object.value(forKey: "localizedNamesJSON") as? String,
                let rawNames = decodeJSON([String: String].self, from: localizedNamesJSON),
                let addedAt = object.value(forKey: "addedAt") as? Date,
                let expiryDate = object.value(forKey: "expiryDate") as? Date
            else {
                return nil
            }

            let quantity = Int(object.value(forKey: "quantity") as? Int64 ?? 1)
            let shelfLifeDays = Int(object.value(forKey: "shelfLifeDays") as? Int64 ?? 1)
            let localizedNames = rawNames.reduce(into: [AppLanguage: String]()) { partialResult, pair in
                guard let language = AppLanguage(rawValue: pair.key) else { return }
                partialResult[language] = pair.value
            }

            return FoodItem(
                id: id,
                key: key,
                emoji: emoji,
                sfSymbol: sfSymbol,
                localizedNames: localizedNames,
                quantity: max(1, quantity),
                addedAt: addedAt,
                expiryDate: expiryDate,
                shelfLifeDays: max(1, shelfLifeDays)
            )
        }
    }

    private func encodeJSON<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from raw: String?) -> T? {
        guard let raw, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let food = NSEntityDescription()
        food.name = Entity.food
        food.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        food.properties = [
            attribute(name: "id", type: .UUIDAttributeType),
            attribute(name: "key", type: .stringAttributeType),
            attribute(name: "emoji", type: .stringAttributeType),
            attribute(name: "sfSymbol", type: .stringAttributeType),
            attribute(name: "localizedNamesJSON", type: .stringAttributeType),
            attribute(name: "quantity", type: .integer64AttributeType),
            attribute(name: "addedAt", type: .dateAttributeType),
            attribute(name: "expiryDate", type: .dateAttributeType),
            attribute(name: "shelfLifeDays", type: .integer64AttributeType)
        ]

        let appState = NSEntityDescription()
        appState.name = Entity.appState
        appState.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        appState.properties = [
            attribute(name: "id", type: .stringAttributeType),
            attribute(name: "selectedLanguage", type: .stringAttributeType),
            attribute(name: "notificationsEnabled", type: .booleanAttributeType),
            attribute(name: "prefersDarkMode", type: .booleanAttributeType),
            attribute(name: "recentLogsJSON", type: .stringAttributeType, isOptional: true),
            attribute(name: "totalSavedItems", type: .integer64AttributeType),
            attribute(name: "totalWastedItems", type: .integer64AttributeType),
            attribute(name: "monthlyCO2SavedKg", type: .doubleAttributeType),
            attribute(name: "monthlyMoneySaved", type: .integer64AttributeType),
            attribute(name: "mealsFromRescuedFood", type: .integer64AttributeType),
            attribute(name: "currentStreakDays", type: .integer64AttributeType),
            attribute(name: "customShelfLivesJSON", type: .stringAttributeType, isOptional: true),
            attribute(name: "lastCookedDay", type: .dateAttributeType, isOptional: true)
        ]

        model.entities = [food, appState]
        return model
    }

    private static func attribute(
        name: String,
        type: NSAttributeType,
        isOptional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        return attribute
    }
}
