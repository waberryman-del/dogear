import SwiftUI

/// Decision #43(a): one-time discoverability hint for the fold-to-save
/// gesture (decision #6, Phase 4 Stage 4) — the press-and-hold gesture has
/// no other visual affordance anywhere, so a first-time reader has no way
/// to discover it without this. Shown on Today, the first cover-bearing
/// screen after onboarding; dismissal (and the persisted "seen" flag) is
/// owned by the caller, not this view.
struct FoldHintBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DogearSpacing.space3) {
            Image(systemName: "hand.point.up.left")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DogearColor.brass)
                .padding(.top, 2)
            Text("Press and hold a cover to save it to your shelf.")
                .font(DogearType.bodySmall)
                .foregroundStyle(DogearColor.ink)
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DogearColor.mutedInk)
            }
            .buttonStyle(DogearPressStyle())
        }
        .padding(DogearSpacing.space4)
        .background(DogearColor.linen)
        .clipShape(RoundedRectangle(cornerRadius: DogearRadius.control))
        .padding(.horizontal, DogearSpacing.space5)
    }
}
