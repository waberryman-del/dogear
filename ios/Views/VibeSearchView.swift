import SwiftUI
import UIKit

/// One of the 5 rotating prompt bubbles on Vibe Search (brand board design
/// brief) — universal and evocative, deliberately not personalized.
private struct VibePromptSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
}

/// Phase 2 spec: free text only, no genre dropdown alongside it — the text box IS
/// the whole interface. Reuses RecommendationCard + BookDetailView from Today
/// rather than a parallel UI system. A dedicated screen (not a bar bolted onto
/// Today) since CLAUDE.md calls this a first-class feature, not an experiment.
///
/// The query stays visible and editable the whole time (Design System Section 13:
/// "Keep the original query visible as an editable editorial quote"). Contextual
/// one-tap refinements appear only after results return and layer onto the
/// original query rather than replacing it (decision #14).
struct VibeSearchView: View {
    @EnvironmentObject var library: LibraryStore

    @State private var query = ""
    @State private var lastSearchedQuery = ""
    @State private var appliedRefinements: [String] = []
    @State private var suggestedRefinements: [String] = []
    @State private var results: [Recommendation] = []
    @State private var isSearching = false
    @State private var searchFailed = false
    @State private var hasSearched = false
    /// True when the backend actually returned matches but every one of them
    /// had already been shown before — distinct from a genuine zero-match
    /// search, which needs different, honest copy (see `content`).
    @State private var resultsExhaustedByExclusion = false
    @State private var selectedResult: Recommendation?
    @FocusState private var fieldFocused: Bool

    /// Decision #42(a), final spec: exactly 4 prompts shown at once (was 5
    /// per the original brand board brief, briefly 3 in an intermediate
    /// round). The underlying rotating pool below (still ~12 prompts, still
    /// a whole-set rotation not one-at-a-time) is unchanged. Deliberately
    /// universal/evocative and NOT derived from the reader's own data
    /// (unlike the AI-generated refinements below, which are), matching the
    /// board's own example tone.
    private static let promptPool: [VibePromptSuggestion] = [
        .init(text: "It just started raining.", icon: "cloud.rain"),
        .init(text: "I need hope.", icon: "sun.max"),
        .init(text: "I want to disappear into another world.", icon: "sparkles"),
        .init(text: "A book that feels like October.", icon: "leaf"),
        .init(text: "Give me something that hurts (in a good way).", icon: "heart"),
        .init(text: "Something ambitious, lonely, and beautiful.", icon: "moon.stars"),
        .init(text: "A slow Sunday kind of book.", icon: "cup.and.saucer"),
        .init(text: "I want to fall in love with someone on the page.", icon: "heart.circle"),
        .init(text: "Something that will keep me up too late.", icon: "flashlight.on.fill"),
        .init(text: "A book that feels like coming home.", icon: "house"),
        .init(text: "I need to laugh.", icon: "face.smiling"),
        .init(text: "Take me somewhere I've never been.", icon: "airplane"),
    ]
    private static let visiblePromptCount = 4
    @State private var visiblePrompts: [VibePromptSuggestion] =
        Array(VibeSearchView.promptPool.shuffled().prefix(VibeSearchView.visiblePromptCount))

    var body: some View {
        NavigationStack {
            // Decision #42(a): "What are you in the mood for?" must be the
            // literal topmost element — no nav-bar chrome above it. Same
            // hidden-nav-bar + in-content-header pattern already used by
            // Today and Profile.
            //
            // Decision #42(a), ROOT CAUSE FIX after 9 rounds: pinning the
            // field to the true bottom of the screen via `.safeAreaInset`
            // (correction #3 onward) structurally guaranteed a large void
            // whenever content above it didn't naturally reach that far —
            // an architecture problem no spacing value could fix. The field
            // is back in normal document flow now, directly after the last
            // bubble, separated by the one fixed 40pt gap `promptBubbles`
            // already carries as its own bottom padding — nothing extra
            // added here. Any genuine leftover space on a taller screen
            // falls below the field, past the last interactive element, not
            // wedged in the middle. `ScrollViewReader` is back too (removed
            // when the field was pinned and always on-screen) — `queryQuote`
            // needs it again to scroll back up to the now not-always-visible
            // field once results are showing.
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        if isEntryState {
                            promptBubbles
                        }
                        promptField
                            .padding(.horizontal, DogearSpacing.space5)
                            // Entry state: zero — the 40pt gap already comes
                            // from `promptBubbles`' own bottom padding right
                            // above. Results state (bubbles hidden): the
                            // field sits directly under the header, so it
                            // needs its own separation.
                            .padding(.top, isEntryState ? 0 : DogearSpacing.space6)
                            .id("promptField")
                        content(scrollProxy: scrollProxy)
                            .padding(.top, isEntryState ? 0 : DogearSpacing.space6)
                    }
                    .padding(.top, DogearSpacing.space5)
                    .padding(.bottom, isEntryState ? 0 : DogearSpacing.space6)
                }
            }
            .background(DogearColor.paper)
            .toolbar(.hidden, for: .navigationBar)
            // TIMING instrumentation for the reported keyboard-appear delay —
            // the rotating-timer-pause fix went in unverified last round.
            // Rather than guess again, this logs real timestamps for the
            // focus-state change and the two system keyboard notifications so
            // the actual gap (and which side of it — SwiftUI focus handling
            // vs. the system's own keyboard animation — is responsible) shows
            // up in the console next time this is reproduced on-device.
            .onChange(of: fieldFocused) { _, newValue in
                if newValue {
                    print("[VibeSearch][TIMING] fieldFocused=true at \(Self.timingTimestamp())")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                print("[VibeSearch][TIMING] keyboardWillShow at \(Self.timingTimestamp())")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                print("[VibeSearch][TIMING] keyboardDidShow at \(Self.timingTimestamp())")
            }
            .sheet(item: $selectedResult) { rec in
                BookDetailView(book: rec.book, reason: rec.reason)
                    .environmentObject(library)
            }
        }
    }

    /// Brand board: large serif headline alone, no small caption above it —
    /// and now, per decision #42(a), nothing but the safe area above it either.
    private var header: some View {
        Text("What are you in the mood for?")
            .font(DogearType.displayL).italic()
            .foregroundStyle(DogearColor.ink)
            .padding(.horizontal, DogearSpacing.space5)
    }

    private var promptField: some View {
        VibePromptField(mode: .editable(text: $query, isFocused: $fieldFocused, onSubmit: search))
    }

    /// True before any search has happened — the "What are you in the mood
    /// for?" + bubbles + field screen, as opposed to a results grid.
    private var isEntryState: Bool {
        !hasSearched && !isSearching
    }

    /// Decision #42(a), FINAL spec — every value here is literal and fixed,
    /// not a token, not a formula, not adaptive to screen size:
    /// - 32pt gap after the header (this view's own top padding)
    /// - 16pt gap between bubbles (this VStack's `spacing`)
    /// - 40pt gap before the field (this view's own bottom padding)
    /// Bubble internal padding (18pt) lives on `bubbleButton` below.
    private var promptBubbles: some View {
        VStack(spacing: 16) {
            ForEach(visiblePrompts) { prompt in
                bubbleButton(prompt)
            }
        }
        .padding(.horizontal, DogearSpacing.space5)
        .padding(.top, 32)
        .padding(.bottom, 40)
        .id(visiblePrompts.map(\.id))
        .transition(.opacity)
        .onReceive(Timer.publish(every: 8, on: .main, in: .common).autoconnect()) { _ in
            // Skip the rotation while the field is focused — an animated state
            // change landing in the same run-loop tick as the keyboard's
            // focus-in animation was competing with it and adding a visible
            // beat before the keyboard appeared.
            guard !fieldFocused else { return }
            withAnimation(DogearMotion.standard) {
                visiblePrompts = Array(Self.promptPool.shuffled().prefix(Self.visiblePromptCount))
            }
        }
    }

    /// Decision #42(a), FINAL spec: 18pt internal padding, literal — not
    /// the `DogearSpacing` scale (16pt/space4 and 20pt/space5 both miss it).
    private func bubbleButton(_ prompt: VibePromptSuggestion) -> some View {
        Button {
            query = prompt.text
            search()
        } label: {
            HStack(spacing: DogearSpacing.space3) {
                Image(systemName: prompt.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(DogearColor.brass)
                    .frame(width: 20)
                Text(prompt.text)
                    .font(DogearType.body)
                    .foregroundStyle(DogearColor.ink)
                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(DogearColor.linen)
            .clipShape(RoundedRectangle(cornerRadius: DogearRadius.control))
        }
        .buttonStyle(DogearPressStyle())
    }

    @ViewBuilder
    private func content(scrollProxy: ScrollViewProxy) -> some View {
        if isSearching && results.isEmpty {
            LoadingStateView(message: "Finding books for that vibe…")
        } else if searchFailed && results.isEmpty {
            ErrorStateView(message: "Couldn't reach your library's brain.", action: retry)
        } else if !results.isEmpty {
            VStack(alignment: .leading, spacing: DogearSpacing.space5) {
                queryQuote(scrollProxy: scrollProxy)
                if searchFailed {
                    InlineRetryBanner(message: "Couldn't apply that refinement.", action: retry)
                } else if isSearching {
                    // A refinement is in flight — old results/chips stay on
                    // screen (never blank out what the reader already saw),
                    // but without this there was zero feedback that the tap
                    // did anything until the whole round trip finished.
                    HStack(spacing: DogearSpacing.space2) {
                        ProgressView()
                        Text("Refining…")
                            .font(DogearType.caption)
                            .foregroundStyle(DogearColor.mutedInk)
                    }
                    .padding(.horizontal, DogearSpacing.space5)
                }
                if !appliedRefinements.isEmpty {
                    Text("Refined: \(appliedRefinements.joined(separator: ", "))")
                        .font(DogearType.caption)
                        .foregroundStyle(DogearColor.mutedInk)
                        .padding(.horizontal, DogearSpacing.space5)
                }
                resultsGrid
                if !suggestedRefinements.isEmpty {
                    refinementRow
                }
            }
        } else if hasSearched {
            Text(resultsExhaustedByExclusion
                ? "You've already discovered our best matches for this — try a different angle."
                : "Try describing the feeling rather than the plot.")
                .font(DogearType.bodySmall)
                .foregroundStyle(DogearColor.mutedInk)
                .padding(.horizontal, DogearSpacing.space5)
                .padding(.vertical, DogearSpacing.space8)
        }
    }

    /// Design System 0.1 Section 13: "Keep the original query visible as an
    /// editable editorial quote." Sits right above the results so a reader
    /// browsing a full grid doesn't have to scroll back to the top of the
    /// screen to refine or start over — tapping it scrolls back up to the
    /// real field and focuses it (decision: only one actual text box exists
    /// per #13, this is a shortcut back to it, not a second input). The
    /// scroll-back is needed again now that the field lives in normal
    /// document flow (root-cause fix, decision #42(a)) rather than being
    /// permanently pinned on-screen via `.safeAreaInset`.
    private func queryQuote(scrollProxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation(DogearMotion.standard) {
                scrollProxy.scrollTo("promptField", anchor: .top)
            }
            fieldFocused = true
        } label: {
            HStack(spacing: DogearSpacing.space3) {
                Text("“\(lastSearchedQuery)”")
                    .font(DogearType.bodySmall.italic())
                    .foregroundStyle(DogearColor.ink)
                    .lineLimit(2)
                Spacer()
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(DogearColor.brass)
            }
            .padding(.horizontal, DogearSpacing.space4)
            .padding(.vertical, DogearSpacing.space3)
            .background(DogearColor.linen)
            .clipShape(RoundedRectangle(cornerRadius: DogearRadius.control))
        }
        .buttonStyle(DogearPressStyle())
        .padding(.horizontal, DogearSpacing.space5)
    }

    private var resultsGrid: some View {
        RecommendationGrid(recommendations: results) { rec in
            selectedResult = rec
        }
    }

    private var refinementRow: some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space2) {
            Text("REFINE")
                .font(DogearType.caption).tracking(1.5)
                .foregroundStyle(DogearColor.brass)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DogearSpacing.space2) {
                    ForEach(suggestedRefinements, id: \.self) { label in
                        DogearChip(label: label) { applyRefinement(label) }
                    }
                }
                .padding(.horizontal, DogearSpacing.space5)
            }
        }
    }

    private var isQueryEmpty: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func search() {
        // Debounce: ignore a rapid re-tap of submit/a refinement chip while a
        // search is already in flight, rather than firing an overlapping
        // request (LibraryStore.vibeSearch() also guards against this
        // independently, but rejecting the tap here avoids even starting a
        // Task that would just fail).
        guard !isQueryEmpty, !isSearching else { return }
        fieldFocused = false
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // A genuinely new query starts a fresh refinement chain; re-submitting
        // the same text (e.g. after a failure) keeps whatever was already applied.
        if trimmed != lastSearchedQuery {
            appliedRefinements = []
        }
        lastSearchedQuery = trimmed
        performSearch()
    }

    private func applyRefinement(_ label: String) {
        guard !appliedRefinements.contains(label), !isSearching else { return }
        fieldFocused = false
        appliedRefinements.append(label)
        performSearch()
    }

    private func retry() {
        performSearch()
    }

    private func performSearch() {
        isSearching = true
        searchFailed = false
        Task {
            do {
                let result = try await library.vibeSearch(query: lastSearchedQuery, refinements: appliedRefinements)
                results = result.results
                suggestedRefinements = result.suggestedRefinements.filter { !appliedRefinements.contains($0) }
                resultsExhaustedByExclusion = result.results.isEmpty && result.rawResultCount > 0
                hasSearched = true
            } catch {
                print("[VibeSearchView] search failed: \(error)")
                searchFailed = true
                DogearHaptics.failure()
            }
            isSearching = false
        }
    }

    /// Monotonic (not wall-clock, so it's immune to NTP jumps) millisecond
    /// timestamp for the TIMING logs above — subtract two of these to get a
    /// real, reliable delta between the tap and the keyboard actually appearing.
    private static func timingTimestamp() -> String {
        String(format: "%.1fms", ProcessInfo.processInfo.systemUptime * 1000)
    }
}
