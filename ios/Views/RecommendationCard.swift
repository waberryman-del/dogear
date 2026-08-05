import SwiftUI

/// Shared by Today's recommendation shelf and vibe search results — both are
/// just `Recommendation`s, sourced differently. Don't fork this per screen.
struct RecommendationCard: View {
    let rec: Recommendation
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BookCoverView(url: rec.book.coverURL, title: rec.book.title, width: 104, height: 150)
            Text(rec.book.title)
                .font(.caption.bold())
                .foregroundStyle(DogearColor.ink)
                .lineLimit(1)
            Text(rec.reason)
                .font(.caption2)
                .foregroundStyle(DogearColor.mutedInk)
                .lineLimit(2)
        }
        .frame(width: 104)
    }
}
