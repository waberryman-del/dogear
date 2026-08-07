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
/// #17) shows alongside undecided daily picks when both apply. Once all 3
/// are decided, the daily-picks section clears until tomorrow —
/// `library.allTodaysPicksDecided` drives that — and the hero card becomes
/// the main event instead, via `HeroReadingCard(isProminent:)`. [UPDATED —
/// the earlier full-bleed/blurred-cover `TodayHeroMoment` redesign for that
/// moment was scrapped: disliked in review, and had its own layout bugs
/// (cut-off text). Scaling up the same proven `HeroReadingCard` anatomy
/// replaces it — no new bespoke layout.]
struct TodayView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var selectedRecommendation: Recommendation?
    @State private var selectedShelfEntry: LibraryEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DogearSpacing.space8) {
                    header
                    // Once all 3 picks are decided, the hero card becomes the
                    // main event instead of a small card in otherwise-empty
                    // space — `isProminent` only visually matters when there's
                    // an actual currently-reading book; the empty-state invite
                    // (no book in progress) stays its normal compact size
                    // either way.
                    if library.allTodaysPicksDecided {
                        HeroReadingCard(isProminent: true)
                        upNextSection
                    } else {
                        HeroReadingCard()
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
            .sheet(item: $selectedShelfEntry) { entry in
                BookDetailView(book: entry.book)
                    .environmentObject(library)
            }
        }
    }

    /// Fills the space below the prominent hero once today's picks are all
    /// decided (decision #26/#27's daily-picks section clears then, and the
    /// old full-bleed redesign left that space empty) with a peek at what's
    /// already queued up — existing want-to-read entries, no new data or
    /// engine call. Reuses the same cover/title/author card language as
    /// `MyShelfView`'s shelf grid and `RecommendationRowView`'s cards; never
    /// truly blank, even with nothing queued.
    @ViewBuilder
    private var upNextSection: some View {
        let wantToRead = library.entries.filter { $0.status == .wantToRead }
        VStack(alignment: .leading, spacing: DogearSpacing.space3) {
            Text("UP NEXT")
                .font(DogearType.caption).tracking(1.5)
                .foregroundStyle(DogearColor.brass)
                .padding(.horizontal, DogearSpacing.space5)
            if wantToRead.isEmpty {
                // Nothing queued and today's picks are already spoken for —
                // send the reader to Search (its AI-personalized rows are
                // the general "find something to add" surface; Vibe Search
                // is for a specific mood query, a narrower ask than this
                // empty state calls for) rather than leaving flat text.
                VStack(alignment: .leading, spacing: DogearSpacing.space2) {
                    Text("Nothing queued up yet.")
                        .font(DogearType.bodySmall)
                        .foregroundStyle(DogearColor.mutedInk)
                    Button {
                        library.selectedTab = .search
                    } label: {
                        Text("Browse Search for something to read →")
                            .font(DogearType.bodySmall.weight(.semibold))
                            .foregroundStyle(DogearColor.forest)
                    }
                    .buttonStyle(DogearPressStyle())
                }
                .padding(.horizontal, DogearSpacing.space5)
            } else {
                HStack(spacing: DogearSpacing.space4) {
                    ForEach(wantToRead.prefix(3)) { entry in
                        Button {
                            selectedShelfEntry = entry
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                BookCoverView(url: entry.book.coverURL, title: entry.book.title, width: 88, height: 128)
                                Text(entry.book.title)
                                    .font(.caption.bold())
                                    .foregroundStyle(DogearColor.ink)
                                    .lineLimit(1)
                                Text(entry.book.author)
                                    .font(.caption2)
                                    .foregroundStyle(DogearColor.mutedInk)
                                    .lineLimit(1)
                            }
                            .frame(width: 88)
                        }
                        .buttonStyle(DogearPressStyle())
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DogearSpacing.space5)
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

    // Decision #12/#24: the old "My shelf" header link was a workaround from
    // when Shelf wasn't a real tab. It is now (RootTabView), so this link
    // was just a redundant second path to the same destination — removed.
    // Decision #29: the "DOGEAR" wordmark above the greeting is gone — the
    // tab bar already establishes app identity, so it was redundant here.
    // The greeting alone carries more visual weight now (`displayLItalic`)
    // to still read as the screen's anchor. [Refined] The name stacks on
    // its own line below the time-of-day phrase rather than sharing one
    // line with it — two short lines read calmer than one long one at this
    // size, and it avoids an ever-lengthening single line as names vary.
    private var header: some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space1) {
            Text(timeOfDayGreeting)
                .font(DogearType.displayLItalic)
                .foregroundStyle(DogearColor.ink)
            if !firstName.isEmpty {
                Text(firstName)
                    .font(DogearType.displayLItalic)
                    .foregroundStyle(DogearColor.ink)
            }
        }
        .padding(.horizontal, DogearSpacing.space5)
    }

    /// Morning/afternoon/evening based on the device clock.
    private var timeOfDayGreeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    /// Just the reader's first name, even if they typed a full name into
    /// Profile's free-text field (decision #29) — "Walker Berryman" greets
    /// as "Walker." Blank input means no second line at all.
    private var firstName: String {
        let trimmed = library.readerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
    }
}
