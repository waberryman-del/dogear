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
/// is a static decorative cue only; the interactive fold-to-save gesture lives
/// elsewhere and is not implemented on this fallback.
struct BookCoverView: View {
    let url: URL?
    let title: String
    var author: String? = nil
    var width: CGFloat
    var height: CGFloat
    var displayMode: BookCoverDisplayMode = .crop

    var body: some View {
        RoundedRectangle(cornerRadius: DogearRadius.small)
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
