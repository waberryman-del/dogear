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
        /// `isFocused` is owned by the caller so it can dismiss the keyboard
        /// itself (e.g. on submit) rather than reaching into this view's state.
        case editable(text: Binding<String>, isFocused: FocusState<Bool>.Binding, onSubmit: () -> Void)
        case staticPrompt(onTap: () -> Void)
    }

    var placeholder: String = "What are you in the mood for?"
    var mode: Mode
    /// Drives a visible pulse on the submit arrow. Needs to be state on this
    /// view (not just a press-style effect on the arrow's own Button) because
    /// submitting via the keyboard's return/search key — the more common path
    /// once the field is focused — never touches the arrow's Button at all,
    /// so a haptic alone there was invisible on that path.
    @State private var arrowPulsing = false

    var body: some View {
        switch mode {
        case .editable(let text, let isFocused, let onSubmit):
            editableField(text: text, isFocused: isFocused, onSubmit: onSubmit)
        case .staticPrompt(let onTap):
            staticField(onTap: onTap)
        }
    }

    private func editableField(
        text: Binding<String>, isFocused: FocusState<Bool>.Binding, onSubmit: @escaping () -> Void
    ) -> some View {
        let isEmpty = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(alignment: .bottom, spacing: DogearSpacing.space3) {
            TextField(placeholder, text: text, axis: .vertical)
                .font(DogearType.body)
                .foregroundStyle(DogearColor.ink)
                // This alone now does 100% of the height work — collapsed
                // (empty/short) sizes to 1 line, grows up to 5 lines with
                // typed content, with no competing `.frame` fighting it (see
                // the note below on why one was removed).
                .lineLimit(1...5)
                .focused(isFocused)
                .submitLabel(.search)
                .onSubmit { triggerSubmit(onSubmit) }
                // CONFIRMED (Apple dev forums + documented SwiftUI behavior):
                // `.onSubmit` does not fire for `TextField(axis: .vertical)` —
                // the return/search key inserts a newline into the bound text
                // instead, regardless of `submitLabel`. This is why keyboard
                // submit did nothing: `.onSubmit` above has never actually
                // been reachable for this field. Detecting the inserted
                // newline and stripping it is the standard workaround.
                .onChange(of: text.wrappedValue) { _, newValue in
                    if newValue.hasSuffix("\n") {
                        text.wrappedValue = String(newValue.dropLast())
                        triggerSubmit(onSubmit)
                    }
                }

            submitArrow(action: { triggerSubmit(onSubmit) }, disabled: isEmpty)
        }
        // Decision #42(a), correction #4: a single short placeholder line
        // looked lost inside this box — tightened from space4/space3
        // (16/12pt) to space3/space2 (12/8pt) so the box reads proportionate
        // to what's actually inside it at rest. The 40pt submit arrow (not
        // this padding) is what sets the real height floor, so this now
        // collapses to ~56pt — exactly the Design System's original
        // "minimum height 56pt collapsed" target.
        .padding(.horizontal, DogearSpacing.space3)
        .padding(.vertical, DogearSpacing.space2)
        // Decision #42(a), round 3 — CONFIRMED via real-build A/B testing on
        // a simulator (measured pixel height at each step, not guessed):
        // round 1 added `.frame(minHeight: 56, maxHeight: 120)` but left
        // `.fixedSize(vertical: true)` in place → still oversized (~107pt
        // empty). Round 2's theory ("fixedSize is fighting the frame") was
        // WRONG: removing fixedSize while keeping this same `.frame` made it
        // *worse*, not better (~117pt empty, nearly the max, confirmed by
        // screenshot measurement). The real mechanism: proposing a flexible
        // [56,120] height range to a `TextField(axis: .vertical)` makes it
        // expand toward the top of that range regardless of actual content —
        // it does not "size to content, then get clamped." The fix that
        // actually measured correctly (~65pt collapsed, confirmed) is to
        // give this field NO explicit height frame at all: let `lineLimit`
        // below and the 40pt submit arrow's natural height do 100% of the
        // sizing. Do not reintroduce a `.frame(minHeight:/maxHeight:)` here
        // without re-measuring on a real build first — it's the thing that
        // broke this twice.
        .background(DogearColor.linen)
        .clipShape(RoundedRectangle(cornerRadius: DogearRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DogearRadius.control)
                .stroke(isFocused.wrappedValue ? DogearColor.brass : DogearColor.ink.opacity(0.1),
                        lineWidth: isFocused.wrappedValue ? 1.5 : 1)
        )
        .animation(DogearMotion.quick, value: isFocused.wrappedValue)
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
        .buttonStyle(DogearPressStyle())
    }

    /// Fires the haptic and a visible arrow pulse regardless of which path
    /// triggered submission (direct tap or keyboard return), then calls
    /// through to the real submit action.
    private func triggerSubmit(_ onSubmit: @escaping () -> Void) {
        DogearHaptics.actionArmed()
        withAnimation(DogearMotion.quick) { arrowPulsing = true }
        withAnimation(DogearMotion.quick.delay(0.08)) { arrowPulsing = false }
        onSubmit()
    }

    private func submitArrow(action: @escaping () -> Void, disabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DogearColor.paper)
                .frame(width: 40, height: 40)
                .background(Circle().fill(DogearColor.forest))
                .scaleEffect(arrowPulsing ? 0.8 : 1)
                .opacity(arrowPulsing ? 0.7 : 1)
        }
        .buttonStyle(DogearPressStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }
}
