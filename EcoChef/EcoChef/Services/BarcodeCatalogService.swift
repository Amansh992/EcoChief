import Foundation

struct BarcodeMatchResult {
    enum Confidence {
        case exact
        case inferred
    }

    let item: QuickAddItem
    let confidence: Confidence
}

struct BarcodeCatalogService {
    static let shared = BarcodeCatalogService()

    private let exactBarcodeToItemKey: [String: String] = [
        "8901030895451": "milk",
        "8901030865379": "bread",
        "8901030849164": "eggs",
        "8901030852317": "tomato",
        "8901030871189": "onion",
        "8901030894102": "potato",
        "8901030860046": "spinach",
        "8901030829913": "carrot",
        "8901030812304": "paneer",
        "8901030837426": "cucumber",
        "8901030858173": "pepper",
        "8901030879024": "chili"
    ]

    private let heuristicKeys: [String] = [
        "tomato", "onion", "potato", "milk", "bread", "eggs",
        "spinach", "carrot", "cucumber", "pepper", "paneer", "chili"
    ]

    func resolveBarcode(_ rawCode: String, availableItems: [QuickAddItem]) -> BarcodeMatchResult? {
        let code = rawCode.filter(\.isNumber)
        guard code.count >= 8 else { return nil }

        if let mappedKey = exactBarcodeToItemKey[code],
           let item = availableItems.first(where: { $0.key == mappedKey }) {
            return BarcodeMatchResult(item: item, confidence: .exact)
        }

        let checksum = code.compactMap(\.wholeNumberValue).reduce(0, +)
        let inferredKey = heuristicKeys[checksum % heuristicKeys.count]
        guard let inferredItem = availableItems.first(where: { $0.key == inferredKey }) else { return nil }
        return BarcodeMatchResult(item: inferredItem, confidence: .inferred)
    }
}
