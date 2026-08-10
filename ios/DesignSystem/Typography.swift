import SwiftUI

/// Dogear Design System 0.1, Section 04. Playfair Display for emotional/editorial
/// content, Inter for action/state/navigation, per docs/brand-board.png. Long body
/// text is never italic. Fonts are bundled (ios/Resources/Fonts) and registered via
/// UIAppFonts in project.yml — never fall back to `.system` for these roles.
enum DogearType {
    static let displayXL = Font.custom("PlayfairDisplay-Bold", size: 40)
    static let displayL = Font.custom("PlayfairDisplay-Bold", size: 32)
    static let title = Font.custom("PlayfairDisplay-Bold", size: 24)
    static let body = Font.custom("Inter-Regular", size: 16)
    static let bodySmall = Font.custom("Inter-Regular", size: 14)
    static let label = Font.custom("Inter-SemiBold", size: 13)
    static let caption = Font.custom("Inter-Medium", size: 11)

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
    static let rowLabel = Font.custom("PlayfairDisplay-Regular", size: 18)
    static var rowLabelItalic: Font { rowLabel.italic() }
}
