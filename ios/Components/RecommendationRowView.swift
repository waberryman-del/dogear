import SwiftUI

/// One labeled, horizontally-scrolling row of recommendations on Today
/// (decision #19) — replaces the old flat grid there. Find/Vibe Search keeps
/// `RecommendationGrid` for its one-shot results, since rows are specific to
/// Today's automatic, multi-pattern feed.
///
/// Not in Design System 0.1 (rows didn't exist yet): the discovery row gets a
/// small compass glyph in Brass ahead of its label — Brass already means
/// "emphasis" per Section 03, so this reuses that meaning to mark the one row
/// that's deliberately a stretch, rather than inventing a new accent.
struct RecommendationRowView: View {
    let row: RecommendationRow
    let onSelect: (Recommendation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space3) {
            label
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DogearSpacing.space4) {
                    ForEach(row.recommendations) { rec in
                        Button {
                            onSelect(rec)
                        } label: {
                            RecommendationCard(rec: rec)
                        }
                        .buttonStyle(DogearPressStyle())
                    }
                }
                .padding(.horizontal, DogearSpacing.space5)
            }
        }
    }

    private var label: some View {
        HStack(spacing: DogearSpacing.space2) {
            if row.kind == .discovery {
                Image(systemName: "safari")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DogearColor.brass)
            }
            Text(row.label)
                .font(DogearType.rowLabelItalic)
                .foregroundStyle(DogearColor.ink)
                .lineLimit(2)
        }
        .padding(.horizontal, DogearSpacing.space5)
    }
}
