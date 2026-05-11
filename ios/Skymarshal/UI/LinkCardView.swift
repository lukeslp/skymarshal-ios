import SwiftUI
import SkymarshalCore

/// Inline external link card for `app.bsky.embed.external` embeds.
/// Tapping anywhere on the card opens the URL in Safari. Hosts the
/// destination's title, description, and thumbnail in the same
/// horizontal-card shape Bluesky's own apps use.
@available(iOS 17, *)
struct LinkCardView: View {
    let card: LinkCard
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(card.url)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                if let thumb = card.thumbnailURL {
                    AsyncImage(url: thumb) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            placeholder
                        }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    placeholder
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let title = card.title, !title.isEmpty {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    if let summary = card.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Text(card.url.host ?? card.url.absoluteString)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(8)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.tertiary, lineWidth: 0.5)
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Link to \(card.title ?? card.url.absoluteString)")
        .accessibilityHint("Opens in Safari")
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.tint.opacity(0.10))
            .overlay {
                Image(systemName: "link")
                    .foregroundStyle(.tint.opacity(0.6))
                    .font(.title3)
            }
    }
}
