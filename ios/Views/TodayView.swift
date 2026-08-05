import SwiftUI

struct TodayView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var selectedRecommendation: Recommendation?
    @State private var showVibeSearch = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DogearSpacing.space6) {
                    header
                    vibeSearchEntry
                    sectionHeader("For you tonight")
                    content
                }
                .padding(.vertical, DogearSpacing.space6)
            }
            .background(DogearColor.paper)
            .toolbar(.hidden, for: .navigationBar)
            .task { await library.ringTheBell() }
            .navigationDestination(isPresented: $showVibeSearch) {
                VibeSearchView()
            }
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
                Task { await library.ringTheBell() }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DogearSpacing.space4) {
                    ForEach(library.recommendations) { rec in
                        RecommendationCard(rec: rec)
                            .onTapGesture { selectedRecommendation = rec }
                    }
                }
                .padding(.horizontal, DogearSpacing.space5)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DogearSpacing.space1) {
                Text("READERS PARADISE")
                    .font(DogearType.caption).tracking(2)
                    .foregroundStyle(DogearColor.brass)
                Text("Good evening").font(DogearType.titleItalic)
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

    /// Confirmed entry point: a prominent tappable row styled with
    /// VibePromptField, not a small icon buried in the header — navigates to
    /// VibeSearchView via a hidden nav destination since the field itself owns
    /// the tap target (nesting it inside a NavigationLink label would let the
    /// field's internal button eat the tap instead).
    private var vibeSearchEntry: some View {
        VibePromptField(
            placeholder: "What are you in the mood for?",
            mode: .staticPrompt(onTap: { showVibeSearch = true })
        )
        .padding(.horizontal, DogearSpacing.space5)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title).font(DogearType.title.italic())
            Spacer()
            Button {
                Task { await library.ringTheBell() }
            } label: {
                Image(systemName: "bell")
                    .foregroundStyle(DogearColor.brass)
                    .rotationEffect(.degrees(library.isRefreshingRecs ? -20 : 0))
                    .animation(
                        library.isRefreshingRecs
                            ? .easeInOut(duration: 0.4).repeatForever(autoreverses: true)
                            : .default,
                        value: library.isRefreshingRecs
                    )
            }
            .disabled(library.isRefreshingRecs)
        }
        .padding(.horizontal, DogearSpacing.space5)
    }
}
