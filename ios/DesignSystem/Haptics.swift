import UIKit

/// Dogear Design System 0.1, Section 10 "Motion and haptics" — the haptic map
/// documented there (chip selected → selectionChanged, fold armed → light
/// impact, fold committed → medium impact, bell rung → rigid + light success,
/// book placed on shelf → medium impact, error/failed request → notification
/// error, successful refresh → notification success) was never wired into
/// code before this pass; this is the token layer for it. `UIFeedbackGenerator`
/// already no-ops when the user has system haptics disabled, so callers don't
/// need to check that themselves. Never call these from passive scrolling —
/// only from a deliberate tap or a request actually resolving.
enum DogearHaptics {
    static func chipSelected() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func actionArmed() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func actionCommitted() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func failure() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
