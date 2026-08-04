import SwiftUI

struct TodayView: View {
    @EnvironmentObject var library: LibraryStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    sectionHeader("For you tonight") {
                        Task { await library.refreshRecommendations() }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(library.recommendations) { rec in
                                RecommendationCard(rec: rec)
                                    .onTapGesture { library.addToShelf(rec.book) }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color("Linen"))
            .navigationBarHidden(true)
            .task { await library.refreshRecommendations() }
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

    private func sectionHeader(_ title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.system(.title3, design: .serif)).italic()
            Spacer()
            Button("Refresh", action: action).font(.caption.bold())
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
                .overlay(
                    Text(rec.book.title)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(8),
                    alignment: .bottomLeading
                )
            Text(rec.book.title).font(.caption.bold()).lineLimit(1)
            Text(rec.reason).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(width: 104)
    }
}
