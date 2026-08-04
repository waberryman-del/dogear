import SwiftUI

@main
struct DogearApp: App {
    @StateObject private var library = LibraryStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(library)
        }
    }
}
