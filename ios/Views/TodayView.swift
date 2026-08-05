import SwiftUI

/// Phase 3 opening (decisions #17-20): anchored by a "Currently Reading" hero
/// card rather than a flat feed. Recommendations render as labeled,
/// horizontally-scrolling rows below it — each row carries its own specific
/// label now, so the old generic "For you tonight" section header is gone;
/// it would just be redundant noise above rows that already say why they're
/// there. No manual refresh control and no Vibe Search entry point here;
/// "Find" is its own tab (decision #11, amended).
struct TodayView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var selectedRecommendation: Recommendation?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DogearSpacing.space8) {
                    header
                    HeroReadingCard()
                    content
                }
                .padding(.vertical, DogearSpacing.space6)
            }
            .background(DogearColor.paper)
            .toolbar(.hidden, for: .navigationBar)
            .task { await library.loadTodayFeedIfNeeded() }
            .sheet(item: $selectedRecommendation) { rec in
                BookDetailView(book: rec.book, reason: rec.reason)
                    .environmentObject(library)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if library.isRefreshingRecs && library.recommendationRows.isEmpty {
            LoadingStateView(message: "Finding your next reads…")
        } else if library.recommendationsLoadFailed && library.recommendationRows.isEmpty {
            ErrorStateView(message: "Couldn't reach your library's brain.") {
                Task { await library.loadTodayFeedIfNeeded() }
            }
        } else if library.recommendationRows.isEmpty {
            // A completed, non-failed load that still came back empty — the
            // reader's profile is narrow enough (or heavily enough excluded
            // via shown-book history) that recommend.js genuinely had nothing
            // left to offer even after its own retry. Never leave this blank
            // (CLAUDE.md: "never a blank screen"); before the load has even
            // finished once, fall back to the loading state instead of
            // flashing this message prematurely.
            if library.hasAttemptedTodayLoad {
                exhaustedState
            } else {
                LoadingStateView(message: "Finding your next reads…")
            }
        } else {
            VStack(alignment: .leading, spacing: DogearSpacing.space6) {
                ForEach(library.recommendationRows) { row in
                    RecommendationRowView(row: row) { rec in
                        selectedRecommendation = rec
                    }
                }
            }
        }
    }

    private var exhaustedState: some View {
        Text("You've read deep into this pattern. Try Vibe Search for something different.")
            .font(DogearType.bodySmall)
            .foregroundStyle(DogearColor.mutedInk)
            .padding(.horizontal, DogearSpacing.space5)
            .padding(.vertical, DogearSpacing.space8)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DogearSpacing.space1) {
                Text("DOGEAR")
                    .font(DogearType.caption).tracking(2)
                    .foregroundStyle(DogearColor.brass)
                Text(greeting)
                    .font(DogearType.titleItalic)
                    .foregroundStyle(DogearColor.ink)
            }
            Spacer()
            NavigationLink {
                MyShelfView()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "books.vertical")
                    Text("My shelf").font(DogearType.caption)
                }
                .foregroundStyle(DogearColor.ink)
            }
        }
        .padding(.horizontal, DogearSpacing.space5)
    }

    /// Morning/afternoon/evening based on the device clock, not a fixed string.
    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}
