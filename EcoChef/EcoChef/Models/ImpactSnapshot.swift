import Foundation

struct ImpactSnapshot: Hashable {
    let weekLabel: String
    let saved: Double
    let wasted: Double
}

struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let emoji: String
    let sfSymbol: String
    let isUnlocked: Bool
}
