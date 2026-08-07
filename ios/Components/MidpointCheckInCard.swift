import SwiftUI

/// Decision #5: exactly one check-in per book, 5 days after it's marked
/// "reading" — a single yes/no prompt, "still enjoying this one?" Shown on
/// Today (per `LibraryStore.dueMidpointCheckIns`, computed straight from
/// `entries`) whenever a check-in is due, whether the reader got here by
/// tapping the local notification or just opened the app normally after the
/// date passed — the notification is not the only path to this prompt.
struct MidpointCheckInCard: View {
    @EnvironmentObject var library: LibraryStore
    let entry: LibraryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space3) {
            HStack(alignment: .top, spacing: DogearSpacing.space4) {
                BookCoverView(
                    url: entry.book.coverURL, title: entry.book.title, author: entry.book.author,
                    width: 60, height: 88, displayMode: .aspectFit
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("MIDPOINT CHECK-IN")
                        .font(DogearType.caption).tracking(1.5)
                        .foregroundStyle(DogearColor.brass)
                    Text("Still enjoying \(entry.book.title)?")
                        .font(DogearType.rowLabelItalic)
                        .foregroundStyle(DogearColor.ink)
                }
                Spacer()
            }

            HStack(spacing: DogearSpacing.space3) {
                Button {
                    library.answerMidpointCheckIn(entry.book.id, stillEnjoying: true)
                } label: {
                    Text("Yes")
                        .font(DogearType.label)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DogearSpacing.space2)
                        .background(DogearColor.forest)
                        .foregroundStyle(DogearColor.paper)
                        .clipShape(Capsule())
                }
                .buttonStyle(DogearPressStyle())

                Button {
                    library.answerMidpointCheckIn(entry.book.id, stillEnjoying: false)
                } label: {
                    Text("No")
                        .font(DogearType.label)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DogearSpacing.space2)
                        .background(DogearColor.ink.opacity(0.06))
                        .foregroundStyle(DogearColor.mutedInk)
                        .clipShape(Capsule())
                }
                .buttonStyle(DogearPressStyle())
            }
        }
        .padding(DogearSpacing.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DogearColor.linen)
        .clipShape(RoundedRectangle(cornerRadius: DogearRadius.card))
        .padding(.horizontal, DogearSpacing.space5)
    }
}
