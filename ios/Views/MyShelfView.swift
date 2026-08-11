import SwiftUI

/// Decision #42(b): rebuilt as five tappable shelf tiles — Currently Reading,
/// Want to Read, and the three finished shelves from decision #3 — each
/// showing a book count and drilling into the actual book list on tap. This
/// replaces the previous single long inline-sections layout; the underlying
/// categories, counts, and filters are decision #30's, unchanged — only the
/// navigation pattern is new.
///
/// Phase 4 Stage 3: the three finished/judged shelves (Keep Forever, Glad I
/// Read It, Should've Stopped) now render as brand-board-matched shelf art
/// (`shelfArtRow`) instead of plain count tiles — the board only color-codes
/// these three, not Currently Reading / Want to Read, which stay as the
/// original plain tiles. Vertical order (Keep Forever top, Should've Stopped
/// bottom) comes directly from the board's "My Shelf" mockup.
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

        /// Phase 4 Stage 3 background art, brand board-matched — only the
        /// three finished shelves have art; the other two stay `nil` and
        /// render as plain tiles.
        var shelfArtAssetName: String? {
            switch self {
            case .currentlyReading, .wantToRead: return nil
            case .keepForever: return "ShelfKeepForever"
            case .gladIReadIt: return "ShelfGladIReadIt"
            case .shouldveStopped: return "ShelfShouldveStopped"
            }
        }
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    private let plainTiles: [Category] = [.currentlyReading, .wantToRead]
    private let finishedShelves: [Category] = [.keepForever, .gladIReadIt, .shouldveStopped]

    var body: some View {
        ScrollView {
            if library.entries.isEmpty {
                emptyState
            } else {
                VStack(spacing: DogearSpacing.space5) {
                    LazyVGrid(columns: columns, spacing: DogearSpacing.space4) {
                        ForEach(plainTiles) { category in
                            NavigationLink(value: category) {
                                tile(category)
                            }
                            .buttonStyle(DogearPressStyle())
                        }
                    }

                    VStack(spacing: DogearSpacing.space4) {
                        ForEach(finishedShelves) { category in
                            NavigationLink(value: category) {
                                shelfArtRow(category)
                            }
                            .buttonStyle(DogearPressStyle())
                        }
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

    /// Photoreal shelf background (Phase 4 Stage 3 asset, generated to match
    /// `docs/brand-board.png`'s "BOOK SHELF COLORS" treatment) with title and
    /// count overlaid on a top-anchored scrim — never placed directly on the
    /// photo, since local brightness/busyness in the art varies book to book
    /// and plain text on top of it isn't reliably legible.
    private func shelfArtRow(_ category: Category) -> some View {
        let rowHeight: CGFloat = 132
        return ZStack(alignment: .topLeading) {
            if let assetName = category.shelfArtAssetName {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: rowHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }

            LinearGradient(
                colors: [.black.opacity(0.62), .black.opacity(0.22), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: rowHeight)

            VStack(alignment: .leading, spacing: DogearSpacing.space1) {
                Text(category.title)
                    .font(DogearType.rowLabel)
                    .foregroundStyle(.white)
                Text("\(count(for: category)) books")
                    .font(DogearType.caption).tracking(1.2)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(DogearSpacing.space4)
        }
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity)
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
