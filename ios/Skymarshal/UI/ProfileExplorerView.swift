import SwiftUI
import SkymarshalCore

/// Read-only followers / following lists for any handle — not a timeline client.
@available(iOS 17, *)
struct ProfileExplorerView: View {

    let actorHandle: String

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var segment = 0
    @State private var followers: [BskyProfile] = []
    @State private var follows: [BskyProfile] = []
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Graph", selection: $segment) {
                    Text("Followers").tag(0)
                    Text("Following").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if loading {
                    ProgressView("Loading…")
                        .frame(maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Couldn’t load graph",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    List(segment == 0 ? followers : follows, id: \.did) { p in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@\(p.handle)")
                                .font(.body.weight(.medium))
                            if let dn = p.displayName, !dn.isEmpty {
                                Text(dn)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("@\(actorHandle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task(id: actorHandle) {
                await loadBoth()
            }
            .onChange(of: segment) { _, _ in
                // Lists swap instantly — data prefetched in task.
            }
        }
    }

    private func loadBoth() async {
        loading = true
        errorMessage = nil
        defer { loading = false }
        do {
            async let f = model.loadExplorerFollowers(actor: actorHandle)
            async let g = model.loadExplorerFollows(actor: actorHandle)
            let (fv, gv) = try await (f, g)
            followers = fv
            follows = gv
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
