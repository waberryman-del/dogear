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

    private func makeRequest(path: String, body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sharedSecret, forHTTPHeaderField: "X-App-Secret")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    func nextPicks(basedOn library: [LibraryEntry], onboardingGenres: Set<Genre>) async throws -> [Recommendation] {
        let finished = library.filter { $0.status == .finished }
        let currentlyReading = library.filter { $0.status == .reading }

        let payload: [String: Any] = [
            "onboarding_genres": onboardingGenres.map { $0.rawValue },
            "read_history": finished.map { entry in
                [
                    "title": entry.book.title,
                    "author": entry.book.author,
                    "genres": entry.book.genres,
                    "shelf_placement": (entry.shelfPlacement?.rawValue as Any?) ?? NSNull(),
                    "why_liked": entry.aiWhyYouLikedIt ?? ""
                ]
            },
            // Mid-read signal — feeds the engine before a book is even finished.
            "currently_reading": currentlyReading.map { entry in
                [
                    "title": entry.book.title,
                    "still_enjoying_midpoint": (entry.midpointCheckIn?.stillEnjoying as Any?) ?? NSNull()
                ]
            }
        ]

        let request = try makeRequest(path: "recommend", body: payload)
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(RecommendationResponse.self, from: data)
        return decoded.recommendations
    }

    func generateWhyYouLikedIt(for entry: LibraryEntry) async throws -> String {
        let request = try makeRequest(path: "why-liked-it", body: [
            "title": entry.book.title,
            "shelf_placement": entry.shelfPlacement?.rawValue ?? "gladIReadIt",
            "still_enjoying_midpoint": (entry.midpointCheckIn?.stillEnjoying as Any?) ?? NSNull(),
            "highlights": entry.highlights.map { $0.text }
        ])
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        return decoded["note"] ?? ""
    }
}

private struct RecommendationResponse: Codable {
    let recommendations: [Recommendation]
}
