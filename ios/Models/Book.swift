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
