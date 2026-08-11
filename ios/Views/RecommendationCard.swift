import SwiftUI

/// Shared by Today's recommendation shelf and vibe search results — both are
/// just `Recommendation`s, sourced differently. Don't fork this per screen.
///
/// Phase 4 Stage 4 (decision #6): `onTap`/`onFold` are forwarded straight to
/// `BookCoverView`, which claims its own touches once either is set — the
/// title/reason `Text` below stay outside that view, so the ancestor
/// `Button` each caller wraps this in still handles taps on them normally.
struct RecommendationCard: View {
    let rec: Recommendation
    let onTap: () -> Void
    let onFold: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BookCoverView(
                url: rec.book.coverURL, title: rec.book.title, width: 104, height: 150,
                onTap: onTap, onFold: onFold
            )
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
