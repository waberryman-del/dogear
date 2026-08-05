import SwiftUI

/// Section 16 "States, errors, and trust": loading/failure chrome shared by
/// Today and Vibe Search rather than duplicated per screen.
struct LoadingStateView: View {
    var message: String

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: DogearSpacing.space3) {
                ProgressView()
                Text(message)
                    .font(DogearType.bodySmall)
                    .foregroundStyle(DogearColor.mutedInk)
            }
            Spacer()
        }
        .padding(.vertical, DogearSpacing.space10)
    }
}

/// Full-block failure state — used only when there's nothing on screen yet to
/// preserve. When prior results/recommendations exist, prefer a smaller inline
/// retry so the failure never blanks out what the reader already saw.
struct ErrorStateView: View {
    var message: String
    var retryTitle: String = "Retry"
    let action: () -> Void

    var body: some View {
        VStack(spacing: DogearSpacing.space3) {
            Text(message)
                .font(DogearType.bodySmall)
                .foregroundStyle(DogearColor.mutedInk)
                .multilineTextAlignment(.center)
            Button(retryTitle, action: action)
                .font(DogearType.label)
                .padding(.horizontal, DogearSpacing.space4)
                .padding(.vertical, DogearSpacing.space2)
                .background(DogearColor.forest)
                .foregroundStyle(DogearColor.paper)
                .clipShape(Capsule())
                .buttonStyle(DogearPressStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DogearSpacing.space8)
        .padding(.horizontal, DogearSpacing.space5)
    }
}

/// Compact inline banner for a failure that must NOT hide already-visible
/// results (e.g. a failed refinement tap) — Section 16: "Backend failure: Keep
/// query/current shelf and show retry."
struct InlineRetryBanner: View {
    var message: String
    let action: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(DogearType.caption)
                .foregroundStyle(DogearColor.rust)
            Spacer()
            Button("Retry", action: action)
                .font(DogearType.caption.weight(.semibold))
                .foregroundStyle(DogearColor.forest)
                .buttonStyle(DogearPressStyle())
        }
        .padding(.horizontal, DogearSpacing.space5)
    }
}
