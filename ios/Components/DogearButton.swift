import SwiftUI

/// Dogear Design System 0.1, Section 10 press feedback ("Pressed: Scale 0.985 +
/// opacity 0.92, 100ms") generalized as a reusable style — every custom tappable
/// control in the app (chips, cards, retry buttons, the prompt field's arrow)
/// should use this instead of `.plain`, which gives no visual response at all.
struct DogearPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(DogearMotion.quick, value: configuration.isPressed)
    }
}

/// Dogear Design System 0.1, Section 08 "Primary button". `tint` defaults to
/// Forest but a caller can pass Rust for a destructive/undo action (e.g.
/// "Remove from shelf") per Section 03's rule that Rust is semantic, not
/// decorative.
struct DogearButtonStyle: ButtonStyle {
    var tint: Color = DogearColor.forest
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DogearType.label)
            .foregroundStyle(DogearColor.paper)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .padding(.horizontal, DogearSpacing.space5)
            .background(isDisabled ? tint.opacity(0.35) : tint)
            .clipShape(RoundedRectangle(cornerRadius: DogearRadius.control))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(DogearMotion.quick, value: configuration.isPressed)
    }
}

struct DogearButton: View {
    let title: String
    var loadingTitle: String? = nil
    var tint: Color = DogearColor.forest
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
        .buttonStyle(DogearButtonStyle(tint: tint, isDisabled: isDisabled || isLoading))
        .disabled(isDisabled || isLoading)
    }
}
