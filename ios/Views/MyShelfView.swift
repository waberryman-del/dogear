import SwiftUI

/// Decision #30: no longer a flat grid of everything. Real sections, in
/// order — Currently Reading (a real list, can be more than one book; this
/// is separate from the hero card's single-book spotlight on Today, which
/// shows only the most recent), Want to Read (the same underlying list
/// Today's "Up Next" already previews), then the three finished-book
/// shelves per decision #3: Keep Forever, Glad I Read It, Should've
/// Stopped. Gives want-to-read/currently-reading books — which don't have
/// a `shelfPlacement` and never belonged in the three finished shelves — an
/// honest home.
struct MyShelfView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var selectedEntry: LibraryEntry?
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 14)]

    var body: some View {
        ScrollView {
            if library.entries.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: DogearSpacing.space8) {
                    shelfSection(title: "CURRENTLY READING", entries: currentlyReading)
                    shelfSection(title: "WANT TO READ", entries: wantToRead)
                    shelfSection(title: "KEEP FOREVER", entries: entries(placed: .keepForever))
                    shelfSection(title: "GLAD I READ IT", entries: entries(placed: .gladIReadIt))
                    shelfSection(title: "SHOULD'VE STOPPED", entries: entries(placed: .shouldveStopped))
                }
                .padding(.vertical, DogearSpacing.space6)
            }
        }
        .background(DogearColor.paper)
        .navigationTitle("My shelf")
        .sheet(item: $selectedEntry) { entry in
            BookDetailView(book: entry.book)
                .environmentObject(library)
        }
    }

    @ViewBuilder
    private func shelfSection(title: String, entries: [LibraryEntry]) -> some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: DogearSpacing.space3) {
                Text(title)
                    .font(DogearType.caption).tracking(1.5)
                    .foregroundStyle(DogearColor.brass)
                    .padding(.horizontal, DogearSpacing.space5)
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(entries) { entry in
                        Button {
                            selectedEntry = entry
                        } label: {
                            ShelfEntryCard(entry: entry)
                        }
                        .buttonStyle(DogearPressStyle())
                    }
                }
                .padding(.horizontal, DogearSpacing.space5)
            }
        }
    }

    private var currentlyReading: [LibraryEntry] {
        library.entries.filter { $0.status == .reading }
    }

    private var wantToRead: [LibraryEntry] {
        library.entries.filter { $0.status == .wantToRead }
    }

    private func entries(placed placement: ShelfPlacement) -> [LibraryEntry] {
        library.entries.filter { $0.status == .finished && $0.shelfPlacement == placement }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Nothing on your shelf yet")
                .font(.system(.title3, design: .serif)).italic()
                .foregroundStyle(DogearColor.ink)
            Text("Add a book from Today to see it here.")
                .font(.subheadline)
                .foregroundStyle(DogearColor.mutedInk)
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
            Text(entry.book.title)
                .font(.caption.bold())
                .foregroundStyle(DogearColor.ink)
            Text(entry.book.author)
                .font(.caption2)
                .foregroundStyle(DogearColor.mutedInk)
                .lineLimit(1)
        }
        .frame(width: 100)
    }
}
