import SwiftUI

/// Opened by tapping the hero card (decision #18): manual current-page entry
/// (stepper + direct numeric field — no quick-add buttons, no slider) and the
/// target page + target date goal editor, together in one sheet since both
/// are "set/edited from the hero card."
struct ReadingProgressSheet: View {
    @EnvironmentObject var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let entry: LibraryEntry

    @State private var currentPageInput: Int
    @State private var targetPage: Int
    @State private var targetDate: Date
    @State private var goalEnabled: Bool

    init(entry: LibraryEntry) {
        self.entry = entry
        _currentPageInput = State(initialValue: entry.currentPage ?? 0)
        _targetPage = State(initialValue: entry.readingGoal?.targetPage ?? entry.book.pageCount ?? 0)
        _targetDate = State(initialValue: entry.readingGoal?.targetDate
            ?? Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now)
        _goalEnabled = State(initialValue: entry.readingGoal != nil)
    }

    private var pageCeiling: Int {
        entry.book.pageCount ?? 10000
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DogearSpacing.space6) {
                    header
                    currentPageSection
                    goalSection
                    DogearButton(title: "Save") {
                        save()
                    }
                    .padding(.horizontal, DogearSpacing.space5)
                }
                .padding(.vertical, DogearSpacing.space6)
            }
            .background(DogearColor.paper)
            .navigationTitle("Reading progress")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: DogearSpacing.space4) {
            BookCoverView(
                url: entry.book.coverURL, title: entry.book.title, author: entry.book.author,
                width: 60, height: 88, displayMode: .aspectFit
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.book.title)
                    .font(DogearType.rowLabelItalic)
                    .foregroundStyle(DogearColor.ink)
                    .lineLimit(2)
                Text(entry.book.author)
                    .font(DogearType.bodySmall)
                    .foregroundStyle(DogearColor.mutedInk)
            }
            Spacer()
        }
        .padding(.horizontal, DogearSpacing.space5)
    }

    private var currentPageSection: some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space2) {
            Text("CURRENT PAGE")
                .font(DogearType.caption).tracking(1.5)
                .foregroundStyle(DogearColor.brass)
            HStack(spacing: DogearSpacing.space4) {
                TextField("Page", value: $currentPageInput, format: .number)
                    .keyboardType(.numberPad)
                    .font(DogearType.body)
                    .foregroundStyle(DogearColor.ink)
                    .padding(.horizontal, DogearSpacing.space4)
                    .padding(.vertical, DogearSpacing.space3)
                    .background(DogearColor.linen)
                    .clipShape(RoundedRectangle(cornerRadius: DogearRadius.control))
                    .frame(width: 100)
                    // Free typing (e.g. 200 for a 140-page book) was previously
                    // accepted outright — clamp to the book's actual length as
                    // soon as it's entered rather than letting it persist.
                    .onChange(of: currentPageInput) { _, newValue in
                        currentPageInput = min(max(newValue, 0), pageCeiling)
                    }
                Stepper(value: $currentPageInput, in: 0...pageCeiling) {
                    EmptyView()
                }
                .labelsHidden()
                Spacer()
                if let total = entry.book.pageCount {
                    Text("of \(total)")
                        .font(DogearType.bodySmall)
                        .foregroundStyle(DogearColor.mutedInk)
                }
            }
        }
        .padding(.horizontal, DogearSpacing.space5)
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: DogearSpacing.space3) {
            HStack {
                Text("READING GOAL")
                    .font(DogearType.caption).tracking(1.5)
                    .foregroundStyle(DogearColor.brass)
                Spacer()
                if goalEnabled {
                    Button("Remove goal") {
                        goalEnabled = false
                    }
                    .font(DogearType.caption.weight(.semibold))
                    .foregroundStyle(DogearColor.rust)
                    .buttonStyle(DogearPressStyle())
                }
            }

            if goalEnabled {
                VStack(alignment: .leading, spacing: DogearSpacing.space3) {
                    HStack {
                        Text("Target page")
                            .font(DogearType.bodySmall)
                            .foregroundStyle(DogearColor.ink)
                        Spacer()
                        TextField("Page", value: $targetPage, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(DogearType.body)
                            .foregroundStyle(DogearColor.ink)
                            .frame(width: 80)
                    }
                    DatePicker(
                        "Target date", selection: $targetDate, in: Date.now...,
                        displayedComponents: .date
                    )
                    .font(DogearType.bodySmall)
                    .foregroundStyle(DogearColor.ink)
                    if let pace = pagesPerDayToStayOnTrack {
                        Text("\(pace) pages a day to stay on track")
                            .font(DogearType.caption)
                            .foregroundStyle(DogearColor.mutedInk)
                    }
                }
                .padding(DogearSpacing.space4)
                .background(DogearColor.linen)
                .clipShape(RoundedRectangle(cornerRadius: DogearRadius.control))
            } else {
                DogearButton(title: "Set a goal", tint: DogearColor.sage) {
                    goalEnabled = true
                }
            }
        }
        .padding(.horizontal, DogearSpacing.space5)
    }

    /// (target page − current page) ÷ days remaining until the target date,
    /// rounded up so the reader is never told less than what's actually
    /// needed. Reads live @State, so it updates as the sheet's own fields
    /// change, before anything is saved.
    private var pagesPerDayToStayOnTrack: Int? {
        let remainingPages = targetPage - currentPageInput
        guard remainingPages > 0 else { return 0 }
        let daysRemaining = max(targetDate.timeIntervalSinceNow / 86400, 1)
        return Int((Double(remainingPages) / daysRemaining).rounded(.up))
    }

    private func save() {
        library.updateCurrentPage(currentPageInput, for: entry.book.id)
        if goalEnabled {
            library.setReadingGoal(ReadingGoal(targetPage: targetPage, targetDate: targetDate), for: entry.book.id)
        } else {
            library.setReadingGoal(nil, for: entry.book.id)
        }
        dismiss()
    }
}
