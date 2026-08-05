import SwiftUI

struct TodayView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var selectedRecommendation: Recommendation?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    sectionHeader("For you tonight")

                    content
                }
                .padding(.vertical)
            }
            .background(Color("Linen"))
            .toolbar(.hidden, for: .navigationBar)
            .task { await library.ringTheBell() }
            .sheet(item: $selectedRecommendation) { rec in
                BookDetailView(recommendation: rec)
                    .environmentObject(library)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if library.isRefreshingRecs && library.recommendations.isEmpty {
            HStack {
                Spacer()
                ProgressView("Finding your next reads…")
                Spacer()
            }
            .padding(.vertical, 40)
        } else if library.recommendationsLoadFailed && library.recommendations.isEmpty {
            VStack(spacing: 12) {
                Text("Couldn't reach your library's brain.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Retry") { Task { await library.ringTheBell() } }
                    .font(.caption.bold())
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color("Forest"))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(library.recommendations) { rec in
                        RecommendationCard(rec: rec)
                            .onTapGesture { selectedRecommendation = rec }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("READERS PARADISE")
                .font(.caption).tracking(2)
                .foregroundStyle(Color("Brass"))
            Text("Good evening").font(.system(.title, design: .serif)).italic()
        }
        .padding(.horizontal)
    }

    /// The manual "ring the bell" refresh — a real, named UI element per CLAUDE.md
    /// decision #4, not a hidden pull-to-refresh gesture.
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title).font(.system(.title3, design: .serif)).italic()
            Spacer()
            Button {
                Task { await library.ringTheBell() }
            } label: {
                Image(systemName: "bell")
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
        .padding(.horizontal)
    }
}

private struct RecommendationCard: View {
    let rec: Recommendation
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color("Forest"))
                .frame(width: 104, height: 150)
                .overlay {
                    if let url = rec.book.coverURL {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                titleFallback
                            }
                        }
                    } else {
                        titleFallback
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(rec.book.title).font(.caption.bold()).lineLimit(1)
            Text(rec.reason).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(width: 104)
    }

    private var titleFallback: some View {
        Text(rec.book.title)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}
