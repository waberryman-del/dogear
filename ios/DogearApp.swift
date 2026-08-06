import SwiftUI

@main
struct DogearApp: App {
    @StateObject private var library = LibraryStore()

    init() {
        // CONFIRMED (this session): print() output from LibraryStore/
        // RecommendationEngine/VibeSearchView was never reaching Console.app,
        // `log stream`, or `simctl launch --console` — checked via `log show`
        // against the running process and found zero app-originated lines
        // despite real network activity. Root cause: stdout is line-buffered
        // only when it's a TTY; redirected to a pipe/file (which is what all
        // of those capture paths do under the hood), Swift's print() becomes
        // fully block-buffered and short output just sits unflushed. This is
        // almost certainly also why on-device console copying was unreliable.
        // Forcing line buffering makes every print() line flush immediately.
        setvbuf(stdout, nil, _IOLBF, 0)
    }

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
