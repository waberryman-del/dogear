import Foundation
import Combine
import SwiftUI

@MainActor
final class LibraryStore: ObservableObject {
    @Published var entries: [LibraryEntry] = []
    @Published var recommendationRows: [RecommendationRow] = []
    @Published var isRefreshingRecs = false
    @Published var recommendationsLoadFailed = false
    /// True once a Today load has actually completed (success or failure) —
    /// lets the UI tell "haven't tried yet" apart from "tried and genuinely
    /// got nothing back," so it never shows the wrong empty-state message.
    @Published private(set) var hasAttemptedTodayLoad = false
    @Published var onboardingGenres: Set<Genre> = []   // set once, during onboarding
    @Published private(set) var hasCompletedOnboarding: Bool

    /// Every book ever surfaced by either recommend() or vibeSearch(), whether
    /// or not the reader added it — separate from `entries` (see CLAUDE.md
    /// decision #8). Persisted so it survives relaunches, same as onboarding.
    @Published private(set) var shownBooks: [ShownBookRecord] = []

    private let recEngine = RecommendationEngine()
    private let defaults = UserDefaults.standard
    private let hasOnboardedKey = "dogear.hasCompletedOnboarding"
    private let onboardingGenresKey = "dogear.onboardingGenres"
    private let shownBooksKey = "dogear.shownBooks"
    private let recommendationRowsKey = "dogear.recommendationRows"

    /// Debounce guards against overlapping recommend()/vibeSearch() calls —
    /// e.g. the app backgrounded and foregrounded in quick succession firing
    /// Today's feed load more than once before the first call resolves. A
    /// redundant call while one is already in flight is dropped rather than
    /// stacking a second concurrent request, which was observed to trigger
    /// Anthropic rate limiting under rapid repeats. Safe to check-then-set
    /// synchronously like this since LibraryStore is @MainActor and there's
    /// no `await` between the check and the set — no other call can interleave.
    private var isTodayRefreshInFlight = false
    private var isVibeSearchInFlight = false

    init() {
        hasCompletedOnboarding = defaults.bool(forKey: hasOnboardedKey)
        if let saved = defaults.array(forKey: onboardingGenresKey) as? [String] {
            onboardingGenres = Set(saved.compactMap(Genre.init(rawValue:)))
        }
        if let data = defaults.data(forKey: shownBooksKey),
           let decoded = try? JSONDecoder().decode([ShownBookRecord].self, from: data) {
            shownBooks = decoded
        }
        // Show last session's picks immediately on launch instead of a blank
        // loading screen every time — loadTodayFeedIfNeeded() refreshes them
        // in the background once Today appears.
        if let data = defaults.data(forKey: recommendationRowsKey),
           let decoded = try? JSONDecoder().decode([RecommendationRow].self, from: data) {
            recommendationRows = decoded
        }
    }

    // MARK: - Onboarding

    func completeOnboarding(genres: Set<Genre>) async {
        onboardingGenres = genres
        defaults.set(genres.map { $0.rawValue }, forKey: onboardingGenresKey)
        defaults.set(true, forKey: hasOnboardedKey)
        hasCompletedOnboarding = true
        await refreshRecommendations()   // seeds the very first shelf from genres alone
    }

    // MARK: - Adding + starting books

    func addToShelf(_ book: Book, status: ReadStatus = .wantToRead) {
        guard !entries.contains(where: { $0.book.id == book.id }) else { return }
        entries.append(LibraryEntry(
            book: book, status: status, dateAdded: .now,
            dateStartedReading: status == .reading ? .now : nil,
            dateFinished: nil, shelfPlacement: nil,
            aiWhyYouLikedIt: nil, midpointCheckIn: nil, highlights: []
        ))
    }

    /// Undo for `addToShelf` — the only shelf-entry lifecycle that exists before
    /// Phase 3's start-reading/finish flows land, so this simply removes the
    /// entry outright rather than trying to model an in-between state.
    func removeFromShelf(_ bookID: String) {
        entries.removeAll { $0.book.id == bookID }
    }

    func startReading(_ bookID: String) {
        guard let idx = entries.firstIndex(where: { $0.book.id == bookID }) else { return }
        entries[idx].status = .reading
        entries[idx].dateStartedReading = .now
        // Schedule the one midpoint check-in 5 days out. A local notification should be
        // registered here in the real implementation (UNUserNotificationCenter) — this
        // just records the intended ask date; Week 2/3 wires the actual notification.
        entries[idx].midpointCheckIn = MidpointCheckIn(
            askedOn: Calendar.current.date(byAdding: .day, value: 5, to: .now) ?? .now,
            stillEnjoying: nil
        )
    }

    /// Stops the current read from the hero card without going through shelf
    /// placement — placement only happens on actually finishing a book
    /// (decision #2). Reverts to wantToRead and clears reading-only state so
    /// the card returns to its empty/invite state and the book can be
    /// restarted cleanly later. Used for both "switch to a different book"
    /// (caller starts a new one right after) and "just stop for now."
    func stopReading(_ bookID: String) {
        guard let idx = entries.firstIndex(where: { $0.book.id == bookID }) else { return }
        entries[idx].status = .wantToRead
        entries[idx].dateStartedReading = nil
        entries[idx].currentPage = nil
        entries[idx].readingGoal = nil
        entries[idx].midpointCheckIn = nil
    }

    // MARK: - Midpoint check-in

    func answerMidpointCheckIn(_ bookID: String, stillEnjoying: Bool) {
        guard let idx = entries.firstIndex(where: { $0.book.id == bookID }) else { return }
        entries[idx].midpointCheckIn?.stillEnjoying = stillEnjoying
        // Deliberately does NOT trigger a recommendation refresh — refresh is earned only
        // by finishing/shelving a book. A check-in is a signal for the *next* recommend()
        // call, not a refresh trigger itself.
    }

    // MARK: - Finishing a book — shelf placement IS the rating

    func placeOnShelf(_ bookID: String, placement: ShelfPlacement) async {
        guard let idx = entries.firstIndex(where: { $0.book.id == bookID }) else { return }
        entries[idx].status = .finished
        entries[idx].shelfPlacement = placement
        entries[idx].dateFinished = .now
        if let note = try? await recEngine.generateWhyYouLikedIt(for: entries[idx]) {
            entries[idx].aiWhyYouLikedIt = note
        }
        DogearHaptics.actionCommitted()  // Design System Section 10: "Book placed on shelf → medium impact"
        await refreshRecommendations()   // earned refresh
    }

    // MARK: - Vibe search (Phase 2)

    /// Results are scoped to whichever screen asked — unlike `recommendations`,
    /// this isn't app-wide state, so it's just a throwing passthrough to the
    /// service layer rather than another @Published array. Blends `query` with
    /// this reader's actual taste profile (decision #10) and carries forward any
    /// one-tap `refinements` already applied (decision #14).
    func vibeSearch(query: String, refinements: [String] = []) async throws -> VibeSearchResult {
        // VibeSearchView already guards against rapid re-taps itself; this is
        // a second, defense-in-depth line for any other caller.
        guard !isVibeSearchInFlight else { throw LibraryStoreError.requestAlreadyInFlight }
        isVibeSearchInFlight = true
        defer { isVibeSearchInFlight = false }

        let result = try await recEngine.vibeSearch(
            query: query,
            refinements: refinements,
            basedOn: entries,
            onboardingGenres: onboardingGenres,
            shownBooks: shownBooks
        )
        let filtered = filterAlreadyShown(result.results)
        recordShown(filtered.map { $0.book })
        return VibeSearchResult(results: filtered, suggestedRefinements: result.suggestedRefinements)
    }

    // MARK: - Today's feed

    /// Today has no manual refresh control (decision #4, amended) — new picks
    /// are earned only by shelving a book (`placeOnShelf`), which calls
    /// `refreshRecommendations()` directly. This is the cold-start/retry path,
    /// called each time Today appears. If a cached batch from last session is
    /// already showing (see `init()`), this refreshes it silently in the
    /// background rather than blocking the UI on a fresh network call — the
    /// reader sees something immediately and it updates underneath them. Only
    /// blocks with a loading state when there's truly nothing cached to show.
    func loadTodayFeedIfNeeded() async {
        guard !isTodayRefreshInFlight else { return }
        if recommendationRows.isEmpty {
            await refreshRecommendations()
        } else {
            await performRefresh(blocking: false)
        }
    }

    private func refreshRecommendations() async {
        await performRefresh(blocking: true)
    }

    private func performRefresh(blocking: Bool) async {
        guard !isTodayRefreshInFlight else { return }
        isTodayRefreshInFlight = true
        if blocking { isRefreshingRecs = true }
        defer {
            isTodayRefreshInFlight = false
            if blocking { isRefreshingRecs = false }
            hasAttemptedTodayLoad = true
        }
        do {
            let rows = try await recEngine.nextPicks(
                basedOn: entries,
                onboardingGenres: onboardingGenres,
                shownBooks: shownBooks
            )
            let filtered = filterAlreadyShown(rows)
            withAnimation(DogearMotion.standard) {
                recommendationRows = filtered
            }
            recordShown(filtered.flatMap { $0.recommendations }.map { $0.book })
            recommendationsLoadFailed = false
            persistRecommendationRows()
        } catch {
            print("[LibraryStore] Today refresh failed: \(error)")
            // Leave any existing rows on screen — a failed refresh should
            // never blank out picks the reader already saw. Only surface the
            // retry state when there was nothing on screen to begin with; a
            // silent background refresh failing shouldn't flag already-good
            // cached content as broken.
            if recommendationRows.isEmpty {
                recommendationsLoadFailed = true
            }
        }
    }

    private func persistRecommendationRows() {
        if let data = try? JSONEncoder().encode(recommendationRows) {
            defaults.set(data, forKey: recommendationRowsKey)
        }
    }

    // MARK: - Reading progress + goals (decision #18)

    func updateCurrentPage(_ page: Int, for bookID: String) {
        guard let idx = entries.firstIndex(where: { $0.book.id == bookID }) else { return }
        entries[idx].currentPage = page
    }

    /// `goal: nil` clears an existing goal.
    func setReadingGoal(_ goal: ReadingGoal?, for bookID: String) {
        guard let idx = entries.firstIndex(where: { $0.book.id == bookID }) else { return }
        entries[idx].readingGoal = goal
    }

    /// Today's hero card is singular — if more than one book is somehow
    /// `.reading` at once, the most recently started wins (decision #17).
    var currentlyReadingEntry: LibraryEntry? {
        entries
            .filter { $0.status == .reading }
            .sorted { ($0.dateStartedReading ?? .distantPast) > ($1.dateStartedReading ?? .distantPast) }
            .first
    }

    // MARK: - Shown-book exclusion (decision #8)

    /// Defense in depth: even though both prompts are told to exclude
    /// `shownBooks`, a model can still slip one through. Drop it client-side
    /// rather than surface a book the reader has already been shown — a
    /// shorter-than-requested batch is preferable to a repeat. Used by Vibe
    /// Search's flat results list.
    private func filterAlreadyShown(_ recs: [Recommendation]) -> [Recommendation] {
        let shownKeys = Set(shownBooks.map { $0.normalizedKey })
        return recs.filter { rec in
            let key = ShownBookRecord.normalize(title: rec.book.title, author: rec.book.author)
            return !shownKeys.contains(key)
        }
    }

    /// Same idea, applied per-row for Today's feed — a row that loses every
    /// book to this filter is dropped entirely rather than shown empty.
    private func filterAlreadyShown(_ rows: [RecommendationRow]) -> [RecommendationRow] {
        let shownKeys = Set(shownBooks.map { $0.normalizedKey })
        return rows.compactMap { row in
            let filtered = row.recommendations.filter { rec in
                let key = ShownBookRecord.normalize(title: rec.book.title, author: rec.book.author)
                return !shownKeys.contains(key)
            }
            guard !filtered.isEmpty else { return nil }
            return RecommendationRow(label: row.label, kind: row.kind, recommendations: filtered)
        }
    }

    private func recordShown(_ books: [Book]) {
        var existingKeys = Set(shownBooks.map { $0.normalizedKey })
        var newRecords: [ShownBookRecord] = []
        for book in books {
            let record = ShownBookRecord(id: book.id, title: book.title, author: book.author)
            if !existingKeys.contains(record.normalizedKey) {
                existingKeys.insert(record.normalizedKey)
                newRecords.append(record)
            }
        }
        guard !newRecords.isEmpty else { return }
        shownBooks.append(contentsOf: newRecords)
        if let data = try? JSONEncoder().encode(shownBooks) {
            defaults.set(data, forKey: shownBooksKey)
        }
    }
}

enum LibraryStoreError: Error {
    /// Thrown when `vibeSearch()` is called while a previous call is still
    /// in flight — should be unreachable in normal use since VibeSearchView
    /// guards against this itself, but is a real error rather than a silent
    /// no-op so a bypassing caller doesn't get a misleading empty success.
    case requestAlreadyInFlight
}
