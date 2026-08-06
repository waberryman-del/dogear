import SwiftUI

/// Decision #28: "basic reading stats... plus app settings. Real content,
/// not a placeholder, but intentionally minimal." Both halves below are
/// computed only from data that genuinely already exists — no new activity
/// log was added to support this, so the stats are only as rich as
/// `LibraryEntry`/onboarding state actually allow.
struct ProfileView: View {
    @EnvironmentObject var library: LibraryStore

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
        }
    }

    private var header: some View {
        Text("Profile")
            .font(DogearType.titleItalic)
            .foregroundStyle(DogearColor.ink)
            .padding(.horizontal, DogearSpacing.space5)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space3) {
            Text("READING STATS")
                .font(DogearType.caption).tracking(1.5)
                .foregroundStyle(DogearColor.brass)
                .padding(.horizontal, DogearSpacing.space5)
            HStack(spacing: DogearSpacing.space3) {
                statTile(value: "\(finishedCount)", label: finishedCount == 1 ? "book finished" : "books finished")
                statTile(value: "\(currentStreak)", label: currentStreak == 1 ? "day streak" : "day streak")
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
                    Text("Onboarding genres")
                        .font(DogearType.bodySmall)
                        .foregroundStyle(DogearColor.ink)
                    Spacer()
                    Text(genresSummary)
                        .font(DogearType.bodySmall)
                        .foregroundStyle(DogearColor.mutedInk)
                        .multilineTextAlignment(.trailing)
                }
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

    private var genresSummary: String {
        library.onboardingGenres.isEmpty
            ? "None selected"
            : library.onboardingGenres.map { $0.rawValue }.sorted().joined(separator: ", ")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
