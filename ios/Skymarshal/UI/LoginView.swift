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
                    Text("Sign in to Bluesky")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Use an **app password**, not your main account password. Generate one at bsky.app under Settings → App Passwords.")
                        Link("Open Bluesky settings", destination: URL(string: "https://bsky.app/settings/app-passwords")!)
                            .font(.footnote)
                    }
                }

                if let error = model.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await model.login(handle: handle, password: appPassword) }
                    } label: {
                        HStack {
                            if model.isLoading { ProgressView() }
                            Text("Sign in")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Skymarshal")
        }
    }
}

@available(iOS 17, *)
#Preview {
    LoginView()
        .environment(AppModel.liveDefault())
}
