import SwiftUI

/// A single reusable chip anatomy shared by onboarding genre picks and Vibe
/// Search's contextual one-tap refinements (Section 09/13). Selected state uses
/// Forest fill + Paper label; unselected uses a Linen surface with a hairline
/// Brass border, per Section 03/05.
struct DogearChip: View {
    let label: String
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DogearType.label)
                .foregroundStyle(isSelected ? DogearColor.paper : DogearColor.ink)
                .padding(.horizontal, DogearSpacing.space4)
                .padding(.vertical, DogearSpacing.space3)
                .frame(minHeight: 44)
                .background(isSelected ? DogearColor.forest : DogearColor.linen)
                .clipShape(RoundedRectangle(cornerRadius: DogearRadius.round))
                .overlay(
                    RoundedRectangle(cornerRadius: DogearRadius.round)
                        .stroke(DogearColor.brass.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
