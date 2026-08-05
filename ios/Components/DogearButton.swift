import SwiftUI

/// Dogear Design System 0.1, Section 08 "Primary button".
struct DogearButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DogearType.label)
            .foregroundStyle(DogearColor.paper)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .padding(.horizontal, DogearSpacing.space5)
            .background(isDisabled ? DogearColor.forest.opacity(0.35) : DogearColor.forest)
            .clipShape(RoundedRectangle(cornerRadius: DogearRadius.control))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(DogearMotion.quick, value: configuration.isPressed)
    }
}

struct DogearButton: View {
    let title: String
    var loadingTitle: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DogearSpacing.space2) {
                if isLoading {
                    ProgressView().tint(DogearColor.paper)
                }
                Text(isLoading ? (loadingTitle ?? title) : title)
            }
        }
        .buttonStyle(DogearButtonStyle(isDisabled: isDisabled || isLoading))
        .disabled(isDisabled || isLoading)
    }
}
