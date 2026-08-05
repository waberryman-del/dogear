import SwiftUI

/// Dogear Design System 0.1, Section 04. Serif for emotional/editorial content,
/// sans for action/state/navigation. Long body text is never italic.
enum DogearType {
    static let displayXL = Font.system(size: 40, weight: .regular, design: .serif)
    static let displayL = Font.system(size: 32, weight: .regular, design: .serif)
    static let title = Font.system(size: 24, weight: .regular, design: .serif)
    static let body = Font.system(size: 16, weight: .regular)
    static let bodySmall = Font.system(size: 14, weight: .regular)
    static let label = Font.system(size: 13, weight: .semibold)
    static let caption = Font.system(size: 11, weight: .medium)

    /// Reserved for greetings, atmosphere, short reflective statements only.
    static var titleItalic: Font { title.italic() }
}
