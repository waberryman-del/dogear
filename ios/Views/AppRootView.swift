import SwiftUI

/// Smallest working slice: onboarding, then straight to Today. Archive, Vault,
/// Profile, the midpoint check-in, and the fold gesture are all out of scope for
/// this pass — see RootTabView for the full-app shell once those land.
struct AppRootView: View {
    @EnvironmentObject var library: LibraryStore

    var body: some View {
        if library.hasCompletedOnboarding {
            TodayView()
        } else {
            OnboardingView()
        }
    }
}
