import SwiftUI

/// One of Today's 3 daily picks (decision #24) — a plain cover+title+reason
/// layout plus the two-button want-to-read/not-interested decision row
/// (decisions #26/#27). Once decided, shows what was decided instead of the
/// buttons rather than disappearing — decision #24 clears the whole
/// daily-picks section only once ALL 3 are decided, not per-card.
struct DailyPickCard: View {
    let recommendation: Recommendation
    let decision: DailyPickDecision?
    let onSelect: () -> Void
    let onDecide: (DailyPickDecision) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space3) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: DogearSpacing.space4) {
                    BookCoverView(
                        url: recommendation.book.coverURL, title: recommendation.book.title,
                        author: recommendation.book.author, width: 72, height: 104, displayMode: .aspectFit
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.book.title)
                            .font(DogearType.rowLabelItalic)
                            .foregroundStyle(DogearColor.ink)
                        Text(recommendation.book.author)
                            .font(DogearType.bodySmall)
                            .foregroundStyle(DogearColor.mutedInk)
                        Text(recommendation.reason)
                            .font(DogearType.bodySmall)
                            .foregroundStyle(DogearColor.ink)
                            .padding(.top, 2)
                    }
                    Spacer()
                }
            }
            .buttonStyle(DogearPressStyle())

            if let decision {
                decidedBadge(for: decision)
            } else {
                decisionButtons
            }
        }
        .padding(DogearSpacing.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DogearColor.linen)
        .clipShape(RoundedRectangle(cornerRadius: DogearRadius.card))
    }

    private var decisionButtons: some View {
        HStack(spacing: DogearSpacing.space3) {
            Button {
                onDecide(.wantToRead)
            } label: {
                Text("Want to read")
                    .font(DogearType.label)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DogearSpacing.space2)
                    .background(DogearColor.forest)
                    .foregroundStyle(DogearColor.paper)
                    .clipShape(Capsule())
            }
            .buttonStyle(DogearPressStyle())

            Button {
                onDecide(.notInterested)
            } label: {
                Text("Not interested")
                    .font(DogearType.label)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DogearSpacing.space2)
                    .background(DogearColor.ink.opacity(0.06))
                    .foregroundStyle(DogearColor.mutedInk)
                    .clipShape(Capsule())
            }
            .buttonStyle(DogearPressStyle())
        }
    }

    private func decidedBadge(for decision: DailyPickDecision) -> some View {
        HStack(spacing: DogearSpacing.space2) {
            Image(systemName: decision == .wantToRead ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(decision == .wantToRead ? DogearColor.forest : DogearColor.mutedInk)
            Text(decision == .wantToRead ? "Added to your shelf" : "Not for you")
                .font(DogearType.caption)
                .foregroundStyle(DogearColor.mutedInk)
        }
    }
}
