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

    @State private var showEasterEgg = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DotBirdHeader(onSecretHold: { showEasterEgg = true })
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
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if showEasterEgg {
                    EasterEggOverlay(isPresented: $showEasterEgg)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showEasterEgg)
        }
    }
}

/// Dot-matrix spy-bird hero + wordmark. The bird itself is the same
/// silhouette as the AppIcon, rendered as cyan dots on the gradient with
/// a single orange visor accent — matches the launch screen.
@available(iOS 17, *)
private struct DotBirdHeader: View {
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
                .animation(.spring(duration: 0.6), value: appear)

            VStack(spacing: 4) {
                Text("Skymarshal")
                    .font(.system(.largeTitle, design: .default).weight(.semibold))
                Text("Air-traffic control for your Bluesky.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 3.0) {
                onSecretHold()
            }
        }
        .onAppear { appear = true }
    }
}

/// Hidden visual easter egg revealed by 3-second hold on the wordmark.
/// Not documented in user-facing copy. Dismisses automatically after 4s
/// or on tap.
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
        }
        .onTapGesture { isPresented = false }
        .task {
            try? await Task.sleep(for: .seconds(4))
            isPresented = false
        }
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
