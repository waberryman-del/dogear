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

            DogearButton(
                title: "Continue",
                loadingTitle: "Finding your first picks…",
                isLoading: isSubmitting,
                isDisabled: selected.isEmpty
            ) {
                let genres = selected
                isSubmitting = true
                Task {
                    await library.completeOnboarding(genres: genres)
                    isSubmitting = false
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(DogearColor.paper.ignoresSafeArea())
    }

    private func genreChip(_ genre: Genre) -> some View {
        let isSelected = selected.contains(genre)
        return DogearChip(label: genre.rawValue, isSelected: isSelected) {
            if isSelected {
                selected.remove(genre)
            } else if selected.count < maxSelectable {
                selected.insert(genre)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
