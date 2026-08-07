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

    /// Decision #29: Today's greeting, having lost the "DOGEAR" wordmark
    /// above it, needed more visual weight to still read as the screen's
    /// anchor — bumped up from `titleItalic` (24pt) to `displayL` (32pt).
    static var displayLItalic: Font { displayL.italic() }

    /// Not in Design System 0.1 — added for Phase 3's recommendation row
    /// labels ("Because you loved Beloved"), which are short reflective
    /// statements per Section 04's italic-serif rule but repeat several times
    /// per screen, so full Title (24pt) reads too heavy stacked. Sits between
    /// Title and Body; flagging for formalization into the design doc.
    static let rowLabel = Font.system(size: 18, weight: .regular, design: .serif)
    static var rowLabelItalic: Font { rowLabel.italic() }
}
