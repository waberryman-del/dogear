import Foundation

struct Book: Identifiable, Codable, Equatable {
    let id: String              // ISBN or Google Books volumeId
    var title: String
    var author: String
    var coverURL: URL?
    var pageCount: Int?
    var genres: [String]
    var summary: String?
    var publicationYear: Int?   // Stage 1 (decision #39.2, at-a-glance strip)
}

/// Fixed genre list for onboarding — pick up to 5. Keep this list short and concrete;
/// it's the only cold-start signal the recommendation engine gets before any book is
/// finished, so vague/overlapping categories hurt more here than anywhere else in the app.
enum Genre: String, CaseIterable, Codable, Identifiable {
    case literaryFiction = "Literary fiction"
    case mystery = "Mystery & thriller"
    case scienceFiction = "Science fiction"
    case fantasy = "Fantasy"
    case historicalFiction = "Historical fiction"
    case memoir = "Memoir"
    case biography = "Biography"
    case businessStrategy = "Business & strategy"
    case popScience = "Popular science"
    case history = "History"
    case philosophy = "Philosophy"
    case poetry = "Poetry"

    var id: String { rawValue }
}

/// Placement IS the rating — no separate star score. Replaces a 1-5 number with a
/// judgment the reader actually makes naturally when deciding whether to keep a book.
enum ShelfPlacement: String, Codable {
    case keepForever
    case gladIReadIt
    case shouldveStopped
}

enum ReadStatus: String, Codable {
    case wantToRead, reading, finished, dnf
}

struct LibraryEntry: Identifiable, Codable, Equatable {
    var id: String { book.id }
    var book: Book
    var status: ReadStatus
    var dateAdded: Date
    var dateStartedReading: Date?     // set when status moves to .reading — drives the midpoint check-in timer
    var dateFinished: Date?
    var shelfPlacement: ShelfPlacement?   // set only when status == .finished
    var aiWhyYouLikedIt: String?          // generated once, on shelf placement
    var midpointCheckIn: MidpointCheckIn?
    var highlights: [Highlight]
    var currentPage: Int?             // manual entry only — no quick-add, no slider (decision #18)
    var readingGoal: ReadingGoal?      // set/edited from the Today hero card

    // Stage 1 (decisions #33/#37/#39.3-4): the detail page's "why this fits
    // you" verdict and (best-effort) Recognition section, cached so they're
    // generated at most once per book, not on every detail-view visit.
    // `cachedVerdict` is seeded for free from the original recommendation
    // reason when one exists (Today/Search-rows/Vibe Search), or from
    // `book-verdict.js` when it doesn't (e.g. Search's manual lookup).
    // `verdictCachedAtFinishedCount` is decision #33's invalidation key —
    // both fields are considered stale once the reader's finished-book count
    // (a cheap proxy for "taste profile changed") no longer matches.
    var cachedVerdict: String? = nil
    var cachedRecognition: String? = nil
    // Decision #40: the cleaned synopsis from the same book-verdict.js call,
    // replacing raw source text as the Synopsis section's content. Cached
    // and invalidated the same way as the other two fields.
    var cachedSynopsis: String? = nil
    var verdictCachedAtFinishedCount: Int? = nil
}

/// Target page + target date, set and edited from the Today hero card
/// (decision #18).
struct ReadingGoal: Codable, Equatable {
    var targetPage: Int
    var targetDate: Date
}

/// Shared progress math — originally private to `HeroReadingCard`,
/// pulled out here once the post-decision full-bleed hero (design brief,
/// decision #24 follow-up) needed the exact same calculations.
extension LibraryEntry {
    var progressFraction: Double? {
        guard let currentPage else { return nil }
        guard let denominator = readingGoal?.targetPage ?? book.pageCount,
              denominator > 0 else { return nil }
        return min(Double(currentPage) / Double(denominator), 1.0)
    }

    /// Calm, factual stats only — pages remaining and how long the reader's
    /// been on this book. No pace/timeline judgment ("on track" / "behind"
    /// against the goal's schedule) — this app doesn't comment on reading
    /// speed. The "Started N days ago" clause only appears alongside a goal;
    /// without one, pages remaining (or read so far) stands alone.
    var pageStatusText: String? {
        guard let currentPage else { return nil }
        let pagesPart: String
        if let total = readingGoal?.targetPage ?? book.pageCount, total > currentPage {
            pagesPart = "\(total - currentPage) pages left"
        } else {
            pagesPart = "\(currentPage) pages read so far"
        }
        guard readingGoal != nil, let startDate = dateStartedReading else { return pagesPart }
        let days = max(Int(Date.now.timeIntervalSince(startDate) / 86400), 0)
        let startedPart = days == 0 ? "Started today" : "Started \(days) day\(days == 1 ? "" : "s") ago"
        return "\(pagesPart) · \(startedPart)"
    }
}

/// One check-in per book, fixed 5 days after dateStartedReading. Yes/no only —
/// feeds the recommendation engine a signal before the reader even finishes.
struct MidpointCheckIn: Codable, Equatable {
    var askedOn: Date
    var stillEnjoying: Bool?    // nil until answered
}

struct Highlight: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var note: String?
    var dateCreated: Date
}

struct Recommendation: Identifiable, Codable, Equatable {
    var id: String { book.id }
    var book: Book
    var reason: String          // AI-generated "why this, why now"
    var confidence: Double      // 0-1, used for ordering only, never shown raw
    /// True when the backend's decision #8 scarcity fallback supplied this
    /// pick from the reader's own shown-books history rather than a fresh
    /// AI pick. CONFIRMED root cause of a real bug: `LibraryStore`'s
    /// defense-in-depth exclusion filter treats "already in shownBooks" as
    /// an absolute removal reason — which is exactly where a backfilled
    /// pick comes from by definition, so every backfilled recommendation
    /// was getting silently stripped back out client-side, collapsing rows
    /// that only met their floor via backfill. This flag lets that filter
    /// tell "the server intentionally resurfaced this" apart from "a model
    /// mistake slipped through," which is the case the filter actually
    /// exists to catch. Defaults false so older cached/server data (with no
    /// such field) decodes as "not backfilled," the historically-correct
    /// behavior.
    var backfilled: Bool = false

    enum CodingKeys: String, CodingKey { case book, reason, confidence, backfilled }
    init(book: Book, reason: String, confidence: Double, backfilled: Bool = false) {
        self.book = book
        self.reason = reason
        self.confidence = confidence
        self.backfilled = backfilled
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        book = try container.decode(Book.self, forKey: .book)
        reason = try container.decode(String.self, forKey: .reason)
        confidence = try container.decode(Double.self, forKey: .confidence)
        backfilled = try container.decodeIfPresent(Bool.self, forKey: .backfilled) ?? false
    }
}

/// Today's feed is organized into labeled, horizontally-scrolling rows rather
/// than one flat list (decision #19) — this is the shape `recommend.js` now
/// returns. `label` is specific and reader-facing ("Because you loved
/// Beloved"), never generic. `kind` distinguishes the one discovery row from
/// the taste-anchored ones so the UI can give it a different visual cue.
struct RecommendationRow: Identifiable, Codable, Equatable {
    var id: String { label }
    var label: String
    var kind: RowKind
    var recommendations: [Recommendation]
}

enum RowKind: String, Codable {
    case taste
    case discovery
}

/// One entry per book ever surfaced by `recommend.js` or `vibe-search.js`,
/// whether or not the reader added it — this list is deliberately separate from
/// the reader's actual shelves (see CLAUDE.md decision #8). `normalizedKey` is
/// how we catch the same physical book resurfacing under a different Google
/// Books / Open Library id (different edition, different source) — raw `id`
/// equality alone isn't reliable across the two metadata sources.
struct ShownBookRecord: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var author: String
    var normalizedKey: String

    init(id: String, title: String, author: String) {
        self.id = id
        self.title = title
        self.author = author
        self.normalizedKey = ShownBookRecord.normalize(title: title, author: author)
    }

    static func normalize(title: String, author: String) -> String {
        let combined = "\(title)|\(author)"
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        let filtered = combined.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == "|"
        }
        return String(String.UnicodeScalarView(filtered))
    }
}

/// Decision #26/#27: the binary choice on one of Today's daily picks.
/// "wantToRead" adds the book to the shelf (never auto-starts reading — that
/// stays a separate, deliberate action from My Shelf, decision #26).
/// "notInterested" is a real but moderate negative signal, weaker than
/// "shouldveStopped" on a finished book, tracked distinctly from shelf
/// placements since a dismissed book was never shelved at all.
enum DailyPickDecision: String, Codable {
    case wantToRead
    case notInterested
}

/// A book the reader explicitly dismissed from a Today daily pick (decision
/// #27) — structurally mirrors `ShownBookRecord` (same normalization, same
/// "different edition/source id" problem) but is a semantically different
/// signal: this is a moderate negative taste signal for future generations
/// to reason about, not just an exclusion record.
struct NotInterestedRecord: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var author: String
    var normalizedKey: String

    init(id: String, title: String, author: String) {
        self.id = id
        self.title = title
        self.author = author
        self.normalizedKey = ShownBookRecord.normalize(title: title, author: author)
    }
}
