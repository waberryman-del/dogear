import SwiftUI

/// Simplest possible visibility into what's been added — everything currently
/// in `LibraryStore.entries` as one grid. Not the three-shelf Archive design;
/// that's a later pass once shelf placement (finishing a book) is wired up.
struct MyShelfView: View {
    @EnvironmentObject var library: LibraryStore
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 14)]

    var body: some View {
        ScrollView {
            if library.entries.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(library.entries) { entry in
                        ShelfEntryCard(entry: entry)
                    }
                }
                .padding()
            }
        }
        .background(Color("Linen"))
        .navigationTitle("My shelf")
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Nothing on your shelf yet")
                .font(.system(.title3, design: .serif)).italic()
            Text("Add a book from Today to see it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

private struct ShelfEntryCard: View {
    let entry: LibraryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BookCoverView(url: entry.book.coverURL, title: entry.book.title, width: 100, height: 146)
            Text(entry.book.title).font(.caption.bold()).lineLimit(2)
            Text(entry.book.author).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(width: 100)
    }
}
