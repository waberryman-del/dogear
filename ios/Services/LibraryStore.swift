import Foundation
import Combine
import SwiftUI

@MainActor
final class LibraryStore: ObservableObject {
    @Published var entries: [LibraryEntry] = []
    /// Lets a screen (e.g. Today's empty "Up Next" CTA) send the reader to
    /// another tab without a second navigation system — transient UI state,
    /// not shelf data, so deliberately not persisted like `entries` above.
    @Published var selectedTab: RootTab = .today
    @Published var recommendationRows: [RecommendationRow] = []
    @Published var isRefreshingRecs = false
    @Published var recommendationsLoadFailed = false
    /// True once a Today load has actually completed (success or failure) —
    /// lets the UI tell "haven't tried yet" apart from "tried and genuinely
    /// got nothing back," so it never shows the wrong empty-state message.
    @Published private(set) var hasAttemptedTodayLoad = false
    @Published var onboardingGenres: Set<Genre> = []   // set once, during onboarding
    @Published private(set) var hasCompletedOnboarding: Bool

    /// Decision #29: optional first name for Today's greeting, set from
    /// Profile settings. Plain text, no validation. Stopgap until real
    /// accounts/login exist (explicitly not v1) — do not build that now,
    /// this field is meant to be replaced by the account name then.
    @Published private(set) var readerName: String = ""

    /// Every book ever surfaced by either recommend() or vibeSearch(), whether
    /// or not the reader added it — separate from `entries` (see CLAUDE.md
    /// decision #8). Persisted so it survives relaunches, same as onboarding.
    @Published private(set) var shownBooks: [ShownBookRecord] = []

    // MARK: - Today's daily picks (decision #24, #26, #27)

    /// Exactly 3 (once generated), or empty before today's batch has loaded.
    @Published private(set) var todaysPicks: [Recommendation] = []
    /// Keyed by `Recommendation.book.id`. A pick with no entry here is
    /// undecided.
    @Published private(set) var todaysPickDecisions: [String: DailyPickDecision] = [:]
    /// The calendar day `todaysPicks` was generated for — compared against
    /// `Calendar.current` (decision: local calendar day, not a rolling 24h
    /// window) to decide whether a fresh batch is due.
    @Published private(set) var todaysPicksDate: Date?
    @Published var isLoadingTodaysPicks = false
    @Published var todaysPicksLoadFailed = false

    /// Decision #27: books explicitly dismissed from a daily pick — a real
    /// but moderate negative signal, distinct from shelf placements, fed to
    /// both `daily-picks.js` and `recommend.js` (Search's rows) so both
    /// reason about it. Not a hard client-side exclusion list itself — the
    /// book is already covered by `shownBooks`'s hard exclusion the moment
    /// it's generated as a pick, regardless of how the reader decides on it.
    @Published private(set) var notInterestedBooks: [NotInterestedRecord] = []

    private let recEngine = RecommendationEngine()
    private let defaults = UserDefaults.standard
    private let entriesKey = "dogear.entries"
    private let hasOnboardedKey = "dogear.hasCompletedOnboarding"
    private let onboardingGenresKey = "dogear.onboardingGenres"
    private let readerNameKey = "dogear.readerName"
    private let shownBooksKey = "dogear.shownBooks"
    private let recommendationRowsKey = "dogear.recommendationRows"
    private let todaysPicksKey = "dogear.todaysPicks"
    private let todaysPickDecisionsKey = "dogear.todaysPickDecisions"
    private let todaysPicksDateKey = "dogear.todaysPicksDate"
    private let notInterestedBooksKey = "dogear.notInterestedBooks"

    /// CONFIRMED bug (found via live console capture, not assumption): this
    /// used to be a bare Bool guard (`isTodayRefreshInFlight`) shared across
    /// `.task`'s automatic load, `.refreshable`'s pull gesture, and
    /// `placeOnShelf`'s earned refresh. A bare guard means a *second* caller
    /// that arrives while the first is still running just returns instantly
    /// — a real no-op, not "the same fetch, just not the caller who started
    /// it." Reproduced: pulling to refresh moments after Today's own
    /// automatic load (which fires on every appearance) silently no-op'd
    /// the pull — the visible "Finding new books for you" banner cleared in
    /// well under a second because there was never a real fetch behind it,
    /// while the *original* automatic load kept running invisibly and
    /// eventually updated content on its own, disconnected from the pull.
    /// Storing the in-flight work as a `Task` that a second caller can
    /// `await` instead of skip fixes this: every caller either starts the
    /// real fetch or genuinely waits on the one already running, and gets
    /// its real success/failure back.
    private var inFlightTodayRefresh: Task<Bool, Never>?
    private var isVibeSearchInFlight = false

    init() {
        if let data = defaults.data(forKey: entriesKey),
           let decoded = try? JSONDecoder().decode([LibraryEntry].self, from: data) {
            entries = decoded
        }
        hasCompletedOnboarding = defaults.bool(forKey: hasOnboardedKey)
        if let saved = defaults.array(forKey: onboardingGenresKey) as? [String] {
            onboardingGenres = Set(saved.compactMap(Genre.init(rawValue:)))
        }
        readerName = defaults.string(forKey: readerNameKey) ?? ""
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
        if let data = defaults.data(forKey: notInterestedBooksKey),
           let decoded = try? JSONDecoder().decode([NotInterestedRecord].self, from: data) {
            notInterestedBooks = decoded
        }
        // Today's picks + decisions + the date they were generated for all
        // load together — `loadTodaysPicksIfNeeded()` is what decides
        // whether this cached batch is still today's or needs replacing.
        if let data = defaults.data(forKey: todaysPicksKey),
           let decoded = try? JSONDecoder().decode([Recommendation].self, from: data) {
            todaysPicks = decoded
        }
        if let data = defaults.data(forKey: todaysPickDecisionsKey),
           let decoded = try? JSONDecoder().decode([String: DailyPickDecision].self, from: data) {
            todaysPickDecisions = decoded
        }
        if let timestamp = defaults.object(forKey: todaysPicksDateKey) as? Date {
            todaysPicksDate = timestamp
        }
    }

    // MARK: - Onboarding

    func completeOnboarding(genres: Set<Genre>) async {
        onboardingGenres = genres
        defaults.set(genres.map { $0.rawValue }, forKey: onboardingGenresKey)
        defaults.set(true, forKey: hasOnboardedKey)
        hasCompletedOnboarding = true
        await performRefresh(blocking: true)   // seeds the very first shelf from genres alone
    }

    /// Decision #29: no validation — a blank name just means the greeting
    /// falls back to the time-of-day phrase alone.
    func setReaderName(_ name: String) {
        readerName = name
        defaults.set(name, forKey: readerNameKey)
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
        persistEntries()
    }

    /// Undo for `addToShelf` — the only shelf-entry lifecycle that exists before
    /// Phase 3's start-reading/finish flows land, so this simply removes the
    /// entry outright rather than trying to model an in-between state.
    func removeFromShelf(_ bookID: String) {
        entries.removeAll { $0.book.id == bookID }
        persistEntries()
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
        persistEntries()
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
        persistEntries()
    }

    // MARK: - Midpoint check-in

    func answerMidpointCheckIn(_ bookID: String, stillEnjoying: Bool) {
        guard let idx = entries.firstIndex(where: { $0.book.id == bookID }) else { return }
        entries[idx].midpointCheckIn?.stillEnjoying = stillEnjoying
        persistEntries()
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
        persistEntries()
        DogearHaptics.actionCommitted()  // Design System Section 10: "Book placed on shelf → medium impact"
        await performRefresh(blocking: true)   // earned refresh
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
        return VibeSearchResult(
            results: filtered,
            suggestedRefinements: result.suggestedRefinements,
            rawResultCount: result.rawResultCount
        )
    }

    // MARK: - Search (decision #25, part 1 — real metadata search)

    /// No AI reasoning, no exclusion filtering — a direct catalog lookup, so
    /// unlike `vibeSearch`/`nextPicks`/`dailyPicks` this doesn't touch
    /// `shownBooks` at all. Finding a book via search and looking at it
    /// isn't "being shown a recommendation."
    func searchBooks(query: String) async throws -> [Book] {
        try await recEngine.searchBooks(query: query)
    }

    // MARK: - Today's daily picks (decision #24, #26, #27)

    var allTodaysPicksDecided: Bool {
        !todaysPicks.isEmpty && todaysPicks.allSatisfy { todaysPickDecisions[$0.book.id] != nil }
    }

    /// Generates a fresh 3 once per local calendar day (confirmed: local
    /// `Calendar.current`, not a rolling 24h window) — a no-op if today's
    /// batch already exists, decided or not. Any picks still undecided when
    /// a new day arrives become an implicit skip: recorded into `shownBooks`
    /// so they don't resurface, but never counted as an explicit "not
    /// interested" signal — that's reserved for an actual decision.
    func loadTodaysPicksIfNeeded() async {
        if let date = todaysPicksDate, Calendar.current.isDateInToday(date) {
            return
        }
        if !todaysPicks.isEmpty {
            let undecided = todaysPicks.filter { todaysPickDecisions[$0.book.id] == nil }
            recordShown(undecided.map { $0.book })
        }

        isLoadingTodaysPicks = true
        todaysPicksLoadFailed = false
        defer { isLoadingTodaysPicks = false }

        do {
            let picks = try await recEngine.dailyPicks(
                basedOn: entries,
                onboardingGenres: onboardingGenres,
                shownBooks: shownBooks,
                notInterestedBooks: notInterestedBooks
            )
            todaysPicks = picks
            todaysPickDecisions = [:]
            todaysPicksDate = Calendar.current.startOfDay(for: .now)
            recordShown(picks.map { $0.book })
            persistTodaysPicks()
        } catch {
            print("[LibraryStore] Today's picks load failed: \(error)")
            todaysPicksLoadFailed = true
        }
    }

    /// "wantToRead" adds to the shelf — never auto-starts reading, starting
    /// is always a separate, deliberate action from My Shelf (decision #26).
    /// "notInterested" records a moderate negative signal (decision #27),
    /// tracked distinctly from shelf placements since this book was never
    /// shelved at all.
    func decideTodaysPick(_ bookID: String, decision: DailyPickDecision) {
        guard let pick = todaysPicks.first(where: { $0.book.id == bookID }) else { return }
        todaysPickDecisions[bookID] = decision
        persistTodaysPickDecisions()

        switch decision {
        case .wantToRead:
            addToShelf(pick.book, status: .wantToRead)
        case .notInterested:
            recordNotInterested(pick.book)
        }
    }

    private func recordNotInterested(_ book: Book) {
        let key = ShownBookRecord.normalize(title: book.title, author: book.author)
        guard !notInterestedBooks.contains(where: { $0.normalizedKey == key }) else { return }
        notInterestedBooks.append(NotInterestedRecord(id: book.id, title: book.title, author: book.author))
        persistNotInterestedBooks()
    }

    private func persistTodaysPicks() {
        if let data = try? JSONEncoder().encode(todaysPicks) {
            defaults.set(data, forKey: todaysPicksKey)
        }
        defaults.set(todaysPicksDate, forKey: todaysPicksDateKey)
    }

    private func persistTodaysPickDecisions() {
        if let data = try? JSONEncoder().encode(todaysPickDecisions) {
            defaults.set(data, forKey: todaysPickDecisionsKey)
        }
    }

    private func persistNotInterestedBooks() {
        if let data = try? JSONEncoder().encode(notInterestedBooks) {
            defaults.set(data, forKey: notInterestedBooksKey)
        }
    }

    private func persistEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: entriesKey)
        }
    }

    // MARK: - Search's row-browsing engine (decision #25 — this used to be
    // "Today's feed"; the underlying engine/state below wasn't rewritten, it
    // was relocated. Names below (e.g. `loadTodayFeedIfNeeded`) are known
    // naming debt from that move, left as-is deliberately to avoid a large,
    // risky rename mid-pivot — worth a quieter follow-up pass later.

    /// Search's row content has no manual refresh control of its own beyond
    /// pull-to-refresh — new picks are also earned whenever a book is placed
    /// on a shelf (`placeOnShelf`), which calls `performRefresh(blocking:
    /// true)` directly. This is the cold-start/retry path, called each time
    /// Search appears. If a cached batch from last session is already
    /// showing (see `init()`), this refreshes it silently in the background
    /// rather than blocking the UI on a fresh network call. Only blocks with
    /// a loading state when there's truly nothing cached to show.
    func loadTodayFeedIfNeeded() async {
        await performRefresh(blocking: recommendationRows.isEmpty)
    }

    /// Explicit pull-to-refresh entry point, distinct from the silent
    /// background load: this is a deliberate user action, so unlike
    /// `loadTodayFeedIfNeeded()`'s silence-on-failure behavior, the caller
    /// gets a real success/failure back to show honest feedback for.
    @discardableResult
    func refreshTodayFromPull() async -> Bool {
        await performRefresh(blocking: false)
    }

    @discardableResult
    private func performRefresh(blocking: Bool) async -> Bool {
        if let existing = inFlightTodayRefresh {
            return await existing.value
        }
        if blocking { isRefreshingRecs = true }

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }
            do {
                let rows = try await self.recEngine.nextPicks(
                    basedOn: self.entries,
                    onboardingGenres: self.onboardingGenres,
                    shownBooks: self.shownBooks,
                    notInterestedBooks: self.notInterestedBooks
                )
                let filtered = self.filterAlreadyShown(rows)
                withAnimation(DogearMotion.standard) {
                    self.recommendationRows = filtered
                }
                self.recordShown(filtered.flatMap { $0.recommendations }.map { $0.book })
                self.recommendationsLoadFailed = false
                self.persistRecommendationRows()
                return true
            } catch {
                print("[LibraryStore] Today refresh failed: \(error)")
                // Leave any existing rows on screen — a failed refresh should
                // never blank out picks the reader already saw. Only surface
                // the retry state when there was nothing on screen to begin
                // with; a silent background refresh failing shouldn't flag
                // already-good cached content as broken. (Pull-to-refresh
                // callers still get `false` back to show their own honest
                // feedback — this only controls the full-screen error state.)
                if self.recommendationRows.isEmpty {
                    self.recommendationsLoadFailed = true
                }
                return false
            }
        }
        inFlightTodayRefresh = task
        let succeeded = await task.value
        inFlightTodayRefresh = nil
        if blocking { isRefreshingRecs = false }
        hasAttemptedTodayLoad = true
        return succeeded
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
        persistEntries()
    }

    /// `goal: nil` clears an existing goal.
    func setReadingGoal(_ goal: ReadingGoal?, for bookID: String) {
        guard let idx = entries.firstIndex(where: { $0.book.id == bookID }) else { return }
        entries[idx].readingGoal = goal
        persistEntries()
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
    ///
    /// CONFIRMED root cause of a real bug (reproduced against production):
    /// this used to filter purely on "is this key in shownBooks," with no
    /// exception — but that's precisely where a decision #8 scarcity-
    /// backfilled pick comes from by definition, so every backfilled
    /// recommendation was getting silently stripped right back out here,
    /// collapsing any row that only reached its floor via backfill. `rec
    /// .backfilled` lets this filter skip the ones the server intentionally
    /// resurfaced, while still catching a genuine model mistake.
    private func filterAlreadyShown(_ recs: [Recommendation]) -> [Recommendation] {
        let shownKeys = Set(shownBooks.map { $0.normalizedKey })
        return recs.filter { rec in
            if rec.backfilled { return true }
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
                if rec.backfilled { return true }
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
