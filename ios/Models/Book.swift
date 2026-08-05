import Foundation

struct Book: Identifiable, Codable, Equatable {
    let id: String              // ISBN or Google Books volumeId
    var title: String
    var author: String
    var coverURL: URL?
    var pageCount: Int?
    var genres: [String]
    var summary: String?
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
}

/// Target page + target date, set and edited from the Today hero card
/// (decision #18). The pace indicator (on track / behind) is computed from
/// this plus `LibraryEntry.currentPage` and `dateStartedReading` — not stored,
/// since it changes with every day that passes even if nothing else does.
struct ReadingGoal: Codable, Equatable {
    var targetPage: Int
    var targetDate: Date
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
