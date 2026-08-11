import SwiftUI

/// Shared full-width grid of recommendation cards — used by Today's automatic
/// feed and Find's on-demand results (previously a single horizontal scroll
/// row on Today; a real grid uses the screen width instead of hiding picks
/// off the edge). Cards are real Buttons, not a bare `.onTapGesture`, so every
/// card gets visible press feedback.
struct RecommendationGrid: View {
    let recommendations: [Recommendation]
    let onSelect: (Recommendation) -> Void
    /// Phase 4 Stage 4 (decision #6): fires when a card's fold gesture
    /// commits — the caller's save action (`addToShelf`), same as tapping
    /// into the detail sheet and using its "Want to read" button would do.
    let onFold: (Recommendation) -> Void

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: DogearSpacing.space4)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: DogearSpacing.space5) {
            ForEach(recommendations) { rec in
                Button {
                    onSelect(rec)
                } label: {
                    RecommendationCard(rec: rec, onTap: { onSelect(rec) }, onFold: { onFold(rec) })
                }
                .buttonStyle(DogearPressStyle())
            }
        }
        .padding(.horizontal, DogearSpacing.space5)
    }
}
