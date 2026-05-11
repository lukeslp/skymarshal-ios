import SwiftUI
import SkymarshalCore

/// Big centered "we're working on it" view shown when a scan has been
/// kicked off but the first analyzed batch hasn't landed yet. Replaces
/// the silent blank-area-under-thin-banner state.
@available(iOS 17, *)
struct ScanInFlightView: View {
    let progress: ScanProgress?
    let onStop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(.tint.opacity(0.45 - Double(i) * 0.12), lineWidth: 1)
                        .frame(width: 56 + CGFloat(i) * 18, height: 56 + CGFloat(i) * 18)
                        .scaleEffect(pulse ? 1.05 : 0.95)
                        .opacity(pulse ? 1.0 : 0.7)
                }
                Image(systemName: "scope")
                    .font(.system(.largeTitle, design: .default).weight(.light))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating, value: pulse)
            }
            .frame(height: 110)
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

            VStack(spacing: 6) {
                Text(headlineText)
                    .font(.headline)
                Text(detailText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let progress, progress.total > 0 {
                ProgressView(value: Double(progress.current), total: Double(max(progress.total, progress.current)))
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .frame(width: 220)
            } else {
                ProgressView()
                    .controlSize(.regular)
            }

            Button("Stop scan", role: .destructive, action: onStop)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .onAppear { if !reduceMotion { pulse = true } }
    }

    private var headlineText: String {
        switch progress?.phase {
        case .fetching:    return "Pulling your follow list…"
        case .hydrating:   return "Looking up account details…"
        case .lastPosts:   return "Checking who's still active…"
        case .interactions:return "Sweeping interaction history…"
        case .analyzing:   return "Scoring accounts…"
        case .complete:    return "Done"
        case .error, .none:return "Boarding…"
        }
    }

    private var detailText: String {
        guard let progress else { return "Skymarshal is calling out to Bluesky." }
        if progress.total > 0 {
            return "\(progress.current.formatted()) of about \(progress.total.formatted())"
        }
        return progress.message
    }
}
