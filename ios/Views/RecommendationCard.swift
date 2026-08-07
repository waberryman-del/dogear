import SwiftUI

/// Shared by Today's recommendation shelf and vibe search results — both are
/// just `Recommendation`s, sourced differently. Don't fork this per screen.
struct RecommendationCard: View {
    let rec: Recommendation
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BookCoverView(url: rec.book.coverURL, title: rec.book.title, width: 104, height: 150)
            // Same class of bug as BookCoverView's fallback text: an
            // unbounded title here (independent of whether the cover above
            // loaded or fell back) would just as easily grow this card
            // taller than its row neighbors for any long title.
            Text(rec.book.title)
                .font(.caption.bold())
                .foregroundStyle(DogearColor.ink)
                .lineLimit(2)
            Text(rec.reason)
                .font(.caption2)
                .foregroundStyle(DogearColor.mutedInk)
                .lineLimit(2)
        }
        .frame(width: 104)
    }
}
