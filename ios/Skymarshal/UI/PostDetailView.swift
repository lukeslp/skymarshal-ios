import SwiftUI
import SkymarshalCore

/// Sheet shown when the user taps a ContentRow. Carries the full text
/// (no truncation), inline tappable URLs from the post's facets, the
/// media gallery (tap to lightbox), the external link card if present,
/// engagement counts, and two actions: Delete + View on Bluesky.
@available(iOS 17, *)
struct PostDetailView: View {
    let item: ContentItem
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var lightboxStartIndex: Int? = nil
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    if let text = item.text, !text.isEmpty {
                        Text(AttributedPostText.make(text: text, links: item.textLinks))
                            .font(.body)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !item.media.isEmpty {
                        MediaGallery(
                            media: item.media,
                            onTap: { index in lightboxStartIndex = index }
                        )
                    }

                    if let card = item.linkCard {
                        LinkCardView(card: card)
                    }

                    metricRow

                    Divider().padding(.vertical, 4)

                    actions
                }
                .padding()
            }
            .navigationTitle(item.contentType.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { lightboxStartIndex.map { LightboxStart(index: $0) } },
                set: { lightboxStartIndex = $0?.index }
            )) { start in
                MediaLightboxView(media: item.media, initialIndex: start.index)
            }
            .confirmationDialog(
                "Delete this \(item.contentType.label.lowercased())?",
                isPresented: $showDeleteConfirm
            ) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes the record from Bluesky. It cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: item.contentType.sfSymbol)
                .foregroundStyle(item.contentType.stripeColor)
            Text(item.contentType.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let date = item.createdAt {
                Text("·").foregroundStyle(.tertiary)
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if item.engagementScore > 0 {
                EngagementBadge(score: Int(item.engagementScore))
            }
        }
    }

    @ViewBuilder
    private var metricRow: some View {
        HStack(spacing: 18) {
            metric("\(item.likeCount)", "heart")
            metric("\(item.repostCount)", "arrow.2.squarepath")
            metric("\(item.replyCount)", "bubble.left")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 8) {
            if let url = item.bskyAppURL {
                Button {
                    openURL(url)
                } label: {
                    Label("View on Bluesky", systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.danger)
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private func metric(_ count: String, _ symbol: String) -> some View {
        Label(count, systemImage: symbol)
            .labelStyle(.titleAndIcon)
            .symbolRenderingMode(.hierarchical)
    }
}

/// Bigger version of MediaThumbnailRow for the detail sheet —
/// 96pt thumbs, tap to open the lightbox at that index.
@available(iOS 17, *)
private struct MediaGallery: View {
    let media: [MediaPreview]
    let onTap: (Int) -> Void

    private let thumbSize: CGFloat = 96

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(media.enumerated()), id: \.offset) { index, item in
                    Button {
                        onTap(index)
                    } label: {
                        thumb(for: item)
                            .frame(width: thumbSize, height: thumbSize)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                if item.kind == .video {
                                    Image(systemName: "play.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(5)
                                        .background(.black.opacity(0.55), in: .circle)
                                        .padding(6)
                                        .accessibilityLabel("Play video")
                                }
                            }
                            .overlay(alignment: .bottomLeading) {
                                if item.alt?.isEmpty == false {
                                    Text("ALT")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(.black.opacity(0.55), in: .capsule)
                                        .padding(6)
                                        .accessibilityLabel("Alt text available")
                                }
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(.tertiary, lineWidth: 0.5)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentMargins(.trailing, 8, for: .scrollContent)
    }

    @ViewBuilder
    private func thumb(for item: MediaPreview) -> some View {
        if let url = item.thumbnailURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: placeholder(item.kind)
                }
            }
        } else {
            placeholder(item.kind)
        }
    }

    private func placeholder(_ kind: MediaPreview.Kind) -> some View {
        Rectangle()
            .fill(.tint.opacity(0.10))
            .overlay {
                Image(systemName: kind == .video ? "video" : "photo")
                    .foregroundStyle(.tint.opacity(0.6))
                    .font(.title2)
            }
    }
}

/// Identifiable wrapper so .sheet(item:) can carry the lightbox start index.
private struct LightboxStart: Identifiable {
    let index: Int
    var id: Int { index }
}
