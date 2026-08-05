import SwiftUI

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
    @State private var selectedResult: Recommendation?
    @State private var exampleIndex = 0

    private let exampleQueries = [
        "It just started raining.",
        "A book that feels like October.",
        "Something ambitious, lonely, and beautiful.",
        "I want to disappear into another world."
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DogearSpacing.space6) {
                header
                promptField
                if !hasSearched && !isSearching {
                    examplePrompt
                }
                content
            }
            .padding(.vertical, DogearSpacing.space6)
        }
        .background(DogearColor.paper)
        .navigationTitle("Vibe search")
        .sheet(item: $selectedResult) { rec in
            BookDetailView(book: rec.book, reason: rec.reason)
                .environmentObject(library)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space1) {
            Text("DESCRIBE THE READ")
                .font(DogearType.caption).tracking(2)
                .foregroundStyle(DogearColor.brass)
            Text("What are you in the mood for?")
                .font(DogearType.titleItalic)
        }
        .padding(.horizontal, DogearSpacing.space5)
    }

    private var promptField: some View {
        VibePromptField(mode: .editable(text: $query, onSubmit: search))
            .padding(.horizontal, DogearSpacing.space5)
    }

    private var examplePrompt: some View {
        Button {
            query = exampleQueries[exampleIndex]
            search()
        } label: {
            HStack(spacing: DogearSpacing.space2) {
                Image(systemName: "sparkle")
                    .font(.caption2)
                    .foregroundStyle(DogearColor.brass)
                Text(exampleQueries[exampleIndex])
                    .font(DogearType.bodySmall.italic())
                    .foregroundStyle(DogearColor.mutedInk)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DogearSpacing.space5)
        .id(exampleIndex)
        .transition(.opacity)
        .onReceive(Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(DogearMotion.standard) {
                exampleIndex = (exampleIndex + 1) % exampleQueries.count
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isSearching && results.isEmpty {
            LoadingStateView(message: "Finding books for that vibe…")
        } else if searchFailed && results.isEmpty {
            ErrorStateView(message: "Couldn't reach your library's brain.", action: retry)
        } else if !results.isEmpty {
            VStack(alignment: .leading, spacing: DogearSpacing.space5) {
                if searchFailed {
                    InlineRetryBanner(message: "Couldn't apply that refinement.", action: retry)
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
            Text("Try describing the feeling rather than the plot.")
                .font(DogearType.bodySmall)
                .foregroundStyle(DogearColor.mutedInk)
                .padding(.horizontal, DogearSpacing.space5)
                .padding(.vertical, DogearSpacing.space8)
        }
    }

    private var resultsGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 104), spacing: DogearSpacing.space4)]
        return LazyVGrid(columns: columns, spacing: DogearSpacing.space5) {
            ForEach(results) { rec in
                RecommendationCard(rec: rec)
                    .onTapGesture { selectedResult = rec }
            }
        }
        .padding(.horizontal, DogearSpacing.space5)
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
        guard !isQueryEmpty else { return }
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
        guard !appliedRefinements.contains(label) else { return }
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
                hasSearched = true
            } catch {
                searchFailed = true
            }
            isSearching = false
        }
    }
}
