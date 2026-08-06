import SwiftUI

/// Decision #12 (amended) — full 5-tab bar: Today (decision #24's once-daily
/// ritual), Search (decision #25 — real metadata search + the relocated
/// row-browsing engine), Find/Vibe Search (unchanged), Shelf, Profile
/// (decision #28). The earlier "no empty placeholder tabs" reasoning held
/// while Search/Shelf/Profile had no real content — they now do (or, for
/// Search/Profile mid-pivot, are actively being filled in this same pass).
struct RootTabView: View {
    var body: some View {
        TabView {
            // Icons matched to docs/brand-board.png's iconography row
            // (house / magnifying glass / sparkle / library / person).
            TodayView()
                .tabItem { Label("Today", systemImage: "house") }
            SearchView()
                .tabItem { Label("Search", systemImage: "text.magnifyingglass") }
            VibeSearchView()
                .tabItem { Label("Find", systemImage: "sparkles") }
            // MyShelfView doesn't wrap itself in a NavigationStack — Today's
            // header used to push it into its own stack, but that link is
            // gone now that Shelf is a real tab (its sole caller now).
            // Wrapping it here rather than in MyShelfView itself keeps that
            // choice local to this one call site.
            NavigationStack { MyShelfView() }
                .tabItem { Label("Shelf", systemImage: "books.vertical") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(DogearColor.forest)
    }
}
