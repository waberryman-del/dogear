import SwiftUI

/// Dogear Design System 0.1, Section 10. Motion explains spatial relationships —
/// it should never slow access to books.
enum DogearMotion {
    static let quick = Animation.easeOut(duration: 0.1)
    static let standard = Animation.easeInOut(duration: 0.22)
    static let editorial = Animation.spring(response: 0.36, dampingFraction: 0.86)
    static let fold = Animation.interactiveSpring(response: 0.42, dampingFraction: 0.8)
    static let shelf = Animation.spring(response: 0.5, dampingFraction: 1.0)
}
