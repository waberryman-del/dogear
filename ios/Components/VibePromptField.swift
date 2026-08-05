import SwiftUI

/// Dogear Design System 0.1, Section 08 "Vibe prompt field".
///
/// Two modes:
/// - `.editable` is the live Vibe Search input (bound text, submit action).
/// - `.staticPrompt` renders identical chrome but is a plain tappable row with
///   no keyboard — used as Today's entry point into Vibe Search, per the
///   confirmed product decision that the entry point should be "a prominent
///   tappable row styled using VibePromptField that navigates to VibeSearchView."
struct VibePromptField: View {
    enum Mode {
        case editable(text: Binding<String>, onSubmit: () -> Void)
        case staticPrompt(onTap: () -> Void)
    }

    var placeholder: String = "What are you in the mood for?"
    var mode: Mode
    @FocusState private var isFocused: Bool

    var body: some View {
        switch mode {
        case .editable(let text, let onSubmit):
            editableField(text: text, onSubmit: onSubmit)
        case .staticPrompt(let onTap):
            staticField(onTap: onTap)
        }
    }

    private func editableField(text: Binding<String>, onSubmit: @escaping () -> Void) -> some View {
        let isEmpty = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(alignment: .bottom, spacing: DogearSpacing.space3) {
            TextField(placeholder, text: text, axis: .vertical)
                .font(DogearType.body)
                .lineLimit(1...5)
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit(onSubmit)

            submitArrow(action: onSubmit, disabled: isEmpty)
        }
        .padding(.horizontal, DogearSpacing.space4)
        .padding(.vertical, DogearSpacing.space3)
        .frame(minHeight: 56)
        .background(DogearColor.linen)
        .clipShape(RoundedRectangle(cornerRadius: DogearRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DogearRadius.control)
                .stroke(isFocused ? DogearColor.brass : DogearColor.ink.opacity(0.1),
                        lineWidth: isFocused ? 1.5 : 1)
        )
        .animation(DogearMotion.quick, value: isFocused)
    }

    private func staticField(onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: DogearSpacing.space3) {
                Text(placeholder)
                    .font(DogearType.body)
                    .foregroundStyle(DogearColor.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                submitArrow(action: onTap, disabled: false)
            }
            .padding(.horizontal, DogearSpacing.space4)
            .padding(.vertical, DogearSpacing.space3)
            .frame(minHeight: 56)
            .background(DogearColor.linen)
            .clipShape(RoundedRectangle(cornerRadius: DogearRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: DogearRadius.control)
                    .stroke(DogearColor.ink.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func submitArrow(action: @escaping () -> Void, disabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DogearColor.paper)
                .frame(width: 40, height: 40)
                .background(Circle().fill(DogearColor.forest))
        }
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }
}
