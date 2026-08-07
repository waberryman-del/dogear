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

    /// Runs the request and returns the body, throwing a `BackendError` with the
    /// status code and response body on anything outside 2xx. Without this, a
    /// non-2xx response (401 bad shared secret, 500 from an Anthropic-side
    /// failure, a Vercel-level timeout) falls straight into `JSONDecoder`,
    /// which throws its own decode error that looks identical, at the call
    /// site, to a genuine network failure — impossible to tell apart later.
    private func send(_ request: URLRequest, endpoint: String) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            print("[RecommendationEngine] \(endpoint) returned HTTP \(http.statusCode): \(body)")
            throw BackendError.httpError(endpoint: endpoint, status: http.statusCode, body: body)
        }
        return data
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

    /// Structured {title, author} objects, in the order they were shown
    /// (oldest first — `LibraryStore` only ever appends) — decision #8's
    /// amended scarcity fallback backfills from the oldest end of this list,
    /// so the ordering itself is load-bearing, not incidental. Previously
    /// sent as flat "Title by Author" strings; structured objects are what
    /// the backend needs to actually re-look-up and reuse one of these as a
    /// backfilled recommendation, not just quote it back to Claude for
    /// exclusion.
    private func shownBooksPayload(_ shownBooks: [ShownBookRecord]) -> [[String: String]] {
        shownBooks.map { ["title": $0.title, "author": $0.author] }
    }

    /// Every entry on the reader's shelf regardless of status (want-to-read,
    /// reading, finished, dnf) — decision #8 (amended): these are a hard,
    /// permanent exclusion with no scarcity-fallback exception, unlike
    /// `shown_books`, which the backend may backfill from when genuinely
    /// exhausted. The backend needs this as a separate list because
    /// `shown_books` doesn't indicate which entries were ever added to the
    /// shelf — it only tracks what was surfaced.
    private func shelvedBooksPayload(from library: [LibraryEntry]) -> [[String: String]] {
        library.map { ["title": $0.book.title, "author": $0.book.author] }
    }

    /// Decision #27: books explicitly dismissed from a daily pick — a real
    /// but moderate negative signal, sent to both `daily-picks.js` and
    /// `recommend.js` so Search's rows factor it in too.
    private func notInterestedPayload(_ notInterestedBooks: [NotInterestedRecord]) -> [[String: String]] {
        notInterestedBooks.map { ["title": $0.title, "author": $0.author] }
    }

    /// Returns Today's feed as labeled rows (decision #19) rather than a flat
    /// list — 1-3 taste rows grounded in specific patterns from the reader's
    /// history plus exactly one discovery row, per `recommend.js`'s prompt.
    func nextPicks(
        basedOn library: [LibraryEntry],
        onboardingGenres: Set<Genre>,
        shownBooks: [ShownBookRecord],
        notInterestedBooks: [NotInterestedRecord]
    ) async throws -> [RecommendationRow] {
        let payload: [String: Any] = [
            "onboarding_genres": onboardingGenres.map { $0.rawValue },
            "read_history": readHistoryPayload(from: library),
            "currently_reading": currentlyReadingPayload(from: library),
            "shown_books": shownBooksPayload(shownBooks),
            "shelved_books": shelvedBooksPayload(from: library),
            "not_interested": notInterestedPayload(notInterestedBooks)
        ]

        // recommend.js's vercel.json maxDuration is 60s — 75s gives real
        // headroom so the client always outlasts the server's own hard cap.
        let request = try makeRequest(path: "recommend", body: payload, timeout: 75)
        let data = try await send(request, endpoint: "recommend")
        do {
            return try JSONDecoder().decode(RecommendationResponse.self, from: data).rows
        } catch {
            print("[RecommendationEngine] recommend decode failed: \(error) — raw: \(String(data: data, encoding: .utf8) ?? "<non-utf8>")")
            throw error
        }
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
            "shown_books": shownBooksPayload(shownBooks),
            "shelved_books": shelvedBooksPayload(from: library)
        ]

        // Same 60s vercel.json maxDuration as recommend.js — same 75s headroom.
        let request = try makeRequest(path: "vibe-search", body: payload, timeout: 75)
        let data = try await send(request, endpoint: "vibe-search")
        do {
            let decoded = try JSONDecoder().decode(VibeSearchResponse.self, from: data)
            return VibeSearchResult(
                results: decoded.results,
                suggestedRefinements: decoded.refinements,
                rawResultCount: decoded.results.count
            )
        } catch {
            print("[RecommendationEngine] vibe-search decode failed: \(error) — raw: \(String(data: data, encoding: .utf8) ?? "<non-utf8>")")
            throw error
        }
    }

    /// Decision #24: Today's once-daily 3 picks — a single, much smaller
    /// generation task than `nextPicks()`'s three-row taxonomy, deliberately
    /// a flat `[Recommendation]` with no row/kind shape.
    func dailyPicks(
        basedOn library: [LibraryEntry],
        onboardingGenres: Set<Genre>,
        shownBooks: [ShownBookRecord],
        notInterestedBooks: [NotInterestedRecord]
    ) async throws -> [Recommendation] {
        let payload: [String: Any] = [
            "onboarding_genres": onboardingGenres.map { $0.rawValue },
            "read_history": readHistoryPayload(from: library),
            "currently_reading": currentlyReadingPayload(from: library),
            "shown_books": shownBooksPayload(shownBooks),
            "shelved_books": shelvedBooksPayload(from: library),
            "not_interested": notInterestedPayload(notInterestedBooks)
        ]

        // daily-picks.js's vercel.json maxDuration is 60s — 75s gives real
        // headroom, same margin as recommend.js/vibe-search.js.
        let request = try makeRequest(path: "daily-picks", body: payload, timeout: 75)
        let data = try await send(request, endpoint: "daily-picks")
        do {
            return try JSONDecoder().decode(DailyPicksResponse.self, from: data).picks
        } catch {
            print("[RecommendationEngine] daily-picks decode failed: \(error) — raw: \(String(data: data, encoding: .utf8) ?? "<non-utf8>")")
            throw error
        }
    }

    /// Decision #25: real title/author/ISBN search against the same
    /// two-source metadata lookup used elsewhere — no AI reasoning, no
    /// Anthropic call at all. Hits `book-search.js`, a distinct endpoint
    /// from the two reasoning ones above.
    func searchBooks(query: String) async throws -> [Book] {
        let payload: [String: Any] = ["query": query]
        // book-search.js's vercel.json maxDuration is 15s — 20s headroom,
        // same margin as why-liked-it.js since neither involves a Claude call.
        let request = try makeRequest(path: "book-search", body: payload, timeout: 20)
        let data = try await send(request, endpoint: "book-search")
        do {
            return try JSONDecoder().decode(BookSearchResponse.self, from: data).results
        } catch {
            print("[RecommendationEngine] book-search decode failed: \(error) — raw: \(String(data: data, encoding: .utf8) ?? "<non-utf8>")")
            throw error
        }
    }

    func generateWhyYouLikedIt(for entry: LibraryEntry) async throws -> String {
        // why-liked-it.js's vercel.json maxDuration is 15s — 20s headroom.
        let request = try makeRequest(path: "why-liked-it", body: [
            "title": entry.book.title,
            "shelf_placement": entry.shelfPlacement?.rawValue ?? "gladIReadIt",
            "still_enjoying_midpoint": (entry.midpointCheckIn?.stillEnjoying as Any?) ?? NSNull(),
            "highlights": entry.highlights.map { $0.text }
        ], timeout: 20)
        let data = try await send(request, endpoint: "why-liked-it")
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        return decoded["note"] ?? ""
    }

    /// Stage 1 (decisions #33/#37/#39.3-4): a single book's "why this fits
    /// you" verdict + best-effort Recognition, blended with the reader's
    /// taste profile the same way `nextPicks`/`vibeSearch`/`dailyPicks` are.
    /// `LibraryStore` decides how to use the two fields in the response —
    /// this call always runs once per book regardless of whether a prior
    /// reason exists (decision #37, amended), so it stays a plain passthrough
    /// with no caching logic of its own.
    func fetchVerdict(
        for book: Book,
        basedOn library: [LibraryEntry],
        onboardingGenres: Set<Genre>
    ) async throws -> BookVerdictResponse {
        let payload: [String: Any] = [
            "book": [
                "title": book.title,
                "author": book.author,
                "summary": book.summary as Any? ?? NSNull()
            ],
            "onboarding_genres": onboardingGenres.map { $0.rawValue },
            "read_history": readHistoryPayload(from: library),
            "currently_reading": currentlyReadingPayload(from: library)
        ]
        // book-verdict.js's vercel.json maxDuration is 15s — 20s headroom,
        // same margin as why-liked-it.js/book-search.js.
        let request = try makeRequest(path: "book-verdict", body: payload, timeout: 20)
        let data = try await send(request, endpoint: "book-verdict")
        do {
            return try JSONDecoder().decode(BookVerdictResponse.self, from: data)
        } catch {
            print("[RecommendationEngine] book-verdict decode failed: \(error) — raw: \(String(data: data, encoding: .utf8) ?? "<non-utf8>")")
            throw error
        }
    }
}

enum BackendError: LocalizedError {
    case httpError(endpoint: String, status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .httpError(let endpoint, let status, let body):
            return "\(endpoint) returned HTTP \(status): \(body)"
        }
    }
}

struct VibeSearchResult {
    let results: [Recommendation]
    let suggestedRefinements: [String]
    /// Count before `LibraryStore`'s shownBooks exclusion filter runs — lets
    /// the UI tell "the backend genuinely found nothing" apart from "it found
    /// results but every one was already shown," which need different, honest
    /// copy rather than one generic empty-state message.
    let rawResultCount: Int
}

/// Stage 1: `book-verdict.js`'s response. Not `private` — `LibraryStore`
/// (decision #37's reuse-or-fetch orchestration) consumes this directly.
struct BookVerdictResponse: Codable {
    let verdict: String
    let recognition: String?
}

private struct RecommendationResponse: Codable {
    let rows: [RecommendationRow]
}

private struct DailyPicksResponse: Codable {
    let picks: [Recommendation]
}

private struct BookSearchResponse: Codable {
    let results: [Book]
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
