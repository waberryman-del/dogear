import SwiftUI

/// Wired to the empty hero card's "Start reading" CTA (decision #17). Deliberately
/// thin — a quick picker, not a browsing experience. Picking a shelf book calls the
/// existing `startReading(_:)`; picking a recommendation calls `addToShelf(status:
/// .reading)`, since it isn't on the shelf yet. Neither method is new — this pass
/// only wires them to a UI entry point, it doesn't touch their behavior.
struct StartReadingSheet: View {
    @EnvironmentObject var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    private var wantToRead: [LibraryEntry] {
        library.entries.filter { $0.status == .wantToRead }
    }

    /// Flattened across rows and capped — this is a quick picker, not a full browse.
    private var recommendedBooks: [Recommendation] {
        Array(library.recommendationRows.flatMap { $0.recommendations }.prefix(10))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DogearSpacing.space6) {
                    if !wantToRead.isEmpty {
                        section(title: "FROM YOUR SHELF") {
                            ForEach(wantToRead) { entry in
                                pickerRow(book: entry.book) {
                                    library.startReading(entry.book.id)
                                    dismiss()
                                }
                            }
                        }
                    }
                    if !recommendedBooks.isEmpty {
                        section(title: "FROM TODAY'S PICKS") {
                            ForEach(recommendedBooks) { rec in
                                pickerRow(book: rec.book) {
                                    library.addToShelf(rec.book, status: .reading)
                                    dismiss()
                                }
                            }
                        }
                    }
                    if wantToRead.isEmpty && recommendedBooks.isEmpty {
                        Text("Add a book from Today or Find first.")
                            .font(DogearType.bodySmall)
                            .foregroundStyle(DogearColor.mutedInk)
                            .padding(.horizontal, DogearSpacing.space5)
                    }
                }
                .padding(.vertical, DogearSpacing.space6)
            }
            .background(DogearColor.paper)
            .navigationTitle("Start reading")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func section<Content: View>(
        title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space3) {
            Text(title)
                .font(DogearType.caption).tracking(1.5)
                .foregroundStyle(DogearColor.brass)
                .padding(.horizontal, DogearSpacing.space5)
            content()
        }
    }

    private func pickerRow(book: Book, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DogearSpacing.space3) {
                BookCoverView(url: book.coverURL, title: book.title, author: book.author, width: 44, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(DogearType.label)
                        .foregroundStyle(DogearColor.ink)
                    Text(book.author)
                        .font(DogearType.caption)
                        .foregroundStyle(DogearColor.mutedInk)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(DogearColor.forest)
            }
            .padding(.horizontal, DogearSpacing.space5)
            .padding(.vertical, DogearSpacing.space2)
        }
        .buttonStyle(DogearPressStyle())
    }
}
