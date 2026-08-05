import SwiftUI

/// First-launch only (see CLAUDE.md decision #1): pick up to 5 genres, no book
/// search, no taste quiz. This alone seeds the first batch of recommendations.
struct OnboardingView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var selected: Set<Genre> = []
    @State private var isSubmitting = false

    private let maxSelectable = 5
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What do you read?")
                    .font(.system(.largeTitle, design: .serif)).italic()
                Text("Pick up to \(maxSelectable) — we'll use these to find your first recommendations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Genre.allCases) { genre in
                        genreChip(genre)
                    }
                }
                .padding(.horizontal)
            }

            Button {
                let genres = selected
                isSubmitting = true
                Task {
                    await library.completeOnboarding(genres: genres)
                    isSubmitting = false
                }
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    }
                    Text(isSubmitting ? "Finding your first picks…" : "Continue")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selected.isEmpty ? Color.gray.opacity(0.4) : Color("Forest"))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(selected.isEmpty || isSubmitting)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color("Linen").ignoresSafeArea())
    }

    private func genreChip(_ genre: Genre) -> some View {
        let isSelected = selected.contains(genre)
        return Text(genre.rawValue)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color("Forest") : Color.white.opacity(0.6))
            .foregroundStyle(isSelected ? .white : Color("Ink"))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color("Brass").opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
            .onTapGesture {
                if isSelected {
                    selected.remove(genre)
                } else if selected.count < maxSelectable {
                    selected.insert(genre)
                }
            }
    }
}
