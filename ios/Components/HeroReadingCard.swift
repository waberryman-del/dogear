import SwiftUI

/// Today's home is now anchored by a "Currently Reading" hero (decision #17),
/// not just a flat recommendation feed. Two states: an in-progress book with
/// page progress and a pace indicator, or an empty invite that opens
/// `StartReadingSheet` rather than leaving blank space.
///
/// Not in Design System 0.1: the card uses `DogearRadius.card` on a Linen
/// surface, matching the recommendation-card language, and a thin Forest
/// progress bar. There's no documented hero-card anatomy yet — this
/// extrapolates from existing tokens rather than inventing new ones; flagging
/// for formalization into the design doc.
struct HeroReadingCard: View {
    @EnvironmentObject var library: LibraryStore
    @State private var showProgressSheet = false
    @State private var showStartSheet = false
    @State private var showSwitchOptions = false

    var body: some View {
        Group {
            if let entry = library.currentlyReadingEntry {
                readingCard(for: entry)
            } else {
                emptyCard
            }
        }
        .sheet(isPresented: $showProgressSheet) {
            if let entry = library.currentlyReadingEntry {
                ReadingProgressSheet(entry: entry)
                    .environmentObject(library)
            }
        }
        .sheet(isPresented: $showStartSheet) {
            StartReadingSheet()
                .environmentObject(library)
        }
        .confirmationDialog(
            "Change currently reading", isPresented: $showSwitchOptions, titleVisibility: .visible
        ) {
            if let entry = library.currentlyReadingEntry {
                Button("Read something else") {
                    library.stopReading(entry.book.id)
                    showStartSheet = true
                }
                Button("Stop reading this", role: .destructive) {
                    library.stopReading(entry.book.id)
                }
            }
        }
    }

    private func readingCard(for entry: LibraryEntry) -> some View {
        Button {
            showProgressSheet = true
        } label: {
            VStack(alignment: .leading, spacing: DogearSpacing.space3) {
                HStack(alignment: .top, spacing: DogearSpacing.space4) {
                    BookCoverView(
                        url: entry.book.coverURL, title: entry.book.title, author: entry.book.author,
                        width: 76, height: 110, displayMode: .aspectFit
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CURRENTLY READING")
                            .font(DogearType.caption).tracking(1.5)
                            .foregroundStyle(DogearColor.brass)
                        Text(entry.book.title)
                            .font(DogearType.rowLabelItalic)
                            .foregroundStyle(DogearColor.ink)
                        Text(entry.book.author)
                            .font(DogearType.bodySmall)
                            .foregroundStyle(DogearColor.mutedInk)
                        if let statusText = entry.pageStatusText {
                            Text(statusText)
                                .font(DogearType.caption)
                                .foregroundStyle(DogearColor.mutedInk)
                        }
                    }
                    Spacer()
                }
                if let fraction = entry.progressFraction {
                    progressBar(fraction: fraction)
                } else {
                    Text("Tap to add your current page")
                        .font(DogearType.caption)
                        .foregroundStyle(DogearColor.mutedInk)
                }
            }
            .padding(DogearSpacing.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DogearColor.linen)
            .clipShape(RoundedRectangle(cornerRadius: DogearRadius.card))
        }
        .buttonStyle(DogearPressStyle())
        .overlay(alignment: .topTrailing) {
            Button {
                showSwitchOptions = true
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(DogearColor.mutedInk)
                    .padding(DogearSpacing.space2)
            }
            .buttonStyle(DogearPressStyle())
            .padding(.trailing, DogearSpacing.space5 + DogearSpacing.space2)
            .padding(.top, DogearSpacing.space2)
        }
        .padding(.horizontal, DogearSpacing.space5)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space3) {
            Text("NOTHING IN PROGRESS")
                .font(DogearType.caption).tracking(1.5)
                .foregroundStyle(DogearColor.brass)
            Text("Start something from your shelf or today's picks.")
                .font(DogearType.rowLabelItalic)
                .foregroundStyle(DogearColor.ink)
            DogearButton(title: "Start reading") {
                showStartSheet = true
            }
        }
        .padding(DogearSpacing.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DogearColor.linen)
        .clipShape(RoundedRectangle(cornerRadius: DogearRadius.card))
        .padding(.horizontal, DogearSpacing.space5)
    }

    private func progressBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DogearRadius.round)
                    .fill(DogearColor.ink.opacity(0.08))
                RoundedRectangle(cornerRadius: DogearRadius.round)
                    .fill(DogearColor.forest)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 6)
    }

}
