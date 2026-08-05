import SwiftUI

/// Decision #12: only Today and Find exist as tabs until Archive/Vault/You are
/// real, useful destinations — no empty placeholder tabs.
struct RootTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sparkles") }
            VibeSearchView()
                .tabItem { Label("Find", systemImage: "magnifyingglass") }
        }
        .tint(DogearColor.forest)
    }
}
