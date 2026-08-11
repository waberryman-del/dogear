import SwiftUI

/// Decision #25: Search hosts two things sharing one tab, not shown at once —
/// native `.searchable` behavior handles the switch between them:
/// 1. Real title/author/ISBN search (`book-search.js`, no AI reasoning) —
///    shown while there's an active, submitted query.
/// 2. The AI-personalized row-browsing experience relocated wholesale from
///    the old Today feed (decision #25: "same engine... just relocated,"
///    approved as a literal move, not a redesign) — shown as the default
///    content once search is empty/cancelled. This section — state,
///    pull-to-refresh, loading/error/exhausted copy — is TodayView's former
///    `content`/`runPullRefresh`, moved here unchanged.
struct SearchView: View {
    @EnvironmentObject var library: LibraryStore

    @State private var query = ""
    @State private var searchResults: [Book] = []
    @State private var isSearching = false
    @State private var searchFailed = false
    @State private var hasSearched = false
    @State private var selectedBook: Book?
    @State private var selectedRecommendation: Recommendation?

    /// Same as old TodayView: distinct from `library.isRefreshingRecs`,
    /// which stays false for the silent background refresh — this only
    /// tracks the explicit pull gesture.
    @State private var isPullRefreshing = false
    @State private var pullRefreshFailed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DogearSpacing.space6) {
                    if hasSearched {
                        searchResultsSection
                    } else {
                        if isPullRefreshing {
                            refreshingBanner
                        } else if pullRefreshFailed {
                            InlineRetryBanner(message: "Couldn't refresh — showing your last picks.") {
                                Task { await runPullRefresh() }
                            }
                        }
                        browseSection
                    }
                }
                .padding(.vertical, DogearSpacing.space6)
            }
            .background(DogearColor.paper)
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Title, author, or ISBN")
            .onSubmit(of: .search) {
                Task { await performSearch() }
            }
            .onChange(of: query) { _, newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    hasSearched = false
                    searchResults = []
                    searchFailed = false
                }
            }
            .task { await library.loadTodayFeedIfNeeded() }
            .refreshable { await runPullRefresh() }
            .sheet(item: $selectedBook) { book in
                BookDetailView(book: book)
                    .environmentObject(library)
            }
            .sheet(item: $selectedRecommendation) { rec in
                BookDetailView(book: rec.book, reason: rec.reason)
                    .environmentObject(library)
            }
        }
    }

    // MARK: - Real metadata search (decision #25, part 1)

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSearching else { return }
        isSearching = true
        searchFailed = false
        do {
            searchResults = try await library.searchBooks(query: trimmed)
            hasSearched = true
        } catch {
            print("[SearchView] search failed: \(error)")
            searchFailed = true
        }
        isSearching = false
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if isSearching {
            LoadingStateView(message: "Searching…")
        } else if searchFailed {
            ErrorStateView(message: "Couldn't reach your library's brain.") {
                Task { await performSearch() }
            }
        } else if searchResults.isEmpty {
            Text("No matches for that title, author, or ISBN.")
                .font(DogearType.bodySmall)
                .foregroundStyle(DogearColor.mutedInk)
                .padding(.horizontal, DogearSpacing.space5)
                .padding(.vertical, DogearSpacing.space8)
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104), spacing: DogearSpacing.space4)],
                spacing: DogearSpacing.space5
            ) {
                ForEach(searchResults) { book in
                    Button {
                        selectedBook = book
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            BookCoverView(
                                url: book.coverURL, title: book.title, width: 104, height: 150,
                                onTap: { selectedBook = book },
                                onFold: { library.addToShelf(book, status: .wantToRead, reason: nil) }
                            )
                            Text(book.title)
                                .font(.caption.bold())
                                .foregroundStyle(DogearColor.ink)
                            Text(book.author)
                                .font(.caption2)
                                .foregroundStyle(DogearColor.mutedInk)
                                .lineLimit(1)
                        }
                        .frame(width: 104)
                    }
                    .buttonStyle(DogearPressStyle())
                }
            }
            .padding(.horizontal, DogearSpacing.space5)
        }
    }

    // MARK: - Relocated row-browsing engine (decision #25, part 2 — was TodayView's `content`)

    @ViewBuilder
    private var browseSection: some View {
        if library.isRefreshingRecs && library.recommendationRows.isEmpty {
            LoadingStateView(message: "Finding your next reads…")
        } else if library.recommendationsLoadFailed && library.recommendationRows.isEmpty {
            ErrorStateView(message: "Couldn't reach your library's brain.") {
                Task { await library.loadTodayFeedIfNeeded() }
            }
        } else if library.recommendationRows.isEmpty {
            if library.hasAttemptedTodayLoad {
                exhaustedState
            } else {
                LoadingStateView(message: "Finding your next reads…")
            }
        } else {
            VStack(alignment: .leading, spacing: DogearSpacing.space6) {
                ForEach(library.recommendationRows) { row in
                    RecommendationRowView(
                        row: row,
                        onSelect: { rec in selectedRecommendation = rec },
                        onFold: { rec in library.addToShelf(rec.book, status: .wantToRead, reason: rec.reason) }
                    )
                }
            }
        }
    }

    private func runPullRefresh() async {
        isPullRefreshing = true
        let succeeded = await library.refreshTodayFromPull()
        isPullRefreshing = false
        pullRefreshFailed = !succeeded
        if succeeded {
            DogearHaptics.success()
        } else {
            DogearHaptics.failure()
        }
    }

    /// CONFIRMED (code inspection): during a pull-to-refresh, this banner's
    /// own `ProgressView` rendered at the same time as iOS's own native
    /// pull-to-refresh spinner — `.refreshable` shows that automatically for
    /// the whole duration of its action, outside this view's control. Two
    /// spinners stacked was the actual bug; text-only here keeps the one
    /// piece this banner adds (real copy for what's a genuinely long wait)
    /// without a second competing spinner glyph.
    private var refreshingBanner: some View {
        Text("Finding new books for you…")
            .font(DogearType.bodySmall)
            .foregroundStyle(DogearColor.mutedInk)
            .padding(.horizontal, DogearSpacing.space5)
    }

    private var exhaustedState: some View {
        Text("You've read deep into this pattern. Try Vibe Search for something different.")
            .font(DogearType.bodySmall)
            .foregroundStyle(DogearColor.mutedInk)
            .padding(.horizontal, DogearSpacing.space5)
            .padding(.vertical, DogearSpacing.space8)
    }
}
