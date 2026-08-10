import SwiftUI

/// Decision #28: "basic reading stats... plus app settings. Real content,
/// not a placeholder, but intentionally minimal." Both halves below are
/// computed only from data that genuinely already exists — no new activity
/// log was added to support this, so the stats are only as rich as
/// `LibraryEntry`/onboarding state actually allow.
struct ProfileView: View {
    @EnvironmentObject var library: LibraryStore
    // Decision #42(c): genres are editable here now, not locked forever
    // after onboarding — this sheet reuses the same chip-picker pattern
    // OnboardingView already established for the exact same choice.
    @State private var showingGenreEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DogearSpacing.space8) {
                    header
                    statsSection
                    settingsSection
                }
                .padding(.vertical, DogearSpacing.space6)
            }
            .background(DogearColor.paper)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingGenreEditor) {
                GenreEditSheet(initialSelection: library.onboardingGenres) { updated in
                    library.updateOnboardingGenres(updated)
                }
            }
        }
    }

    private var header: some View {
        Text("Profile")
            .font(DogearType.titleItalic)
            .foregroundStyle(DogearColor.ink)
            .padding(.horizontal, DogearSpacing.space5)
    }

    /// Decision #42(c): expanded beyond decision #28's original two tiles
    /// (finished count + streak) to also surface currently-reading and
    /// want-to-read counts — still computed only from data that already
    /// exists (`LibraryEntry.status`), no new activity log added.
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space3) {
            Text("READING STATS")
                .font(DogearType.caption).tracking(1.5)
                .foregroundStyle(DogearColor.brass)
                .padding(.horizontal, DogearSpacing.space5)
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: DogearSpacing.space3
            ) {
                statTile(value: "\(finishedCount)", label: finishedCount == 1 ? "book finished" : "books finished")
                statTile(value: "\(currentStreak)", label: currentStreak == 1 ? "day streak" : "day streak")
                statTile(value: "\(currentlyReadingCount)", label: "currently reading")
                statTile(value: "\(wantToReadCount)", label: "want to read")
            }
            .padding(.horizontal, DogearSpacing.space5)
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(DogearType.displayL)
                .foregroundStyle(DogearColor.ink)
            Text(label)
                .font(DogearType.caption)
                .foregroundStyle(DogearColor.mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DogearSpacing.space4)
        .background(DogearColor.linen)
        .clipShape(RoundedRectangle(cornerRadius: DogearRadius.card))
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space3) {
            Text("SETTINGS")
                .font(DogearType.caption).tracking(1.5)
                .foregroundStyle(DogearColor.brass)
                .padding(.horizontal, DogearSpacing.space5)
            VStack(alignment: .leading, spacing: DogearSpacing.space3) {
                HStack {
                    Text("Your name")
                        .font(DogearType.bodySmall)
                        .foregroundStyle(DogearColor.ink)
                    Spacer()
                    // Decision #29: plain text, no validation. Blank means
                    // Today's greeting falls back to the time-of-day phrase
                    // alone. Stopgap until real accounts exist — not to be
                    // confused with a login field.
                    TextField("Optional", text: readerNameBinding)
                        .font(DogearType.bodySmall)
                        .foregroundStyle(DogearColor.mutedInk)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                Divider()
                // Decision #42(c): editable now, not locked forever after
                // onboarding — tapping opens the same chip picker used at
                // onboarding, pre-filled with the current selection.
                Button {
                    showingGenreEditor = true
                } label: {
                    HStack {
                        Text("Onboarding genres")
                            .font(DogearType.bodySmall)
                            .foregroundStyle(DogearColor.ink)
                        Spacer()
                        Text(genresSummary)
                            .font(DogearType.bodySmall)
                            .foregroundStyle(DogearColor.mutedInk)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(DogearColor.mutedInk)
                    }
                }
                .buttonStyle(.plain)
                Divider()
                HStack {
                    Text("Version")
                        .font(DogearType.bodySmall)
                        .foregroundStyle(DogearColor.ink)
                    Spacer()
                    Text(appVersion)
                        .font(DogearType.bodySmall)
                        .foregroundStyle(DogearColor.mutedInk)
                }
            }
            .padding(DogearSpacing.space4)
            .background(DogearColor.linen)
            .clipShape(RoundedRectangle(cornerRadius: DogearRadius.card))
            .padding(.horizontal, DogearSpacing.space5)
        }
    }

    private var finishedCount: Int {
        library.entries.filter { $0.status == .finished }.count
    }

    private var currentlyReadingCount: Int {
        library.entries.filter { $0.status == .reading }.count
    }

    private var wantToReadCount: Int {
        library.entries.filter { $0.status == .wantToRead }.count
    }

    /// Consecutive local-calendar days (working backward from today) with
    /// at least one book finished. Today not having a finish yet doesn't
    /// zero out a streak still in progress from yesterday.
    private var currentStreak: Int {
        let calendar = Calendar.current
        let finishedDays = Set(library.entries.compactMap { entry -> Date? in
            guard let date = entry.dateFinished else { return nil }
            return calendar.startOfDay(for: date)
        })
        guard !finishedDays.isEmpty else { return 0 }

        var streak = 0
        var day = calendar.startOfDay(for: .now)
        if !finishedDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        while finishedDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    private var readerNameBinding: Binding<String> {
        Binding(
            get: { library.readerName },
            set: { library.setReaderName($0) }
        )
    }

    private var genresSummary: String {
        library.onboardingGenres.isEmpty
            ? "None selected"
            : library.onboardingGenres.map { $0.rawValue }.sorted().joined(separator: ", ")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}

/// Decision #42(c): reuses `OnboardingView`'s exact chip-picker pattern (same
/// max-5 rule, same `DogearChip` component) for editing genres after the
/// fact, rather than inventing a second picker UI for the same choice.
private struct GenreEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<Genre>
    let onSave: (Set<Genre>) -> Void

    private let maxSelectable = 5
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    init(initialSelection: Set<Genre>, onSave: @escaping (Set<Genre>) -> Void) {
        _selected = State(initialValue: initialSelection)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Pick up to \(maxSelectable) — we'll use these to shape your recommendations.")
                    .font(.subheadline)
                    .foregroundStyle(DogearColor.mutedInk)
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

                DogearButton(title: "Save", isDisabled: selected.isEmpty) {
                    onSave(selected)
                    dismiss()
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(DogearColor.paper.ignoresSafeArea())
            .navigationTitle("Your genres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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
