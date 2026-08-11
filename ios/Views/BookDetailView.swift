import SwiftUI

/// Stage 1 (CLAUDE.md decisions #31, #36-39): the full book detail page,
/// section by section per decision #39 — identity, at-a-glance strip, the AI
/// verdict, Recognition, synopsis, then status-dependent actions. Every entry
/// point (Today, Search's rows/manual lookup, Vibe Search, My Shelf) opens
/// this same view; `reason` is only ever non-nil for the three that already
/// generated one as part of their normal response (decision #37).
struct BookDetailView: View {
    @EnvironmentObject var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let book: Book
    var reason: String? = nil

    @State private var verdict: String?
    @State private var recognition: String?
    // Decision #40: the cleaned synopsis comes from the same call as verdict/
    // recognition. Decision #41(a)/(b): recognition + synopsis are always
    // pending from that one call regardless of whether `reason` already gave
    // us a verdict, and must reveal together, once, when it resolves —
    // `isLoadingDetails` below gates both, and neither renders any interim
    // content (raw `book.summary` included) before then.
    @State private var synopsis: String?
    @State private var isLoadingVerdict: Bool
    @State private var isLoadingDetails = true
    @State private var showingProgressSheet = false
    @State private var showingPlacementPicker = false

    init(book: Book, reason: String? = nil) {
        self.book = book
        self.reason = reason
        // Decision #36: an existing reason IS the verdict, shown instantly —
        // no loading placeholder ever appears in that case. Only a book with
        // no prior reasoning (Search's manual lookup, or a shelved book whose
        // cache was never populated) starts in the loading state.
        _verdict = State(initialValue: reason)
        _isLoadingVerdict = State(initialValue: reason == nil)
    }

    private var entry: LibraryEntry? {
        library.entries.first { $0.book.id == book.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DogearSpacing.space6) {
                    identitySection
                    atAGlanceStrip
                    verdictSection
                    if let recognition, !recognition.isEmpty {
                        recognitionSection(recognition)
                    }
                    synopsisSection
                    actionsSection
                }
                .padding(DogearSpacing.space5)
            }
            .background(DogearColor.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task(id: book.id) {
            let result = await library.verdictAndRecognition(for: book, existingReason: reason)
            // Decision #41(a): assign all three together, in one pass, so the
            // view re-renders once with everything that just became available
            // — never a verdict-then-recognition-then-synopsis stagger.
            verdict = result.verdict
            recognition = result.recognition
            synopsis = result.synopsis
            isLoadingVerdict = false
            isLoadingDetails = false
        }
        .confirmationDialog(
            "Place on a shelf", isPresented: $showingPlacementPicker, titleVisibility: .visible
        ) {
            ForEach([ShelfPlacement.keepForever, .gladIReadIt, .shouldveStopped], id: \.self) { placement in
                Button(placementLabel(placement)) {
                    Task { await library.placeOnShelf(book.id, placement: placement) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingProgressSheet) {
            if let entry {
                ReadingProgressSheet(entry: entry)
            }
        }
    }

    // MARK: - 1. Identity (decision #39.1)

    private var identitySection: some View {
        HStack(alignment: .top, spacing: DogearSpacing.space4) {
            BookCoverView(
                url: book.coverURL, title: book.title, author: book.author,
                width: 100, height: 150, displayMode: .aspectFit
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(DogearType.title).italic()
                    .foregroundStyle(DogearColor.ink)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(DogearColor.mutedInk)
            }
            Spacer()
        }
    }

    // MARK: - 2. At-a-glance strip (decision #39.2)

    /// Renders identically in structure every time (decision #39's formatting
    /// principle) — a fixed left-to-right fact order, missing facts simply
    /// omitted rather than reordering what's left.
    private var atAGlanceStrip: some View {
        HStack(spacing: DogearSpacing.space4) {
            if let pageCount = book.pageCount {
                glanceFact("\(pageCount) pages")
            }
            if let year = book.publicationYear {
                glanceFact(String(year))
            }
            if let readingTime = estimatedReadingTime {
                glanceFact(readingTime)
            }
            if let firstGenre = book.genres.first {
                glanceFact(firstGenre)
            }
        }
    }

    private func glanceFact(_ text: String) -> some View {
        Text(text)
            .font(DogearType.caption)
            .foregroundStyle(DogearColor.ink)
            .padding(.horizontal, DogearSpacing.space3)
            .padding(.vertical, DogearSpacing.space2)
            .background(DogearColor.linen)
            .clipShape(RoundedRectangle(cornerRadius: DogearRadius.small))
    }

    /// Decision #39.2: "a real computed number — pages ÷ an assumed average
    /// reading pace." 1.5 minutes/page is a commonly-cited average adult
    /// reading pace (~300 words/page at ~200 words/minute) — not measured
    /// per-book, just a stated, consistent assumption.
    private var estimatedReadingTime: String? {
        guard let pageCount = book.pageCount, pageCount > 0 else { return nil }
        let totalMinutes = Int((Double(pageCount) * 1.5).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "~\(minutes) min read" }
        if minutes == 0 { return "~\(hours)h read" }
        return "~\(hours)h \(minutes)m read"
    }

    // MARK: - 3. The AI verdict (decision #33, placed per #39.3)

    private var verdictSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WHY THIS FITS YOU")
                .font(DogearType.caption).tracking(1.5)
                .foregroundStyle(DogearColor.brass)
            if let verdict {
                Text(verdict)
                    .font(DogearType.body)
                    .foregroundStyle(DogearColor.ink)
            } else if isLoadingVerdict {
                // Decision #36: small, contained — never holds up the rest
                // of the page, which has already rendered above and below it.
                HStack(spacing: DogearSpacing.space2) {
                    ProgressView()
                    Text("Thinking about why this fits you…")
                        .font(DogearType.bodySmall)
                        .foregroundStyle(DogearColor.mutedInk)
                }
            } else {
                Text("Couldn't reach your library's brain for this one.")
                    .font(DogearType.bodySmall)
                    .foregroundStyle(DogearColor.mutedInk)
            }
        }
    }

    // MARK: - 4. Recognition (decision #39.4, best-effort)

    /// Decision #41(c): render as a bulleted list once there's more than one
    /// distinct fact — split on sentence boundaries since the backend returns
    /// a single string (`recognition.js`'s response contract), not an array.
    /// A single fact stays as plain prose; splitting one sentence would just
    /// produce a lone, pointless bullet.
    private func recognitionFacts(_ recognition: String) -> [String] {
        recognition
            .split(separator: ".")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func recognitionSection(_ recognition: String) -> some View {
        let facts = recognitionFacts(recognition)
        return VStack(alignment: .leading, spacing: 6) {
            Text("RECOGNITION")
                .font(DogearType.caption).tracking(1.5)
                .foregroundStyle(DogearColor.brass)
            if facts.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(facts, id: \.self) { fact in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\u{2022}")
                                .foregroundStyle(DogearColor.brass)
                            Text(fact + ".")
                                .font(DogearType.body)
                                .foregroundStyle(DogearColor.ink)
                        }
                    }
                }
            } else {
                Text(recognition)
                    .font(DogearType.body)
                    .foregroundStyle(DogearColor.ink)
            }
        }
    }

    // MARK: - 5. Synopsis (decision #38 fallback, decision #40 cleanup)

    /// Decision #41(b): raw `book.summary` must never render as a stand-in
    /// for the cleaned synopsis while it's still generating — that's exactly
    /// the bait-and-switch real testing caught (a visible swap once the call
    /// resolves). While `isLoadingDetails` is true, `synopsisSection` shows a
    /// contained loading placeholder instead, same treatment as the verdict.
    /// Only once loading has genuinely finished does raw `book.summary`
    /// become a legitimate *permanent* fallback — for when the call failed
    /// outright and there's nothing cleaned to show — since at that point
    /// it's the final state, not something that's about to swap out from
    /// under the reader.
    private var synopsisText: String? {
        if let synopsis, !synopsis.isEmpty { return synopsis }
        if let summary = book.summary, !summary.isEmpty { return summary }
        return nil
    }

    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SYNOPSIS")
                .font(DogearType.caption).tracking(1.5)
                .foregroundStyle(DogearColor.brass)
            if isLoadingDetails {
                HStack(spacing: DogearSpacing.space2) {
                    ProgressView()
                    Text("Preparing a synopsis…")
                        .font(DogearType.bodySmall)
                        .foregroundStyle(DogearColor.mutedInk)
                }
            } else {
                Text(synopsisText ?? "No synopsis available for this edition.")
                    .font(DogearType.body)
                    .foregroundStyle(synopsisText != nil ? DogearColor.ink : DogearColor.mutedInk)
            }
        }
    }

    // MARK: - 6. Actions (decision #31, status-dependent)

    @ViewBuilder
    private var actionsSection: some View {
        if let entry {
            switch entry.status {
            case .wantToRead:
                DogearButton(title: "Start reading") {
                    library.startReading(book.id)
                }
            case .reading:
                VStack(spacing: DogearSpacing.space3) {
                    DogearButton(title: "Update progress") {
                        showingProgressSheet = true
                    }
                    // Not explicitly in decision #31's text, but reading →
                    // finished has no other entry point anywhere in the app
                    // today (placeOnShelf was previously unreachable from any
                    // UI) — this is the natural, necessary home for it per
                    // decision #31's "clear, unambiguous next actions for
                    // whatever state the book is in."
                    DogearButton(title: "Finished — place on a shelf", tint: DogearColor.brass) {
                        showingPlacementPicker = true
                    }
                }
            case .finished, .dnf:
                VStack(alignment: .leading, spacing: DogearSpacing.space3) {
                    if let placement = entry.shelfPlacement {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ON YOUR SHELF")
                                .font(DogearType.caption).tracking(1.5)
                                .foregroundStyle(DogearColor.brass)
                            Text(placementLabel(placement))
                                .font(DogearType.body)
                                .foregroundStyle(DogearColor.ink)
                        }
                    }
                    DogearButton(title: "Re-place on a shelf") {
                        showingPlacementPicker = true
                    }
                }
            }
        } else {
            DogearButton(title: "Want to read") {
                library.addToShelf(book, status: .wantToRead, reason: reason)
            }
        }
    }

    private func placementLabel(_ placement: ShelfPlacement) -> String {
        switch placement {
        case .keepForever: return "Keep forever"
        case .gladIReadIt: return "Glad I read it"
        case .shouldveStopped: return "Wasn't for me"
        }
    }
}
