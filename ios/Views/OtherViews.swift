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

// ProfileView moved to its own file (decision #28 — real minimal content,
// not this placeholder) — see ProfileView.swift.
