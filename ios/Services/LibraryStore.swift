import Foundation
import Combine

@MainActor
final class LibraryStore: ObservableObject {
    @Published var entries: [LibraryEntry] = []
    @Published var recommendations: [Recommendation] = []
    @Published var isRefreshingRecs = false
    @Published var recommendationsLoadFailed = false
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

    init() {
        hasCompletedOnboarding = defaults.bool(forKey: hasOnboardedKey)
        if let saved = defaults.array(forKey: onboardingGenresKey) as? [String] {
            onboardingGenres = Set(saved.compactMap(Genre.init(rawValue:)))
        }
        if let data = defaults.data(forKey: shownBooksKey),
           let decoded = try? JSONDecoder().decode([ShownBookRecord].self, from: data) {
            shownBooks = decoded
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
        await refreshRecommendations()   // earned refresh
    }

    // MARK: - Vibe search (Phase 2)

    /// Results are scoped to whichever screen asked — unlike `recommendations`,
    /// this isn't app-wide state, so it's just a throwing passthrough to the
    /// service layer rather than another @Published array. Blends `query` with
    /// this reader's actual taste profile (decision #10) and carries forward any
    /// one-tap `refinements` already applied (decision #14).
    func vibeSearch(query: String, refinements: [String] = []) async throws -> VibeSearchResult {
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
    /// `refreshRecommendations()` directly. This is just the cold-start/retry
    /// path: recommendations aren't persisted across launches yet (pending the
    /// Phase 3 SwiftData migration), so Today needs a way to populate itself
    /// the first time it appears, and to recover after a failed load — neither
    /// of which is a "refresh" in the earned sense, just filling an empty feed.
    func loadTodayFeedIfNeeded() async {
        guard recommendations.isEmpty, !isRefreshingRecs else { return }
        await refreshRecommendations()
    }

    private func refreshRecommendations() async {
        isRefreshingRecs = true
        defer { isRefreshingRecs = false }
        do {
            let picks = try await recEngine.nextPicks(
                basedOn: entries,
                onboardingGenres: onboardingGenres,
                shownBooks: shownBooks
            )
            let filtered = filterAlreadyShown(picks)
            recommendations = filtered
            recordShown(filtered.map { $0.book })
            recommendationsLoadFailed = false
        } catch {
            // Leave any existing recommendations on screen — a failed refresh should
            // never blank out picks the reader already saw. The retry state lives
            // alongside them instead.
            recommendationsLoadFailed = true
        }
    }

    // MARK: - Shown-book exclusion (decision #8)

    /// Defense in depth: even though both prompts are told to exclude
    /// `shownBooks`, a model can still slip one through. Drop it client-side
    /// rather than surface a book the reader has already been shown — a
    /// shorter-than-requested batch is preferable to a repeat.
    private func filterAlreadyShown(_ recs: [Recommendation]) -> [Recommendation] {
        let shownKeys = Set(shownBooks.map { $0.normalizedKey })
        return recs.filter { rec in
            let key = ShownBookRecord.normalize(title: rec.book.title, author: rec.book.author)
            return !shownKeys.contains(key)
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
