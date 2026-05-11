import SwiftUI
import SkymarshalCore

/// Status bar shown above the list while ``ContentService`` is paginating.
/// Tighter typography hierarchy than the v1, with a soft pulse on the
/// scope glyph so the user can tell at a glance that work is still
/// happening (vs a frozen UI).
@available(iOS 17, *)
struct LoadProgressBanner: View {

    let progress: ContentService.LoadProgress
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // The scope motif ties the banner back to the app icon.
            // The pulse + symbol-effect feels alive without being noisy.
            ZStack {
                Circle()
                    .stroke(.tint.opacity(pulse ? 0.18 : 0.55), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                    .scaleEffect(pulse ? 1.25 : 1.0)
                    .opacity(pulse ? 0.0 : 1.0)
                Image(systemName: "scope")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating, value: pulse)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(progress.itemsLoaded.formatted())
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text("loaded")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Text("scanning \(progress.phase.rawValue.lowercased())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text("Search and filters work on what's loaded so far.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 4)

            Button {
                onCancel()
            } label: {
                Text("Stop")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 9)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading content. \(progress.itemsLoaded.formatted()) items loaded so far.")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pulse.toggle()
            }
        }
    }
}

@available(iOS 17, *)
#Preview {
    VStack {
        LoadProgressBanner(
            progress: .init(phase: .posts, itemsLoaded: 11_074, pagesFetched: 111, isComplete: false),
            onCancel: {}
        )
        Spacer()
    }
}
