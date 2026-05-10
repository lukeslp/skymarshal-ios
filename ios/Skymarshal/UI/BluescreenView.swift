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

// Helper views for this screen live in their own files for navigability:
//   ScanInFlightView    — big in-flight loading state (ScanInFlightView.swift)
//   ScanSummaryStrip    — color-coded count pills above the list (ScanSummaryStrip.swift)
//   LoadProgressBannerLite + ScanErrorBanner — thin top bars (StatusBanners.swift)
//   AccountRow + BotScoreBadge — list cell + badge (AccountRow.swift)
