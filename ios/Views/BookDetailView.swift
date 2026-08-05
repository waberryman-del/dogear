import SwiftUI

/// Basic detail sheet: cover, why-this reasoning, summary, and the add-to-shelf action.
/// No shelf placement / rating UI here — that only exists once a book is finished.
/// Shared by Today (has a `reason` from the recommendation) and My Shelf (a book
/// already added, no reason to show — "on shelf" state is read live from the store
/// so it's correct either way this view got opened).
struct BookDetailView: View {
    @EnvironmentObject var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let book: Book
    var reason: String? = nil

    private var isOnShelf: Bool {
        library.entries.contains { $0.book.id == book.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        BookCoverView(url: book.coverURL, title: book.title, width: 90, height: 130)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.system(.title2, design: .serif)).italic()
                            Text(book.author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let pageCount = book.pageCount {
                                Text("\(pageCount) pages")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }

                    if let reason {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("WHY THIS, WHY NOW")
                                .font(.caption).tracking(1.5)
                                .foregroundStyle(Color("Brass"))
                            Text(reason)
                                .font(.body)
                        }
                    }

                    if let summary = book.summary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SUMMARY")
                                .font(.caption).tracking(1.5)
                                .foregroundStyle(Color("Brass"))
                            Text(summary).font(.body)
                        }
                    }

                    Button {
                        library.addToShelf(book)
                    } label: {
                        Label(isOnShelf ? "Added to your library" : "Add to shelf",
                              systemImage: isOnShelf ? "checkmark" : "plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .background(isOnShelf ? Color.gray.opacity(0.3) : Color("Forest"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(isOnShelf)
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
}
