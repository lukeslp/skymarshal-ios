import SwiftUI
import SkymarshalCore

/// Four-step first-run introduction adapted from the Figma Make prototype.
///
/// Inputs: a completion callback supplied by RootView.
/// Output: a skippable, motion-aware carousel that hands off to LoginView.
@available(iOS 17, *)
struct OnboardingView: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var step = 0

    private var reduceMotion: Bool {
        ReduceMotion.shouldReduce(systemReduceMotion: systemReduceMotion)
    }

    private let steps = OnboardingStep.all

    var body: some View {
        ZStack {
            Theme.void.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip", action: onComplete)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityHint("Skips the introduction and opens sign in")
                }
                .padding(.horizontal, 20)

                ScrollView {
                    stepContent
                        .id(step)
                        .padding(.vertical, 24)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                )
                        )
                }
                .scrollIndicators(.hidden)
                .defaultScrollAnchor(.center)

                VStack(spacing: 22) {
                    HStack(spacing: 6) {
                        ForEach(steps.indices, id: \.self) { index in
                            Capsule()
                                .fill(
                                    index == step
                                        ? Theme.cinematicAccentA
                                        : Color.secondary.opacity(0.35)
                                )
                                .frame(width: index == step ? 18 : 6, height: 6)
                                .animation(reduceMotion ? nil : .snappy, value: step)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel("Step \(step + 1) of \(steps.count)")

                    Button(steps[step].cta) {
                        advance()
                    }
                    .buttonStyle(SaturnButton(emphasis: .primaryCinematic))
                    .accessibilityHint(
                        step == steps.count - 1
                            ? "Opens the Bluesky sign-in form"
                            : "Shows the next introduction page"
                    )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 34)
            }
        }
    }

    private var stepContent: some View {
        VStack(spacing: 28) {
            Image(systemName: steps[step].symbol)
                .font(.system(size: 38, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(
                    step == 0
                        ? AnyShapeStyle(Theme.cinematicTitleGradient)
                        : AnyShapeStyle(Theme.cinematicAccentA)
                )
                .frame(width: 88, height: 88)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.elev1)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Theme.hairlineMed, lineWidth: 1)
                        }
                }
                .accessibilityHidden(true)

            VStack(spacing: 14) {
                Text(steps[step].title)
                    .font(Theme.Display.title(.title))
                    .foregroundStyle(
                        step == 0
                            ? AnyShapeStyle(Theme.cinematicTitleGradient)
                            : AnyShapeStyle(Color.primary)
                    )
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(steps[step].body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .frame(maxWidth: 340)
            }
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .contain)
    }

    private func advance() {
        guard step < steps.count - 1 else {
            onComplete()
            return
        }
        if reduceMotion {
            step += 1
        } else {
            withAnimation(.snappy) {
                step += 1
            }
        }
    }
}

private struct OnboardingStep {
    let symbol: String
    let title: String
    let body: String
    let cta: String

    static let all: [OnboardingStep] = [
        OnboardingStep(
            symbol: "sparkles",
            title: "Skymarshal",
            body: "Air-traffic control for your Bluesky.\nFind old posts. Review patterns. Tidy in bulk—with confirmations that match the stakes.",
            cta: "Next"
        ),
        OnboardingStep(
            symbol: "doc.text.magnifyingglass",
            title: "Your full archive",
            body: "Search posts, replies, likes, and reposts. Filter by keyword, date, engagement, or media, then review every destructive action.",
            cta: "Next"
        ),
        OnboardingStep(
            symbol: "person.2",
            title: "Understand your following",
            body: "Review automation signals, inactivity, and follower asymmetry. Preview bulk unfollows before anything changes.",
            cta: "Next"
        ),
        OnboardingStep(
            symbol: "lock.shield",
            title: "Your data stays on-device",
            body: "Skymarshal talks directly to Bluesky. There are no Skymarshal servers, no third-party analytics, and your app password is never persisted.",
            cta: "Sign in"
        ),
    ]
}

@available(iOS 17, *)
#Preview {
    OnboardingView(onComplete: {})
        .preferredColorScheme(.dark)
}
