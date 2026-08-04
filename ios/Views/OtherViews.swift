import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject var library: LibraryStore
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(library.entries) { entry in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color("Forest"))
                            .frame(height: 64)
                    }
                }
                .padding()
            }
            .navigationTitle("Archive")
        }
    }
}

struct VaultView: View {
    @EnvironmentObject var library: LibraryStore
    var body: some View {
        NavigationStack {
            List {
                ForEach(library.entries.flatMap { $0.highlights }) { highlight in
                    Text(highlight.text).italic()
                }
            }
            .navigationTitle("Quote vault")
        }
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            Text("Reading DNA visualization goes here")
                .foregroundStyle(.secondary)
                .navigationTitle("Profile")
        }
    }
}
