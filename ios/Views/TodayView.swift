import SwiftUI

/// Decision #24 — Today stopped being a browsable row feed and became a
/// once-daily ritual: exactly 3 curated picks, generated once per local
/// calendar day, each getting a binary want-to-read/not-interested decision.
/// The old row-based browsing content (RecommendationRowView, pull-to-
/// refresh, the multi-row taxonomy) moved wholesale to the new Search tab
/// (decision #25) — see SearchView.swift. No manual refresh control here at
/// all now; the fixed daily cadence replaces it entirely.
///
/// Composition (decision #24): the hero "Currently Reading" card (decision
/// #17, unchanged) shows alongside undecided daily picks when both apply.
/// Once all 3 are decided, the daily-picks section clears until tomorrow —
/// `library.allTodaysPicksDecided` drives that.
struct TodayView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var selectedRecommendation: Recommendation?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DogearSpacing.space8) {
                    header
                    HeroReadingCard()
                    if !library.allTodaysPicksDecided {
                        dailyPicksSection
                    }
                }
                .padding(.vertical, DogearSpacing.space6)
            }
            .background(DogearColor.paper)
            .toolbar(.hidden, for: .navigationBar)
            .task { await library.loadTodaysPicksIfNeeded() }
            .sheet(item: $selectedRecommendation) { rec in
                BookDetailView(book: rec.book, reason: rec.reason)
                    .environmentObject(library)
            }
        }
    }

    @ViewBuilder
    private var dailyPicksSection: some View {
        if library.isLoadingTodaysPicks && library.todaysPicks.isEmpty {
            LoadingStateView(message: "Finding today's picks…")
        } else if library.todaysPicksLoadFailed && library.todaysPicks.isEmpty {
            ErrorStateView(message: "Couldn't reach your library's brain.") {
                Task { await library.loadTodaysPicksIfNeeded() }
            }
        } else if !library.todaysPicks.isEmpty {
            VStack(alignment: .leading, spacing: DogearSpacing.space4) {
                Text("TODAY'S PICKS")
                    .font(DogearType.caption).tracking(1.5)
                    .foregroundStyle(DogearColor.brass)
                    .padding(.horizontal, DogearSpacing.space5)
                VStack(spacing: DogearSpacing.space3) {
                    ForEach(library.todaysPicks) { rec in
                        DailyPickCard(
                            recommendation: rec,
                            decision: library.todaysPickDecisions[rec.book.id],
                            onSelect: { selectedRecommendation = rec },
                            onDecide: { decision in
                                library.decideTodaysPick(rec.book.id, decision: decision)
                            }
                        )
                    }
                }
                .padding(.horizontal, DogearSpacing.space5)
            }
        }
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
