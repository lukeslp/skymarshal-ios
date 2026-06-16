import SwiftUI
import SkymarshalCore

/// Sheet shown from AccountDetailView's "Interactions with you" button.
/// Two sections: outgoing (you → them, free, populates instantly) and
/// incoming (them → you, network sweep with progress + Cancel).
@available(iOS 17, *)
struct InteractionHistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let target: AnalyzedAccount

    @State private var bundle: InteractionBundle?
    @State private var progress: InteractionProgress?
    @State private var loadTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var hasStarted: Bool = false

    /// Power-user toggle: walks ~2000 items per direction instead of
    /// the default 200. Persisted across sessions so a user who wants
    /// the long sweep doesn't have to re-enable on every visit.
    @AppStorage("sm.interactionDeepSweep") private var deepSweep: Bool = false

    var body: some View {
        NavigationStack {
            List {
                if let progress, progress.phase != .complete {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(progress.message)
                                    .font(.footnote)
                                Text("Tap Cancel to stop and keep what's loaded.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Cancel") { loadTask?.cancel() }
                                .font(.footnote.weight(.medium))
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                    }
                }

                if let bundle {
                    outgoingSections(bundle.outgoing)
                    if bundle.incomingReadState == .unknown
                        && progress?.phase == .complete {
                        Section {
                            Label(
                                "Bluesky throttled this read — counts may be incomplete. This account isn't treated as inactive.",
                                systemImage: "exclamationmark.triangle"
                            )
                            .font(.footnote)
                            .foregroundStyle(Theme.caution)
                        }
                    }
                    incomingSections(
                        bundle.incoming,
                        complete: bundle.incomingComplete,
                        examined: bundle.examinedPerDirection
                    )

                    if bundle.outgoing.isEmpty && bundle.incoming.isEmpty
                       && progress?.phase == .complete {
                        ContentUnavailableView(
                            "No interactions yet",
                            systemImage: "scope",
                            description: Text("You and @\(target.handle) haven't crossed paths in your archives.")
                        )
                    }
                } else if hasStarted {
                    ContentUnavailableView(
                        "Loading…",
                        systemImage: "scope",
                        description: Text("Pulling interactions with @\(target.handle).")
                    )
                }
            }
            .navigationTitle("Interactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(target.profile.displayName ?? target.handle)
                            .font(.subheadline.weight(.semibold))
                        Text("@\(target.handle)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle(isOn: $deepSweep) {
                            Label("Deep sweep", systemImage: "magnifyingglass.circle")
                        }
                        Text("Walks ~2 000 items per direction instead of the default 200. Takes longer; shows more.")
                            .font(.caption2)
                    } label: {
                        Image(systemName: deepSweep
                              ? "magnifyingglass.circle.fill"
                              : "ellipsis.circle")
                    }
                    .accessibilityLabel(deepSweep ? "Sweep options (Deep sweep on)" : "Sweep options")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: deepSweep) { _, _ in
                // Re-run with the new cap. Cancel any in-flight sweep
                // and start fresh; the partial bundle becomes stale
                // the moment the user changes the depth they want.
                bundle = nil
                progress = nil
                errorMessage = nil
                Task { await runLoad() }
            }
            .task {
                guard !hasStarted else { return }
                hasStarted = true
                await runLoad()
            }
            .onDisappear { loadTask?.cancel() }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func outgoingSections(_ outgoing: [Interaction]) -> some View {
        let groups = group(outgoing)
        Section {
            if outgoing.isEmpty {
                Text("Nothing from you yet — try liking, replying, or reposting one of theirs.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(orderedKinds(for: groups), id: \.self) { kind in
                    if let items = groups[kind] {
                        ForEach(items) { row(for: $0) }
                    }
                }
            }
        } header: {
            HStack {
                Text("From you").font(.footnote.weight(.semibold))
                Spacer()
                Text("\(outgoing.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func incomingSections(_ incoming: [Interaction], complete: Bool, examined: Int) -> some View {
        let groups = group(incoming)
        Section {
            if incoming.isEmpty && progress?.phase == .complete {
                Text("Nothing from them yet — at least not in their last \(examined) items.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(orderedKinds(for: groups), id: \.self) { kind in
                    if let items = groups[kind] {
                        ForEach(items) { row(for: $0) }
                    }
                }
                if !complete && progress?.phase == .complete {
                    Text("Showing the most recent \(examined) items per category. Toggle Deep sweep above to widen.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            HStack {
                Text("From them").font(.footnote.weight(.semibold))
                Spacer()
                Text("\(incoming.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func row(for interaction: Interaction) -> some View {
        InteractionRow(interaction: interaction)
    }

    private func group(_ items: [Interaction]) -> [Interaction.Kind: [Interaction]] {
        Dictionary(grouping: items, by: \.kind)
    }

    private func orderedKinds(for groups: [Interaction.Kind: [Interaction]]) -> [Interaction.Kind] {
        // Prefer likes → reposts → replies (effort-ascending; replies
        // are the most engaged interaction so they read last as the
        // "most meaningful" anchor)
        [Interaction.Kind.like, .repost, .reply].filter { groups[$0] != nil }
    }

    // MARK: - Run

    private func runLoad() async {
        loadTask?.cancel()
        let model = self.model
        let userItems = model.items
        let targetDID = target.did
        let targetHandle = target.handle
        let modelAccounts = model.accounts
        let cap = deepSweep
            ? InteractionService.deepSweepPageCap
            : InteractionService.defaultPageCap
        loadTask = Task {
            do {
                let userDID = (await model.content.currentDID) ?? ""
                let result = try await model.interactions.loadInteractions(
                    userDID: userDID,
                    userItems: userItems,
                    targetDID: targetDID,
                    targetHandle: targetHandle,
                    cap: cap,
                    progress: { p in
                        await MainActor.run {
                            self.progress = p
                            // Outgoing is instant; surface those before
                            // incoming finishes so the sheet isn't empty.
                            if self.bundle == nil, p.phase == .outgoing {
                                let outgoing = InteractionService.filterOutgoing(
                                    items: userItems, targetDID: targetDID
                                )
                                let placeholderProfile = modelAccounts
                                    .first(where: { $0.did == targetDID })?
                                    .profile
                                    ?? BskyProfile(did: targetDID, handle: targetHandle)
                                self.bundle = InteractionBundle(
                                    target: placeholderProfile,
                                    outgoing: outgoing,
                                    incoming: [],
                                    examinedPerDirection: cap
                                )
                            }
                        }
                    }
                )
                await MainActor.run {
                    self.bundle = result
                    self.progress = InteractionProgress(
                        phase: .complete,
                        itemsFound: result.outgoing.count + result.incoming.count,
                        message: "Done"
                    )
                }
            } catch is CancellationError {
                // Keep partial bundle visible.
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        await loadTask?.value
    }
}

// Page-cap constants now live on InteractionService directly
// (defaultPageCap / deepSweepPageCap) and the actual cap used for a
// given bundle rides along on InteractionBundle.examinedPerDirection.
// (ContentService.currentDID lives in ContentService.swift now.)
