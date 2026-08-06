import SwiftUI

/// Design brief (decision #24 follow-up): once all 3 of Today's daily picks
/// are decided, the screen shouldn't collapse to the small floating
/// `HeroReadingCard` in otherwise-empty space — it becomes the main event
/// instead. Full-bleed (no horizontal padding, unlike every other element on
/// Today — that's what makes it read as a moment rather than another card),
/// cover art extended/blurred at the edges rather than harshly cropped,
/// progress and today's specific target front and center. Only shown when
/// there's an actual currently-reading book — TodayView falls back to the
/// existing compact `HeroReadingCard` (with its own empty-state invite)
/// otherwise, so this never has to render a "nothing in progress" version.
struct TodayHeroMoment: View {
    @EnvironmentObject var library: LibraryStore
    let entry: LibraryEntry
    @State private var showProgressSheet = false

    private let height: CGFloat = 560

    var body: some View {
        Button {
            showProgressSheet = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                backdrop
                scrim
                info
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .buttonStyle(DogearPressStyle())
        .sheet(isPresented: $showProgressSheet) {
            ReadingProgressSheet(entry: entry)
                .environmentObject(library)
        }
    }

    /// Blurred, extended cover fills the full width/height behind a smaller
    /// sharp copy of the same cover — the "softly blurred/extended at the
    /// edges, not harshly cropped" backdrop the brief asks for, same
    /// technique as a lock-screen-style now-playing background.
    private var backdrop: some View {
        ZStack {
            AsyncImage(url: entry.book.coverURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 36)
                        .overlay(DogearColor.ink.opacity(0.3))
                } else {
                    DogearColor.forest
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            AsyncImage(url: entry.book.coverURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: height * 0.62)
                        .clipShape(RoundedRectangle(cornerRadius: DogearRadius.card))
                        .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
                }
            }
        }
    }

    /// Bottom-weighted gradient so title/progress stay legible over
    /// whatever's in the cover art, without a flat scrim over the whole card.
    private var scrim: some View {
        LinearGradient(
            colors: [.clear, .clear, DogearColor.ink.opacity(0.55), DogearColor.ink.opacity(0.92)],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space2) {
            Text("CURRENTLY READING")
                .font(DogearType.caption).tracking(1.5)
                .foregroundStyle(DogearColor.brass)
            Text(entry.book.title)
                .font(DogearType.displayL).italic()
                .foregroundStyle(DogearColor.paper)
                .lineLimit(2)
            Text(entry.book.author)
                .font(DogearType.body)
                .foregroundStyle(DogearColor.paper.opacity(0.85))
            if let fraction = entry.progressFraction {
                progressBar(fraction: fraction)
                    .padding(.top, DogearSpacing.space2)
            }
            targetLine
        }
        .padding(DogearSpacing.space6)
    }

    private func progressBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DogearRadius.round)
                    .fill(DogearColor.paper.opacity(0.25))
                RoundedRectangle(cornerRadius: DogearRadius.round)
                    .fill(DogearColor.brass)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 6)
    }

    /// "Today's specific reading target front and center" — this is the one
    /// line the whole moment is built around, so it gets its own emphasis
    /// (semibold pace word) rather than blending into the caption above it.
    @ViewBuilder
    private var targetLine: some View {
        if let currentPage = entry.currentPage {
            HStack(spacing: DogearSpacing.space2) {
                if let total = entry.readingGoal?.targetPage ?? entry.book.pageCount {
                    Text("Page \(currentPage) of \(total)")
                }
                if let pace = entry.paceStatus {
                    Text("·")
                    Text(pace).fontWeight(.semibold)
                }
            }
            .font(DogearType.bodySmall)
            .foregroundStyle(DogearColor.paper.opacity(0.95))
        } else {
            Text("Tap to add your current page")
                .font(DogearType.bodySmall)
                .foregroundStyle(DogearColor.paper.opacity(0.8))
        }
    }
}
