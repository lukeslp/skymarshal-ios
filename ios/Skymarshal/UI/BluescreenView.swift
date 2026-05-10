import SwiftUI
import SkymarshalCore

/// Followers / bot / inactive cleanup screen — the "bluescreen" tab.
/// Step 4 of the plan: minimum viable shell. Step 5/6/7 will layer
/// in pill-chip filters, the full filter sheet, and the unfollow
/// confirmation dialog.
@available(iOS 17, *)
struct BluescreenView: View {
    @Environment(AppModel.self) private var model

    @State private var keyword: String = ""
    @State private var pendingUnfollow: [String]? = nil
    @State private var selection: Set<String> = []
    @State private var editMode: EditMode = .inactive

    private var filtered: [AnalyzedAccount] {
        var f = FollowerFilters()
        f.search = keyword
        return f.apply(to: model.accounts)
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            VStack(spacing: 0) {
                if !model.accounts.isEmpty {
                    ScanSummaryStrip(summary: model.scanSummary)
                }
                // Banner only when results have started arriving — the
                // empty-while-scanning state below renders its own
                // big centered status, no need to double up.
                if !model.accounts.isEmpty,
                   let progress = model.scanProgress,
                   progress.phase != .complete {
                    LoadProgressBannerLite(
                        title: progress.message,
                        onCancel: { model.cancelScan() }
                    )
                }
                if let error = model.errorMessage {
                    ScanErrorBanner(message: error) {
                        model.errorMessage = nil
                    }
                }
                if editMode.isEditing {
                    EditActionBar(
                        selectionCount: selection.count,
                        visibleCount: filtered.count,
                        allSelected: !filtered.isEmpty && selection == Set(filtered.map(\.did)),
                        onToggleAll: {
                            let all = Set(filtered.map(\.did))
                            selection = (selection == all) ? [] : all
                        },
                        onDelete: { pendingUnfollow = Array(selection) }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if model.accounts.isEmpty && !model.isScanning {
                    ContentUnavailableView {
                        Label("Scan your follow list", systemImage: "scope")
                    } description: {
                        Text("Pull up everyone you follow and score each one for bot patterns, inactivity, and mutuality.")
                    } actions: {
                        Button("Begin scan") { model.startScan() }
                            .buttonStyle(.borderedProminent)
                    }
                } else if model.accounts.isEmpty && model.isScanning {
                    ScanInFlightView(
                        progress: model.scanProgress,
                        onStop: { model.cancelScan() }
                    )
                } else {
                    List(selection: $selection) {
                        ForEach(filtered) { account in
                            AccountRow(account: account)
                                .listRowBackground(
                                    selection.contains(account.did)
                                    ? Color.accentColor.opacity(0.08)
                                    : Color(.systemBackground)
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        pendingUnfollow = [account.did]
                                    } label: {
                                        Label("Unfollow", systemImage: "person.crop.circle.badge.minus")
                                    }
                                }
                                .tag(account.did)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Followers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Scan now") { model.startScan() }
                            .disabled(model.isScanning)
                        if model.isScanning {
                            Button("Stop scan", role: .destructive) { model.cancelScan() }
                        }
                    } label: {
                        Image(systemName: "scope")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.snappy) {
                            editMode = editMode.isEditing ? .inactive : .active
                            if !editMode.isEditing { selection.removeAll() }
                        }
                    } label: {
                        Text(editMode.isEditing ? "Done" : "Select")
                            .font(.subheadline.weight(.medium))
                    }
                    .disabled(model.accounts.isEmpty)
                }
            }
            .environment(\.editMode, $editMode)
            .searchable(text: $keyword, prompt: "Search handle or name")
            .confirmationDialog(
                unfollowTitle,
                isPresented: unfollowBinding,
                presenting: pendingUnfollow
            ) { batch in
                Button("Unfollow \(batch.count)", role: .destructive) {
                    Task {
                        _ = await model.unfollow(dids: batch)
                        selection.removeAll()
                        pendingUnfollow = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingUnfollow = nil }
            } message: { batch in
                Text("Removes you as a follower of \(batch.count) account\(batch.count == 1 ? "" : "s"). They keep their content; you keep yours. Unfollows go through the same rate-limit safety net as deletes — bulk runs may pause briefly.")
            }
        }
    }

    private var unfollowTitle: String {
        let n = pendingUnfollow?.count ?? 0
        return "Unfollow \(n) account\(n == 1 ? "" : "s")?"
    }

    private var unfollowBinding: Binding<Bool> {
        Binding(
            get: { pendingUnfollow != nil },
            set: { if !$0 { pendingUnfollow = nil } }
        )
    }
}

@available(iOS 17, *)
struct ScanSummaryStrip: View {
    let summary: ScanSummary

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                stat("\(summary.totalAnalyzed.formatted())", "analyzed", .secondary)
                stat("\(summary.bots)", "bots", .red)
                stat("\(summary.inactive)", "inactive", .orange)
                stat("\(summary.deleted)", "deleted", .red)
                stat("\(summary.mutuals)", "mutuals", .accentColor)
                stat("\(summary.badRatio)", "bad ratio", .yellow)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(.thinMaterial)
        .scrollClipDisabled()
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.10), in: .capsule)
    }
}

/// Big centered "we're working on it" view shown when a scan has been
/// kicked off but the first analyzed batch hasn't landed yet. Replaces
/// the silent blank-area-under-thin-banner state.
@available(iOS 17, *)
struct ScanInFlightView: View {
    let progress: ScanProgress?
    let onStop: () -> Void

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
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse, options: .repeating, value: pulse)
            }
            .frame(height: 110)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

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
        .onAppear { pulse = true }
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

/// Inline error banner — surfaces scan / unfollow failures so users
/// don't see the empty-state-blink-empty-state cycle without knowing
/// what failed. Tap the X to dismiss; the next scan attempt clears it.
@available(iOS 17, *)
struct ScanErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't complete that")
                    .font(.footnote.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.08))
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }
}

/// Slimmer banner for the scan loading state. (LoadProgressBanner is
/// shaped for content-load progress with phase enum + items count;
/// scan progress is freer-form with messages like "Activity check…")
@available(iOS 17, *)
struct LoadProgressBannerLite: View {
    let title: String
    let onCancel: () -> Void

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "scope")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeating, value: pulse)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button("Stop", action: onCancel)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
        .onAppear { pulse.toggle() }
    }
}
