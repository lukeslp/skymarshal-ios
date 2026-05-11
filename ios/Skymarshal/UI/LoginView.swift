import SwiftUI
import UIKit
import SkymarshalCore

@available(iOS 17, *)
struct LoginView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlOn
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { ReduceMotion.shouldReduce(systemReduceMotion: systemReduceMotion) }

    @State private var handle: String = ""
    @State private var appPassword: String = ""

    var canSubmit: Bool {
        !handle.trimmingCharacters(in: .whitespaces).isEmpty
            && !appPassword.isEmpty
            && !model.isLoading
    }

    @State private var showEasterEgg = false

    /// Easter egg long-press gates on:
    /// (1) AT off — VoiceOver / Switch Control users routinely hold
    ///     focus on elements much longer than typical touch press.
    /// (2) 6-second minimum — well past any incidental hold.
    private var easterEggEnabled: Bool {
        !voiceOverOn && !switchControlOn
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DotBirdHeader(
                    reduceMotion: reduceMotion,
                    secretHoldEnabled: easterEggEnabled,
                    onSecretHold: { showEasterEgg = true }
                )
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                Form {
                    Section {
                        TextField("yourname.bsky.social", text: $handle)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .accessibilityLabel("Bluesky handle")
                        SecureField("app password", text: $appPassword)
                            .textContentType(.password)
                            .accessibilityLabel("App password")
                    } header: {
                        Text("Climb aboard")
                            .font(.subheadline.weight(.semibold))
                            .tracking(0.3)
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Use an **app password**, not your main one. Skymarshal never sees your real password — generate a disposable app password at bsky.app under Settings → App Passwords and bring that.")
                            Link("Open Bluesky settings", destination: URL(string: "https://bsky.app/settings/app-passwords")!)
                                .font(.footnote)
                        }
                    }

                    if let error = model.errorMessage {
                        Section {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .symbolRenderingMode(.hierarchical)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Sign-in error: \(error)")
                                .accessibilityAddTraits(.isStaticText)
                        }
                    }

                    Section {
                        Button {
                            Task { await model.login(handle: handle, password: appPassword) }
                        } label: {
                            HStack {
                                if model.isLoading {
                                    ProgressView().controlSize(.small)
                                }
                                Text(model.isLoading ? "Signing in…" : "Sign in")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSubmit)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(LoginBackground())
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if showEasterEgg {
                    EasterEggOverlay(isPresented: $showEasterEgg)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showEasterEgg)
            .onChange(of: model.errorMessage) { _, newValue in
                if let msg = newValue, !msg.isEmpty {
                    // WCAG 4.1.3 — announce the error so VoiceOver
                    // users hear it without re-navigating to the form.
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Sign-in error: \(msg)"
                    )
                }
            }
        }
    }
}

/// Dot-matrix spy-bird hero + wordmark. The bird itself is the same
/// silhouette as the AppIcon, rendered as cyan dots on the gradient with
/// a single orange visor accent — matches the launch screen. Hidden
/// from VoiceOver as decorative; the wordmark below labels the section.
@available(iOS 17, *)
private struct DotBirdHeader: View {
    let reduceMotion: Bool
    let secretHoldEnabled: Bool
    let onSecretHold: () -> Void

    @State private var appear = false

    var body: some View {
        VStack(spacing: 10) {
            Image("DotBird")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .opacity(appear ? 1.0 : 0.0)
                .scaleEffect(appear ? 1.0 : 0.92)
                .animation(reduceMotion ? nil : .spring(duration: 0.6), value: appear)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Skymarshal")
                    .font(.system(.largeTitle, design: .default).weight(.semibold))
                Text("Air-traffic control for your Bluesky.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            .contentShape(Rectangle())
            // 6-second minimum and gated on assistive-tech off. Dwell /
            // Switch Control / VoiceOver users routinely hold focus on
            // elements for far longer than typical touch press; the
            // gate prevents this from firing on every sign-in for them.
            .gesture(
                secretHoldEnabled
                    ? LongPressGesture(minimumDuration: 6.0)
                        .onEnded { _ in onSecretHold() }
                    : nil
            )
        }
        .onAppear { appear = true }
    }
}

/// Hidden visual overlay revealed by 6-second hold on the wordmark.
/// Not documented in user-facing copy. No auto-dismiss timer — the
/// WCAG 2.2.1 (Timing Adjustable) failure that was here is gone. User
/// taps anywhere to close, or uses the explicit Close button.
@available(iOS 17, *)
private struct EasterEggOverlay: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            Image("EasterAlf")
                .resizable()
                .scaledToFit()
                .padding(32)
                .accessibilityHidden(true)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityHint("Dismisses this overlay")
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                }
                Spacer()
            }
        }
        .onTapGesture { isPresented = false }
    }
}

@available(iOS 17, *)
private struct LoginBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.accentColor.opacity(0.08),
                Color(.systemBackground),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

@available(iOS 17, *)
#Preview {
    LoginView()
        .environment(AppModel.liveDefault())
}
