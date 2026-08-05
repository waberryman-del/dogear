import SwiftUI

/// Onboarding once, then the two-tab shell (Today, Find). Archive, Vault, and
/// Profile aren't real destinations yet, so they stay out of the tab bar
/// (decision #12) until Phase 3 gives them something to show.
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
