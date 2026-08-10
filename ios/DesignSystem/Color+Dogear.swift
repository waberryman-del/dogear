import SwiftUI

/// Dogear Design System 0.1, Section 03. Backed by Assets.xcassets colorsets —
/// never reference raw hex values from call sites, go through these.
///
/// Phase 4 retune against docs/brand-board.png: forest #0F2B22, sage #2E4A3A,
/// paper #F6F1E7, linen #E7DECA, brass #C79A62 come directly from the board's
/// 5-swatch palette. rust #6B3528 was sampled from the board's "Should've
/// Stopped" shelf spine art (no hex given for it directly). ink and mutedInk
/// are unchanged — the board gives no explicit or visual reference for either.
enum DogearColor {
    static let forest = Color("Forest")
    static let ink = Color("Ink")
    static let linen = Color("Linen")
    static let paper = Color("Paper")
    static let brass = Color("Brass")
    static let rust = Color("Rust")
    static let sage = Color("Sage")
    static let mutedInk = Color("MutedInk")
}
