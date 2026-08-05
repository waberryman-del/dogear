import SwiftUI

/// Phase 2 spec: free text only, no genre dropdown alongside it — the text box IS
/// the whole interface. Reuses RecommendationCard + BookDetailView from Today
/// rather than a parallel UI system. A dedicated screen (not a bar bolted onto
/// Today) since CLAUDE.md calls this a first-class feature, not an experiment.
struct VibeSearchView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var query = ""
    @State private var results: [Recommendation] = []
    @State private var isSearching = false
    @State private var searchFailed = false
    @State private var hasSearched = false
    @State private var selectedResult: Recommendation?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                searchField
                content
            }
            .padding(.vertical)
        }
        .background(Color("Linen"))
        .navigationTitle("Vibe search")
        .sheet(item: $selectedResult) { rec in
            BookDetailView(book: rec.book, reason: rec.reason)
                .environmentObject(library)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DESCRIBE THE READ")
                .font(.caption).tracking(2)
                .foregroundStyle(Color("Brass"))
            Text("What's the vibe?").font(.system(.title, design: .serif)).italic()
        }
        .padding(.horizontal)
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Atmospheric and slow, like a rainy Sunday…", text: $query, axis: .vertical)
                .lineLimit(1...4)
                .focused($fieldFocused)
                .submitLabel(.search)
                .onSubmit(search)
                .padding(12)
                .background(Color.white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color("Brass").opacity(0.3), lineWidth: 1)
                )

            Button {
                fieldFocused = false
                search()
            } label: {
                HStack {
                    if isSearching {
                        ProgressView().tint(.white)
                    }
                    Text(isSearching ? "Searching…" : "Find books")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isQueryEmpty ? Color.gray.opacity(0.4) : Color("Forest"))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isQueryEmpty || isSearching)
        }
        .padding(.horizontal)
    }

    private var isQueryEmpty: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var content: some View {
        if isSearching && results.isEmpty {
            HStack {
                Spacer()
                ProgressView("Finding books for that vibe…")
                Spacer()
            }
            .padding(.vertical, 40)
        } else if searchFailed && results.isEmpty {
            VStack(spacing: 12) {
                Text("Couldn't reach your library's brain.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Retry", action: search)
                    .font(.caption.bold())
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color("Forest"))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else if !results.isEmpty {
            resultsGrid
        } else if hasSearched {
            Text("No matches — try describing it differently.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 32)
        } else {
            Text("Try a mood, a mashup, a memory — not just a genre.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 32)
        }
    }

    private var resultsGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 104), spacing: 14)]
        return LazyVGrid(columns: columns, spacing: 20) {
            ForEach(results) { rec in
                RecommendationCard(rec: rec)
                    .onTapGesture { selectedResult = rec }
            }
        }
        .padding(.horizontal)
    }

    private func search() {
        guard !isQueryEmpty else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        isSearching = true
        searchFailed = false
        Task {
            do {
                results = try await library.vibeSearch(query: trimmed)
                hasSearched = true
            } catch {
                searchFailed = true
            }
            isSearching = false
        }
    }
}
