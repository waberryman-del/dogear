import SwiftUI

@main
struct DogearApp: App {
    @StateObject private var library = LibraryStore()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(library)
                // Dogear's palette (Paper/Linen/Forest/Ink/Brass) is a fixed set of
                // hex swatches with no dark-mode variants yet — letting the system
                // apply Dark Mode makes SwiftUI's implicit .primary/.secondary text
                // colors flip to white/light-gray while these backgrounds stay put,
                // producing illegible text. Lock to light until a real dark theme
                // is designed (see design system Section 03).
                .preferredColorScheme(.light)
        }
    }
}
