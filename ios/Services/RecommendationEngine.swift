import Foundation

/// Talks to two things:
/// 1. Google Books API — free, no key needed for basic search — for real book metadata.
/// 2. Your own backend (thin proxy in front of the Anthropic Messages API) — for the
///    reasoning layer. Never call api.anthropic.com directly from the client: the key
///    would ship inside the app binary. Route through a small serverless function instead
///    (Cloudflare Worker / Vercel function / AWS Lambda — a few hours of work).
struct RecommendationEngine {

    // Fill in after Vercel deploy. Same value as APP_SHARED_SECRET in Vercel env vars —
    // fine to hardcode here since it's only an abuse guard, not real auth (see CLAUDE.md).
    private let baseURL = URL(string: "https://dogear-teal.vercel.app/api")!
    private let sharedSecret = "dogear12345"

    /// No explicit timeout here previously meant relying on `URLSession.shared`'s
    /// default (`timeoutIntervalForRequest`, nominally 60s) — which on-device
    /// testing showed the client giving up around ~24s even though the backend
    /// was still measured taking 27-35s to actually finish successfully. Rather
    /// than trust an implicit platform default that clearly wasn't behaving as
    /// documented, `timeout` is now explicit per call and always set above the
    /// corresponding endpoint's `vercel.json` maxDuration, so the client never
    /// gives up on a request that would have succeeded.
    private func makeRequest(path: String, body: [String: Any], timeout: TimeInterval) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sharedSecret, forHTTPHeaderField: "X-App-Secret")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Most-recent-first — both backend prompts are told explicitly that this
    /// ordering means "weight recent shelf placements more heavily" (decision #9).
    private func readHistoryPayload(from library: [LibraryEntry]) -> [[String: Any]] {
        library
            .filter { $0.status == .finished }
            .sorted { ($0.dateFinished ?? .distantPast) > ($1.dateFinished ?? .distantPast) }
            .map { entry in
                [
                    "title": entry.book.title,
                    "author": entry.book.author,
                    "genres": entry.book.genres,
                    "shelf_placement": (entry.shelfPlacement?.rawValue as Any?) ?? NSNull(),
                    "why_liked": entry.aiWhyYouLikedIt ?? ""
                ]
            }
    }

    private func currentlyReadingPayload(from library: [LibraryEntry]) -> [[String: Any]] {
        library
            .filter { $0.status == .reading }
            .sorted { ($0.dateStartedReading ?? .distantPast) > ($1.dateStartedReading ?? .distantPast) }
            .map { entry in
                [
                    "title": entry.book.title,
                    "still_enjoying_midpoint": (entry.midpointCheckIn?.stillEnjoying as Any?) ?? NSNull()
                ]
            }
    }

    /// "Title by Author" strings — readable to the model, unlike the opaque
    /// Google Books / Open Library ids `ShownBookRecord.id` actually holds
    /// (decision #8).
    private func shownBooksPayload(_ shownBooks: [ShownBookRecord]) -> [String] {
        shownBooks.map { "\($0.title) by \($0.author)" }
    }

    /// Returns Today's feed as labeled rows (decision #19) rather than a flat
    /// list — 1-3 taste rows grounded in specific patterns from the reader's
    /// history plus exactly one discovery row, per `recommend.js`'s prompt.
    func nextPicks(
        basedOn library: [LibraryEntry],
        onboardingGenres: Set<Genre>,
        shownBooks: [ShownBookRecord]
    ) async throws -> [RecommendationRow] {
        let payload: [String: Any] = [
            "onboarding_genres": onboardingGenres.map { $0.rawValue },
            "read_history": readHistoryPayload(from: library),
            "currently_reading": currentlyReadingPayload(from: library),
            "shown_books": shownBooksPayload(shownBooks)
        ]

        // recommend.js's vercel.json maxDuration is 60s — 75s gives real
        // headroom so the client always outlasts the server's own hard cap.
        let request = try makeRequest(path: "recommend", body: payload, timeout: 75)
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(RecommendationResponse.self, from: data)
        return decoded.rows
    }

    /// Phase 2: free-text mood/vibe search, blended with the reader's actual
    /// taste profile — never a cold, context-free query (decision #10).
    /// `refinements` are one-tap adjustments already applied on top of `query`,
    /// most-recently-applied last; the response carries the next round of
    /// suggested refinements, contextual to these results (decision #14).
    func vibeSearch(
        query: String,
        refinements: [String],
        basedOn library: [LibraryEntry],
        onboardingGenres: Set<Genre>,
        shownBooks: [ShownBookRecord]
    ) async throws -> VibeSearchResult {
        let payload: [String: Any] = [
            "query": query,
            "refinements": refinements,
            "onboarding_genres": onboardingGenres.map { $0.rawValue },
            "read_history": readHistoryPayload(from: library),
            "currently_reading": currentlyReadingPayload(from: library),
            "shown_books": shownBooksPayload(shownBooks)
        ]

        // Same 60s vercel.json maxDuration as recommend.js — same 75s headroom.
        let request = try makeRequest(path: "vibe-search", body: payload, timeout: 75)
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(VibeSearchResponse.self, from: data)
        return VibeSearchResult(results: decoded.results, suggestedRefinements: decoded.refinements)
    }

    func generateWhyYouLikedIt(for entry: LibraryEntry) async throws -> String {
        // why-liked-it.js's vercel.json maxDuration is 15s — 20s headroom.
        let request = try makeRequest(path: "why-liked-it", body: [
            "title": entry.book.title,
            "shelf_placement": entry.shelfPlacement?.rawValue ?? "gladIReadIt",
            "still_enjoying_midpoint": (entry.midpointCheckIn?.stillEnjoying as Any?) ?? NSNull(),
            "highlights": entry.highlights.map { $0.text }
        ], timeout: 20)
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        return decoded["note"] ?? ""
    }
}

struct VibeSearchResult {
    let results: [Recommendation]
    let suggestedRefinements: [String]
}

private struct RecommendationResponse: Codable {
    let rows: [RecommendationRow]
}

private struct VibeSearchResponse: Codable {
    let results: [Recommendation]
    let refinements: [String]

    // Tolerates a backend that hasn't picked up the `refinements` field yet
    // (e.g. not redeployed) rather than failing the whole search over one
    // missing key — the field is additive, not something to hard-require.
    enum CodingKeys: String, CodingKey { case results, refinements }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decode([Recommendation].self, forKey: .results)
        refinements = try container.decodeIfPresent([String].self, forKey: .refinements) ?? []
    }
}
