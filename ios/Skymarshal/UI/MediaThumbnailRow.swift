import SwiftUI
import SkymarshalCore

/// Inline media strip below a post's text. Up to 4 small thumbnails in a
/// row; if more, the last shows "+N". Tap-to-expand is a follow-on.
@available(iOS 17, *)
struct MediaThumbnailRow: View {
    let media: [MediaPreview]

    private let thumbSize: CGFloat = 64
    private let maxVisible = 4

    var body: some View {
        HStack(spacing: 6) {
            let visible = Array(media.prefix(maxVisible))
            ForEach(Array(visible.enumerated()), id: \.offset) { index, item in
                ThumbCell(
                    item: item,
                    overflowBadge: (index == maxVisible - 1 && media.count > maxVisible)
                        ? media.count - maxVisible : nil,
                    size: thumbSize
                )
            }
        }
    }
}

@available(iOS 17, *)
private struct ThumbCell: View {
    let item: MediaPreview
    let overflowBadge: Int?
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumb
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.tertiary, lineWidth: 0.5)
                }

            if item.kind == .video {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(.black.opacity(0.55), in: .circle)
                    .padding(4)
            }

            if let n = overflowBadge {
                Text("+\(n)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.black.opacity(0.7), in: .capsule)
                    .foregroundStyle(.white)
                    .padding(4)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var thumb: some View {
        if let url = item.thumbnailURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.tint.opacity(0.10))
            .overlay {
                Image(systemName: item.kind == .video ? "video" : "photo")
                    .foregroundStyle(.tint.opacity(0.6))
                    .font(.system(size: 18))
            }
    }

    private var accessibilityLabel: String {
        let kind = item.kind == .video ? "Video" : "Image"
        if let alt = item.alt, !alt.isEmpty { return "\(kind): \(alt)" }
        return "\(kind), no alt text"
    }
}
