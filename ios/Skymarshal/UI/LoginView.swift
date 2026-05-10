import SwiftUI
import SkymarshalCore

@available(iOS 17, *)
struct LoginView: View {
    @Environment(AppModel.self) private var model

    @State private var handle: String = ""
    @State private var appPassword: String = ""

    var canSubmit: Bool {
        !handle.trimmingCharacters(in: .whitespaces).isEmpty
            && !appPassword.isEmpty
            && !model.isLoading
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScopeHeader()
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                Form {
                    Section {
                        TextField("yourname.bsky.social", text: $handle)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        SecureField("app password", text: $appPassword)
                            .textContentType(.password)
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
                        }
                    }

                    Section {
                        Button {
                            Task { await model.login(handle: handle, password: appPassword) }
                        } label: {
                            HStack {
                                if model.isLoading {
                                    ProgressView().controlSize(.small).tint(.white)
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
            .navigationBarHidden(true)
        }
    }
}

/// The visual signature: scope glyph + concentric rings + wordmark.
/// Small, restrained, only on the auth screen. The same scope motif as
/// the app icon and the LoadProgressBanner — a quiet through-line.
@available(iOS 17, *)
private struct ScopeHeader: View {
    @State private var animateRings = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(.tint.opacity(0.45 - Double(i) * 0.12), lineWidth: 1)
                        .frame(width: 56 + CGFloat(i) * 18, height: 56 + CGFloat(i) * 18)
                        .scaleEffect(animateRings ? 1.0 : 0.85)
                        .opacity(animateRings ? 1.0 : 0.0)
                        .animation(
                            .spring(duration: 0.7).delay(Double(i) * 0.08),
                            value: animateRings
                        )
                }
                Image(systemName: "scope")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(height: 100)

            VStack(spacing: 4) {
                Text("Skymarshal")
                    .font(.system(.largeTitle, design: .default).weight(.semibold))
                Text("Air-traffic control for your Bluesky.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .onAppear { animateRings = true }
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
