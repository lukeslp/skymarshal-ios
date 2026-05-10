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
    @State private var sortField: FollowerFilters.SortField = .botScore
    @State private var sortDirection: FollowerFilters.SortDirection = .desc
    @State private var detailAccount: AnalyzedAccount? = nil

    private var filtered: [AnalyzedAccount] {
        var f = FollowerFilters()
        f.search = keyword
        f.sortField = sortField
        f.sortDirection = sortDirection
        return f.apply(to: model.accounts)
    }

    private func makeFollowersJSON() -> ExportPayload {
        do {
            return try Exporter.followersJSON(model.accounts, handle: model.currentHandle)
        } catch {
            return Exporter.followersCSV([])
        }
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            VStack(spacing: 0) {
                if !model.accounts.isEmpty {
                    ScanSummaryStrip(summary: model.scanSummary)
                }

                // "Last scanned 3h ago" — only when no live scan is
                // running. First thing the user sees on cold start.
                if let lastScanned = model.lastFollowerScannedAt,
                   model.scanProgress == nil,
                   !model.isScanning {
                    LastScannedBanner(lastScannedAt: lastScanned) {
                        model.startScan()
                    }
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

                // Inline Sort + Select row — sits below the summary
                // strip and is always visible regardless of search-bar
                // focus state (the toolbar is dead during .searchable
                // activation; same trap as ContentListView).
                if !model.accounts.isEmpty {
                    HStack(spacing: 12) {
                        Menu {
                            Picker("Sort by", selection: $sortField) {
                                ForEach(FollowerFilters.SortField.allCases) { field in
                                    Text(field.label).tag(field)
                                }
                            }
                            Divider()
                            Picker("Order", selection: $sortDirection) {
                                Label("Descending", systemImage: "arrow.down")
                                    .tag(FollowerFilters.SortDirection.desc)
                                Label("Ascending", systemImage: "arrow.up")
                                    .tag(FollowerFilters.SortDirection.asc)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: sortDirection == .desc ? "arrow.down" : "arrow.up")
                                    .font(.caption2)
                                Text("Sort: \(sortField.label)")
                                    .font(.footnote.weight(.medium))
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.tint)
                        }

                        Spacer(minLength: 8)

                        Button {
                            withAnimation(.snappy) {
                                editMode = editMode.isEditing ? .inactive : .active
                                if !editMode.isEditing { selection.removeAll() }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: editMode.isEditing
                                      ? "checkmark.circle.fill"
                                      : "checkmark.circle")
                                    .font(.footnote)
                                Text(editMode.isEditing ? "Done" : "Select")
                                    .font(.footnote.weight(.medium))
                            }
                            .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
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
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !editMode.isEditing {
                                        detailAccount = account
                                    }
                                }
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
                        if !model.accounts.isEmpty {
                            Section("Export") {
                                ShareLink(
                                    item: ExportItem(payload: makeFollowersJSON()),
                                    preview: SharePreview(
                                        "Skymarshal — followers (JSON)",
                                        image: Image(systemName: "doc.text")
                                    )
                                ) {
                                    Label("As JSON", systemImage: "curlybraces")
                                }
                                ShareLink(
                                    item: ExportItem(payload: Exporter.followersCSV(model.accounts)),
                                    preview: SharePreview(
                                        "Skymarshal — followers (CSV)",
                                        image: Image(systemName: "tablecells")
                                    )
                                ) {
                                    Label("As CSV", systemImage: "tablecells")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "scope")
                    }
                }
                // Select toggle moved inline above the list — toolbar
                // items are hidden when .searchable is focused, which
                // would block the search-then-select flow entirely.
            }
            .environment(\.editMode, $editMode)
            .searchable(text: $keyword, prompt: "Search handle or name")
            .sheet(item: $detailAccount) { acc in
                AccountDetailView(account: acc) {
                    Task { _ = await model.unfollow(dids: [acc.did]) }
                }
            }
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
