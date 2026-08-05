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
                    HStack(alignment: .top, spacing: DogearSpacing.space4) {
                        BookCoverView(
                            url: book.coverURL, title: book.title, author: book.author,
                            width: 90, height: 130, displayMode: .aspectFit
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(DogearType.title).italic()
                            Text(book.author)
                                .font(.subheadline)
                                .foregroundStyle(DogearColor.mutedInk)
                            if let pageCount = book.pageCount {
                                Text("\(pageCount) pages")
                                    .font(DogearType.caption)
                                    .foregroundStyle(DogearColor.mutedInk)
                            }
                        }
                        Spacer()
                    }

                    if let reason {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("WHY THIS, WHY NOW")
                                .font(DogearType.caption).tracking(1.5)
                                .foregroundStyle(DogearColor.brass)
                            Text(reason)
                                .font(DogearType.body)
                        }
                    }

                    if let summary = book.summary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SUMMARY")
                                .font(DogearType.caption).tracking(1.5)
                                .foregroundStyle(DogearColor.brass)
                            Text(summary).font(DogearType.body)
                        }
                    }

                    DogearButton(
                        title: isOnShelf ? "Added to your library" : "Add to shelf",
                        isDisabled: isOnShelf
                    ) {
                        library.addToShelf(book)
                    }
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
    }
}
