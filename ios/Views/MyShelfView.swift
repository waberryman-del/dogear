import SwiftUI

/// Decision #42(b): rebuilt as five tappable shelf tiles — Currently Reading,
/// Want to Read, and the three finished shelves from decision #3 — each
/// showing a book count and drilling into the actual book list on tap. This
/// replaces the previous single long inline-sections layout; the underlying
/// categories, counts, and filters are decision #30's, unchanged — only the
/// navigation pattern is new. Current design tokens only; the brand board's
/// exact shelf art (decision #23) is still Phase 4.
///
/// Wrapped in a `NavigationStack` by `RootTabView`, not here — this view
/// only ever needs to attach `.navigationDestination`, not own the stack.
struct MyShelfView: View {
    @EnvironmentObject var library: LibraryStore

    enum Category: String, CaseIterable, Identifiable, Hashable {
        case currentlyReading, wantToRead, keepForever, gladIReadIt, shouldveStopped
        var id: String { rawValue }

        var title: String {
            switch self {
            case .currentlyReading: return "Currently Reading"
            case .wantToRead: return "Want to Read"
            case .keepForever: return "Keep Forever"
            case .gladIReadIt: return "Glad I Read It"
            case .shouldveStopped: return "Should've Stopped"
            }
        }
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            if library.entries.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: DogearSpacing.space4) {
                    ForEach(Category.allCases) { category in
                        NavigationLink(value: category) {
                            tile(category)
                        }
                        .buttonStyle(DogearPressStyle())
                    }
                }
                .padding(.horizontal, DogearSpacing.space5)
                .padding(.vertical, DogearSpacing.space6)
            }
        }
        .background(DogearColor.paper)
        .navigationTitle("My shelf")
        .navigationDestination(for: Category.self) { category in
            ShelfCategoryListView(category: category)
                .environmentObject(library)
        }
    }

    private func tile(_ category: Category) -> some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space2) {
            Text("\(count(for: category))")
                .font(DogearType.displayL)
                .foregroundStyle(DogearColor.ink)
            Text(category.title)
                .font(DogearType.caption).tracking(1.5)
                .foregroundStyle(DogearColor.brass)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(DogearSpacing.space4)
        .background(DogearColor.linen)
        .clipShape(RoundedRectangle(cornerRadius: DogearRadius.card))
    }

    private func count(for category: Category) -> Int {
        Self.entries(for: category, in: library.entries).count
    }

    /// Decision #30's categories/filters, unchanged — shared with
    /// `ShelfCategoryListView` below so the tile's count and the drilled-into
    /// list can never drift out of sync with each other.
    static func entries(for category: Category, in all: [LibraryEntry]) -> [LibraryEntry] {
        switch category {
        case .currentlyReading:
            return all.filter { $0.status == .reading }
        case .wantToRead:
            return all.filter { $0.status == .wantToRead }
        case .keepForever:
            return all.filter { $0.status == .finished && $0.shelfPlacement == .keepForever }
        case .gladIReadIt:
            return all.filter { $0.status == .finished && $0.shelfPlacement == .gladIReadIt }
        case .shouldveStopped:
            return all.filter { $0.status == .finished && $0.shelfPlacement == .shouldveStopped }
        }
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

/// Decision #42(b)'s drill-in destination for a single shelf tile — the same
/// grid-of-spines rendering decision #30 originally had inline, just reached
/// by navigation now. Computes its list live from `library.entries` (rather
/// than taking a snapshot at navigation time) so a shelf change made from the
/// detail sheet while this list is open — placing a book, starting to read —
/// is reflected immediately, not stale until the next visit.
private struct ShelfCategoryListView: View {
    @EnvironmentObject var library: LibraryStore
    let category: MyShelfView.Category
    @State private var selectedEntry: LibraryEntry?
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 14)]

    private var entries: [LibraryEntry] {
        MyShelfView.entries(for: category, in: library.entries)
    }

    var body: some View {
        ScrollView {
            if entries.isEmpty {
                emptyState
            } else {
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
                .padding(.vertical, DogearSpacing.space6)
            }
        }
        .background(DogearColor.paper)
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedEntry) { entry in
            BookDetailView(book: entry.book)
                .environmentObject(library)
        }
    }

    private var emptyState: some View {
        Text("Nothing here yet")
            .font(.system(.title3, design: .serif)).italic()
            .foregroundStyle(DogearColor.mutedInk)
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
