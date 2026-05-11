import SwiftUI
import SkymarshalCore

/// Full-screen pager for a post's media. Swipe between attachments,
/// pinch-zoom on each image, and read the alt text caption — the
/// alt-text surface that's been search-indexed since launch but
/// never visible until now.
@available(iOS 17, *)
struct MediaLightboxView: View {
    let media: [MediaPreview]
    @State var initialIndex: Int = 0
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                TabView(selection: $currentIndex) {
                    ForEach(Array(media.enumerated()), id: \.offset) { index, item in
                        MediaPage(item: item)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .always : .never))

                // Alt-text caption pinned to the bottom. Black-tinted
                // glass card; readable in any image's color profile.
                VStack {
                    Spacer()
                    if let alt = media[safe: currentIndex]?.alt, !alt.isEmpty {
                        AltTextCaption(text: alt)
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                            .transition(.opacity)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
                if media.count > 1 {
                    ToolbarItem(placement: .principal) {
                        Text("\(currentIndex + 1) of \(media.count)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.black.opacity(0.4), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear { currentIndex = initialIndex }
    }
}

@available(iOS 17, *)
private struct MediaPage: View {
    let item: MediaPreview

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let url = item.fullsizeURL ?? item.thumbnailURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .scaleEffect(scale)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = max(1.0, min(4.0, lastScale * value))
                                        }
                                        .onEnded { _ in
                                            lastScale = scale
                                            if scale < 1.05 {
                                                if reduceMotion { scale = 1.0; lastScale = 1.0 }
                                                else { withAnimation { scale = 1.0; lastScale = 1.0 } }
                                            }
                                        }
                                )
                                .onTapGesture(count: 2) {
                                    let target: CGFloat = scale > 1.0 ? 1.0 : 2.0
                                    if reduceMotion {
                                        scale = target; lastScale = target
                                    } else {
                                        withAnimation(.spring) {
                                            scale = target
                                            lastScale = target
                                        }
                                    }
                                }
                        case .failure:
                            failedState
                        case .empty:
                            ProgressView()
                                .controlSize(.large)
                                .tint(.white)
                        @unknown default:
                            failedState
                        }
                    }
                } else {
                    failedState
                }

                if item.kind == .video {
                    Image(systemName: "play.fill")
                        .font(.system(.largeTitle, design: .default).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .background(Circle().fill(.black.opacity(0.45)).frame(width: 110, height: 110))
                        .accessibilityLabel("Play video")
                }
            }
        }
    }

    private var failedState: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.largeTitle)
            Text("Couldn't load this image")
                .font(.callout)
        }
        .foregroundStyle(.white.opacity(0.6))
    }
}

@available(iOS 17, *)
private struct AltTextCaption: View {
    let text: String
    @State private var expanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.caption.weight(.semibold))
                Text("Alt text")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button(expanded ? "Less" : "More") {
                    withAnimation { expanded.toggle() }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
            }
            .foregroundStyle(.white.opacity(0.85))

            Text(text)
                .font(.callout)
                .foregroundStyle(.white)
                .lineLimit(expanded ? nil : 3)
        }
        .padding(12)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
