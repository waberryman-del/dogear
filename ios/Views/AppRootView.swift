import SwiftUI

/// Onboarding once, then the full 5-tab shell (Today, Search, Find, Shelf,
/// Profile — decision #12, amended).
struct AppRootView: View {
    @EnvironmentObject var library: LibraryStore

    var body: some View {
        if library.hasCompletedOnboarding {
            RootTabView()
        } else {
            OnboardingView()
        }
    }
}
