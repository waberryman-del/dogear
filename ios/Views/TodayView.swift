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
    /// Distinct from `library.isRefreshingRecs`, which stays false for the
    /// silent background refresh `loadTodayFeedIfNeeded()` does on every
    /// appearance — this only tracks the explicit pull gesture, which is
    /// deliberately loud instead: a request the reader triggered on purpose,
    /// taking ~15-20s, needs a real "something is happening" state, not just
    /// the small native pull-spinner with no copy.
    @State private var isPullRefreshing = false
    /// Set only by a pull-triggered refresh that genuinely failed (including
    /// joining an in-flight fetch that then failed) — the silent background
    /// load stays silent by design, but a deliberate pull deserves real
    /// feedback instead of the banner just vanishing with nothing to show
    /// for it. Auto-clears on the next successful refresh.
    @State private var pullRefreshFailed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DogearSpacing.space8) {
                    header
                    if isPullRefreshing {
                        refreshingBanner
                    } else if pullRefreshFailed {
                        InlineRetryBanner(message: "Couldn't refresh — showing your last picks.") {
                            Task { await runPullRefresh() }
                        }
                    }
                    HeroReadingCard()
                    content
                }
                .padding(.vertical, DogearSpacing.space6)
            }
            .background(DogearColor.paper)
            .toolbar(.hidden, for: .navigationBar)
            .task { await library.loadTodayFeedIfNeeded() }
            .refreshable { await runPullRefresh() }
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

    /// `library.refreshTodayFromPull()` now genuinely joins an already-running
    /// fetch instead of silently no-opping when one is in flight (e.g. the
    /// automatic load `.task` kicks off on every appearance) — real evidence
    /// (live console capture, not assumption) showed the old shared-guard
    /// version returning near-instantly with no real fetch behind it,
    /// clearing the banner in well under a second while an unrelated,
    /// already-running load silently updated content later on its own.
    private func runPullRefresh() async {
        isPullRefreshing = true
        let succeeded = await library.refreshTodayFromPull()
        isPullRefreshing = false
        pullRefreshFailed = !succeeded
        if succeeded {
            DogearHaptics.success()
        } else {
            DogearHaptics.failure()
        }
    }

    private var refreshingBanner: some View {
        HStack(spacing: DogearSpacing.space2) {
            ProgressView()
            Text("Finding new books for you…")
                .font(DogearType.bodySmall)
                .foregroundStyle(DogearColor.mutedInk)
        }
        .padding(.horizontal, DogearSpacing.space5)
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
