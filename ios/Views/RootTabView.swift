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
            TodayView()
                .tabItem { Label("Today", systemImage: "sparkles") }
            SearchView()
                .tabItem { Label("Search", systemImage: "text.magnifyingglass") }
            VibeSearchView()
                .tabItem { Label("Find", systemImage: "magnifyingglass") }
            // MyShelfView doesn't wrap itself in a NavigationStack — it was
            // built to be pushed inside Today's existing stack (see Today's
            // header "My shelf" link, still there and left as-is). Wrapping
            // it here rather than in MyShelfView itself avoids a nested
            // NavigationStack (and a second nav bar) when that push path
            // is used, while still giving the tab root its own nav context.
            NavigationStack { MyShelfView() }
                .tabItem { Label("Shelf", systemImage: "books.vertical") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(DogearColor.forest)
    }
}
