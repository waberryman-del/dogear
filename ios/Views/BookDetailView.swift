import SwiftUI

/// Basic detail sheet: cover, why-this reasoning, summary, and the add-to-shelf action.
/// No shelf placement / rating UI here — that only exists once a book is finished.
struct BookDetailView: View {
    @EnvironmentObject var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let recommendation: Recommendation
    @State private var didAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        cover
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recommendation.book.title)
                                .font(.system(.title2, design: .serif)).italic()
                            Text(recommendation.book.author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let pageCount = recommendation.book.pageCount {
                                Text("\(pageCount) pages")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("WHY THIS, WHY NOW")
                            .font(.caption).tracking(1.5)
                            .foregroundStyle(Color("Brass"))
                        Text(recommendation.reason)
                            .font(.body)
                    }

                    if let summary = recommendation.book.summary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SUMMARY")
                                .font(.caption).tracking(1.5)
                                .foregroundStyle(Color("Brass"))
                            Text(summary).font(.body)
                        }
                    }

                    Button {
                        library.addToShelf(recommendation.book)
                        didAdd = true
                    } label: {
                        Label(didAdd ? "Added to your library" : "Add to shelf",
                              systemImage: didAdd ? "checkmark" : "plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .background(didAdd ? Color.gray.opacity(0.3) : Color("Forest"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(didAdd)
                }
                .padding()
            }
            .background(Color("Linen"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var cover: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color("Forest"))
            .frame(width: 90, height: 130)
            .overlay {
                if let url = recommendation.book.coverURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
