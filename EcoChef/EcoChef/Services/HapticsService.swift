import Foundation
#if os(iOS)
import UIKit
#endif

@MainActor
enum HapticsService {
    static func tap() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    static func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }

    static func celebrate() {
        #if os(iOS)
        let notify = UINotificationFeedbackGenerator()
        notify.prepare()
        notify.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let delayedImpact = UIImpactFeedbackGenerator(style: .medium)
            delayedImpact.prepare()
            delayedImpact.impactOccurred()
        }
        #endif
    }
}
