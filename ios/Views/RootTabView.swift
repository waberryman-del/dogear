import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sparkles") }
            ArchiveView()
                .tabItem { Label("Archive", systemImage: "books.vertical") }
            VaultView()
                .tabItem { Label("Vault", systemImage: "quote.bubble") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(Color("Forest")) // define in Assets: deep forest green
    }
}
