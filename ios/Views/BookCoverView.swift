import SwiftUI

/// Shared cover art rendering: real image when available, otherwise a color
/// swatch with the title — the degrade-gracefully fallback used everywhere a
/// cover shows up (Today, detail sheet, My Shelf).
struct BookCoverView: View {
    let url: URL?
    let title: String
    var width: CGFloat
    var height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color("Forest"))
            .frame(width: width, height: height)
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            titleFallback
                        }
                    }
                } else {
                    titleFallback
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var titleFallback: some View {
        Text(title)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}
