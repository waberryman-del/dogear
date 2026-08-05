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

    private let recEngine = RecommendationEngine()
    private let defaults = UserDefaults.standard
    private let hasOnboardedKey = "dogear.hasCompletedOnboarding"
    private let onboardingGenresKey = "dogear.onboardingGenres"

    init() {
        hasCompletedOnboarding = defaults.bool(forKey: hasOnboardedKey)
        if let saved = defaults.array(forKey: onboardingGenresKey) as? [String] {
            onboardingGenres = Set(saved.compactMap(Genre.init(rawValue:)))
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
        // Deliberately does NOT trigger a recommendation refresh — refresh is earned by
        // finishing/shelving a book, or by the manual bell. A check-in is a signal for
        // the *next* recommend() call, not a refresh trigger itself.
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

    // MARK: - Manual refresh (the bell)

    func ringTheBell() async {
        await refreshRecommendations()
    }

    private func refreshRecommendations() async {
        isRefreshingRecs = true
        defer { isRefreshingRecs = false }
        do {
            recommendations = try await recEngine.nextPicks(
                basedOn: entries,
                onboardingGenres: onboardingGenres
            )
            recommendationsLoadFailed = false
        } catch {
            // Leave any existing recommendations on screen — a failed refresh should
            // never blank out picks the reader already saw. The retry state lives
            // alongside them instead.
            recommendationsLoadFailed = true
        }
    }
}
