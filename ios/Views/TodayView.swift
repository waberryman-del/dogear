import SwiftUI

/// Pure, automatically-updating recommendation feed (decision #4, amended) —
/// no manual refresh control and no Vibe Search entry point here anymore;
/// "Find" is its own tab now (decision #11, amended).
struct TodayView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var selectedRecommendation: Recommendation?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DogearSpacing.space6) {
                    header
                    sectionHeader("For you tonight")
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
        if library.isRefreshingRecs && library.recommendations.isEmpty {
            LoadingStateView(message: "Finding your next reads…")
        } else if library.recommendationsLoadFailed && library.recommendations.isEmpty {
            ErrorStateView(message: "Couldn't reach your library's brain.") {
                Task { await library.loadTodayFeedIfNeeded() }
            }
        } else {
            RecommendationGrid(recommendations: library.recommendations) { rec in
                selectedRecommendation = rec
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DogearType.title.italic())
            .foregroundStyle(DogearColor.ink)
            .padding(.horizontal, DogearSpacing.space5)
    }
}
