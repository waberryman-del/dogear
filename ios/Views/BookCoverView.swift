import SwiftUI

/// How the cover image fills its frame. `.crop` fills the frame (cards, shelves,
/// grids); `.aspectFit` preserves the full cover ratio uncropped (detail screens),
/// per Design System Section 06: "Always preserve the actual cover ratio; use
/// aspectFit, not crop, on detail screens."
enum BookCoverDisplayMode {
    case crop
    case aspectFit
}

/// Shared cover art rendering: real image when available, otherwise a Linen
/// fallback field with serif title, sans author, and a small static folded
/// corner — the degrade-gracefully fallback used everywhere a cover shows up
/// (Today, detail sheet, My Shelf, Vibe Search results). The folded corner here
/// is a static decorative cue only, unrelated to and unaffected by `onFold`
/// below — it's top-trailing and purely decorative, while the real gesture's
/// fold is bottom-trailing per the brand board.
struct BookCoverView: View {
    let url: URL?
    let title: String
    var author: String? = nil
    var width: CGFloat
    var height: CGFloat
    var displayMode: BookCoverDisplayMode = .crop

    /// Phase 4 Stage 4 (decision #6): press-and-hold the bottom corner to
    /// save this book, additive alongside whatever explicit button(s) the
    /// screen already has — nil (default) disables the gesture entirely, so
    /// every call site that doesn't opt in (My Shelf's grids, Today's hero
    /// reading card) is completely unaffected. When set, this view claims
    /// its own touches (a plain `.gesture`, not `.simultaneousGesture`) so a
    /// quick tap on the cover specifically calls `onTap` itself rather than
    /// relying on an ancestor `Button` to also see that touch — callers that
    /// wrap this in a `Button` for surrounding text keep that Button working
    /// for taps on the text, since those touches never reach this view.
    var onTap: (() -> Void)? = nil
    var onFold: (() -> Void)? = nil

    @State private var foldProgress: CGFloat = 0
    @State private var isPressing = false
    @State private var didArm = false
    @State private var pressStartDate: Date?
    @State private var pressTask: Task<Void, Never>?

    /// How long a full hold takes to commit the fold/save.
    private static let holdDuration: TimeInterval = 0.5
    /// Fraction of `holdDuration` at which the "armed" haptic fires — partway
    /// through the hold, well before commit, so the reader feels the gesture
    /// is registering before it actually saves anything.
    private static let armThreshold: CGFloat = 0.35
    /// Below this, a press+release counts as a tap, not an aborted fold.
    private static let tapThreshold: TimeInterval = 0.15

    var body: some View {
        let cover = RoundedRectangle(cornerRadius: DogearRadius.small)
            .fill(DogearColor.linen)
            .frame(width: width, height: height)
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .aspectRatio(contentMode: displayMode == .crop ? .fill : .fit)
                        } else {
                            fallback
                        }
                    }
                } else {
                    fallback
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DogearRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DogearRadius.small)
                    .stroke(DogearColor.ink.opacity(0.08), lineWidth: 1)
            )

        Group {
            if onTap != nil || onFold != nil {
                cover
                    .overlay(alignment: .bottomTrailing) {
                        if onFold != nil {
                            foldCorner
                        }
                    }
                    .scaleEffect(isPressing ? 0.96 : 1)
                    .opacity(isPressing ? 0.85 : 1)
                    .animation(DogearMotion.quick, value: isPressing)
                    .contentShape(Rectangle())
                    .gesture(pressGesture)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(title)
                    .accessibilityAction { onTap?() }
                    .modifier(FoldAccessibilityAction(onFold: onFold))
            } else {
                cover
            }
        }
    }

    // MARK: - Fold gesture (decision #6)

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressing else { return }
                beginPress()
            }
            .onEnded { _ in
                // A very quick tap can sometimes reach SwiftUI as just this
                // `onEnded` with no preceding `onChanged` — without this
                // branch that would silently do nothing instead of opening
                // the detail sheet. Treat an unrecognized press as a
                // completed tap rather than assuming it was a hold.
                guard isPressing else {
                    onTap?()
                    return
                }
                endPress()
            }
    }

    private func beginPress() {
        isPressing = true
        didArm = false
        let start = Date()
        pressStartDate = start
        pressTask?.cancel()
        pressTask = Task { @MainActor in
            while isPressing, !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                let progress = onFold != nil ? min(elapsed / Self.holdDuration, 1.0) : 0
                withAnimation(DogearMotion.fold) { foldProgress = progress }
                if onFold != nil, !didArm, progress >= Self.armThreshold {
                    didArm = true
                    DogearHaptics.actionArmed()
                }
                if progress >= 1.0 {
                    commitFold()
                    return
                }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    /// Reached only by holding through the full duration while still
    /// pressed — fires the save action, then springs the corner back down
    /// after a brief settle. Per Walker's direction, the fold never stays
    /// down as a persistent "already saved" indicator — that's what the
    /// existing badges/status text on each screen already do; this is a
    /// gesture only, not a second state display.
    private func commitFold() {
        isPressing = false
        pressTask?.cancel()
        pressStartDate = nil
        DogearHaptics.actionCommitted()
        onFold?()
        withAnimation(DogearMotion.fold.delay(0.18)) { foldProgress = 0 }
    }

    /// Handles both a genuine tap (very short press) and an aborted fold
    /// (held past the tap threshold but released before commit) — the
    /// latter cancels silently, matching "release-early-cancels": no tap,
    /// no save, just the corner springing back.
    private func endPress() {
        guard isPressing else { return }
        isPressing = false
        pressTask?.cancel()
        let elapsed = pressStartDate.map { Date().timeIntervalSince($0) } ?? 0
        pressStartDate = nil
        guard foldProgress < 1.0 else { return }
        withAnimation(DogearMotion.standard) { foldProgress = 0 }
        if elapsed < Self.tapThreshold {
            onTap?()
        }
    }

    /// Bottom-trailing per the brand board's "Fold to add" panel — grows
    /// from the corner as `foldProgress` advances, a lighter "page" triangle
    /// with a crease line and soft shadow standing in for the board's
    /// photographic fold (2D approximation, not a literal 3D flap — SwiftUI
    /// vector drawing rather than needing another generated image asset,
    /// since this is a live, animated interaction, not a static background).
    private var foldCorner: some View {
        GeometryReader { geo in
            let maxSize = min(geo.size.width, geo.size.height) * 0.42
            let size = maxSize * foldProgress
            ZStack(alignment: .bottomTrailing) {
                creasePath(size: size, in: geo.size)
                    .fill(DogearColor.ink.opacity(0.18))
                    .blur(radius: 3)
                creasePath(size: size, in: geo.size)
                    .fill(DogearColor.paper)
                    .overlay(
                        foldEdge(size: size, in: geo.size)
                            .stroke(DogearColor.ink.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: DogearColor.ink.opacity(0.25), radius: 2, x: -1, y: -1)
            }
        }
        .allowsHitTesting(false)
    }

    private func creasePath(size: CGFloat, in containerSize: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: containerSize.width - size, y: containerSize.height))
            path.addLine(to: CGPoint(x: containerSize.width, y: containerSize.height - size))
            path.addLine(to: CGPoint(x: containerSize.width, y: containerSize.height))
            path.closeSubpath()
        }
    }

    private func foldEdge(size: CGFloat, in containerSize: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: containerSize.width - size, y: containerSize.height))
            path.addLine(to: CGPoint(x: containerSize.width, y: containerSize.height - size))
        }
    }

    /// CONFIRMED root cause of a real layout bug: an untruncated title here
    /// (e.g. a long box-set bundle name) could grow this view taller than
    /// the cover frame it's meant to fill, breaking row alignment against
    /// neighboring cards whose covers loaded normally. `lineLimit` plus an
    /// explicit `frame` (belt-and-suspenders alongside the fixed frame
    /// already set on the shape this overlays) guarantee this never renders
    /// larger than any other cover in the same row, loaded or not.
    private var fallback: some View {
        ZStack(alignment: .topTrailing) {
            DogearColor.linen
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(DogearColor.ink)
                    .lineLimit(3)
                if let author {
                    Text(author)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(DogearColor.mutedInk)
                        .lineLimit(1)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            staticFoldedCorner
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private var staticFoldedCorner: some View {
        GeometryReader { geo in
            let size = min(18, geo.size.width * 0.3)
            Path { path in
                path.move(to: CGPoint(x: geo.size.width - size, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width, y: size))
                path.closeSubpath()
            }
            .fill(DogearColor.brass.opacity(0.55))
        }
    }
}

/// Exposes the fold gesture as a named VoiceOver action ("Add to shelf")
/// alongside the default activate action — the gesture itself is a sighted/
/// touch fast path, never the only way to save a book (per decision #6's
/// accessibility framing), so VoiceOver users get an equivalent action
/// without needing to perform a timed press-and-hold.
private struct FoldAccessibilityAction: ViewModifier {
    let onFold: (() -> Void)?

    func body(content: Content) -> some View {
        if let onFold {
            content.accessibilityAction(named: Text("Add to shelf"), onFold)
        } else {
            content
        }
    }
}
