import SwiftUI
import SkymarshalCore

/// Followers / bot / inactive cleanup screen — the "bluescreen" tab.
/// Step 4 of the plan: minimum viable shell. Step 5/6/7 will layer
/// in pill-chip filters, the full filter sheet, and the unfollow
/// confirmation dialog.
@available(iOS 17, *)
struct BluescreenView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { ReduceMotion.shouldReduce(systemReduceMotion: systemReduceMotion) }

    @State private var keyword: String = ""
    @State private var pendingUnfollow: [String]? = nil
    @State private var selection: Set<String> = []
    @State private var editMode: EditMode = .inactive
    @State private var detailAccount: AnalyzedAccount? = nil
    @State private var expandedAccountIDs: Set<String> = []

    /// Opt-in capped ghost-verify batch state. `ghostVerifyTask` lets
    /// the banner cancel; `ghostVerifyProgress` drives the progress line.
    @State private var ghostVerifyTask: Task<Void, Never>? = nil
    @State private var ghostVerifyProgress: ScanProgress? = nil

    /// Inline bot-detection sensitivity preset. Discrete values only —
    /// safety committee verdict ruled out a free slider because a
    /// 0.1 setting would let a user bulk-block real humans. The
    /// 3-preset shape gives explicit, non-dangerous choices.
    /// 0.4 = Loose, 0.6 = Balanced (default), 0.8 = Strict.
    @AppStorage("sm.botSensitivity") private var botSensitivityRaw: Double = 0.6
    @State private var showLooseUnfollowConfirm: Bool = false

    /// Export sheet presentation. See ContentListView for the full
    /// rationale — same pattern, same crash class avoided. Sharing a
    /// single `lastExportFormat` AppStorage with the Content tab is
    /// preserved indirectly via `ExportSheet`.
    @State private var showExportSheet: Bool = false
    @State private var sharePayload: SharePayload?
    /// Same buffer-then-promote pattern as ContentListView. The
    /// ExportSheet's `onShare` callback puts the prepared payload
    /// here, then our `.onDismiss` for the export sheet promotes it
    /// to `sharePayload` so the share sheet only opens after the
    /// export sheet has fully torn down.
    @State private var pendingSharePayload: SharePayload?

    /// Single source of truth for the trim-fakes filter UI: the pill
    /// taps in ScanSummaryStrip AND the full BluescreenFilterSheet
    /// both write into this struct. Search keyword is layered on per
    /// render in `filtered` since it has its own State (.searchable
    /// binding lives separately).
    @State private var filters: FollowerFilters = {
        var f = FollowerFilters()
        f.sortField = .botScore
        f.sortDirection = .desc
        return f
    }()
    @State private var draftFilters: FollowerFilters = FollowerFilters()
    @State private var showFilterSheet: Bool = false
    @State private var dryRunBannerMessage: String?

    @AppStorage(FeatureFlags.cleanupPresetsKey) private var featureCleanupPresets: Bool = true
    @AppStorage(FeatureFlags.unfollowDryRunKey) private var unfollowDryRun: Bool = false

    private var filtered: [AnalyzedAccount] {
        var f = filters
        f.search = keyword
        f.botThreshold = botSensitivityRaw
        return f.apply(to: model.accounts)
    }

    /// Cap for the opt-in ghost-verify batch: never more than 100 reads
    /// per run (kill-criteria ceiling). Mirrors FollowerService's cap.
    private static let ghostVerifyCap = 100

    /// How many already-flagged disengaged candidates are eligible for
    /// the capped ghost-verify batch — reliable read, found disengaged,
    /// not yet checked. Drives the menu label and disabled state.
    private var flaggedGhostCandidateCount: Int {
        min(
            model.accounts.filter {
                $0.ghostVerdict == nil
                    && $0.activityReadState == .read
                    && $0.interactedRecently == false
            }.count,
            Self.ghostVerifyCap
        )
    }

    private func startGhostVerify() {
        guard ghostVerifyTask == nil else { return }
        ghostVerifyProgress = ScanProgress(
            phase: .interactions, current: 0, total: flaggedGhostCandidateCount,
            message: "Verifying flagged ghosts…"
        )
        ghostVerifyTask = Task {
            await model.verifyFlaggedGhosts(cap: Self.ghostVerifyCap) { progress in
                await MainActor.run { ghostVerifyProgress = progress }
            }
            await MainActor.run {
                ghostVerifyProgress = nil
                ghostVerifyTask = nil
            }
        }
    }

    /// FollowerService clears its in-memory list for the **fetching**
    /// phase before the first hydrated profile batch — `accounts` is
    /// briefly empty while `isScanning` is still true. If we hide the
    /// summary strip + Sort/Filter Menus on `accounts.isEmpty`, SwiftUI
    /// tears those controls down and rebuilds them when the first page
    /// arrives, which resets open Menus and feels like dropdowns
    /// "forget" the user's choices. Keep chrome mounted for the whole
    /// scan so `@State filters` bindings stay on one continuous view tree.
    private var showFollowersSummaryAndControls: Bool {
        !model.accounts.isEmpty || model.isScanning
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            VStack(spacing: 0) {
                CinematicScreenHeader(
                    title: "Patterns",
                    subtitle: "\(model.accounts.count.formatted()) FOLLOWING"
                ) {
                    Label(
                        "\(model.scanSummary.bots) flagged",
                        systemImage: "shield.lefthalf.filled"
                    )
                    .font(Theme.Mono.kicker(10))
                    .foregroundStyle(Theme.danger)
                    .symbolRenderingMode(.monochrome)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 32)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .fill(Theme.chipTint(Theme.danger))
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                    .strokeBorder(Theme.danger.opacity(0.4), lineWidth: 1)
                            }
                    }
                    .accessibilityLabel(
                        "\(model.scanSummary.bots) accounts with high automation signals"
                    )
                }

                CinematicSearchField(
                    text: $keyword,
                    prompt: "Search handle or name",
                    onAdvanced: {
                        draftFilters = filters
                        showFilterSheet = true
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 6)

                if showFollowersSummaryAndControls {
                    SensitivitySegmentedControl(threshold: $botSensitivityRaw)
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                    ScanSummaryStrip(summary: model.scanSummary, filters: $filters)
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

                // Opt-in ghost-verify batch progress, with cancel. Caps
                // at 100/run; only the already-flagged disengaged set.
                if let progress = ghostVerifyProgress, progress.phase != .complete {
                    LoadProgressBannerLite(
                        title: progress.total > 0
                            ? "\(progress.message) (\(progress.current)/\(progress.total))"
                            : progress.message,
                        onCancel: { ghostVerifyTask?.cancel() }
                    )
                }

                // Inline Sort + Select — searchable was replaced with
                // CinematicSearchField so this row never collapses.
                if showFollowersSummaryAndControls {
                    HStack(spacing: 12) {
                        Menu {
                            Picker("Sort by", selection: $filters.sortField) {
                                ForEach(FollowerFilters.SortField.allCases) { field in
                                    Text(field.label).tag(field)
                                }
                            }
                            Divider()
                            Picker("Order", selection: $filters.sortDirection) {
                                Label("Descending", systemImage: "arrow.down")
                                    .tag(FollowerFilters.SortDirection.desc)
                                Label("Ascending", systemImage: "arrow.up")
                                    .tag(FollowerFilters.SortDirection.asc)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: filters.sortDirection == .desc ? "arrow.down" : "arrow.up")
                                    .font(.caption2)
                                Text("Sort")
                                    .font(.footnote.weight(.medium))
                            }
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(Theme.cinematicAccentA)
                        }
                        .accessibilityLabel("Sort: \(filters.sortField.label), \(filters.sortDirection == .desc ? "descending" : "ascending")")
                        .accessibilityHint("Tap to change sort field or direction")

                        if filters.hasActiveFilters {
                            Button {
                                draftFilters = filters
                                showFilterSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                        .font(.footnote)
                                    Text("Filter")
                                        .font(.footnote.weight(.medium))
                                }
                                .foregroundStyle(Theme.cinematicAccentA)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Filters, active")
                        }

                        Spacer(minLength: 8)

                        Button {
                            let mutate = {
                                editMode = editMode.isEditing ? .inactive : .active
                                if !editMode.isEditing { selection.removeAll() }
                            }
                            if reduceMotion { mutate() }
                            else { withAnimation(.snappy) { mutate() } }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: editMode.isEditing
                                      ? "checkmark.circle.fill"
                                      : "checkmark.circle")
                                    .font(.footnote)
                                Text(editMode.isEditing ? "Done" : "Select")
                                    .font(.footnote.weight(.medium))
                            }
                            .foregroundStyle(Theme.cinematicAccentA)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .cinematicChromeStrip()
                }

                if editMode.isEditing {
                    EditActionBar(
                        selectionCount: selection.count,
                        visibleCount: filtered.count,
                        allSelected: !filtered.isEmpty && selection == Set(filtered.map(\.did)),
                        action: .unfollow,
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
                            .buttonStyle(SaturnButton(emphasis: .primaryCinematic))
                    }
                } else if model.accounts.isEmpty && model.isScanning {
                    ScanInFlightView(
                        progress: model.scanProgress,
                        onStop: { model.cancelScan() }
                    )
                } else {
                    List(selection: $selection) {
                        ForEach(filtered) { account in
                            AccountRow(
                                account: account,
                                isExpanded: expandedAccountIDs.contains(account.did),
                                onToggleExpansion: {
                                    let update = {
                                        if expandedAccountIDs.contains(account.did) {
                                            expandedAccountIDs.remove(account.did)
                                        } else {
                                            expandedAccountIDs.insert(account.did)
                                        }
                                    }
                                    if reduceMotion { update() }
                                    else { withAnimation(.snappy) { update() } }
                                }
                            )
                                .listRowBackground(
                                    Theme.cinematicRowFill(selected: selection.contains(account.did))
                                )
                                .cinematicListRows()
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
                                // Non-gesture path for Switch Control /
                                // VoiceOver — same destructive action
                                // reachable without invoking the rotor.
                                .accessibilityAction(named: Text("Unfollow")) {
                                    pendingUnfollow = [account.did]
                                }
                                .accessibilityAction(named: Text("Open account details")) {
                                    detailAccount = account
                                }
                                .tag(account.did)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Patterns")
            .navigationBarTitleDisplayMode(.inline)
            .cinematicListChrome()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityHidden(true)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Scan now") { model.startScan() }
                            .disabled(model.isScanning)
                        if model.isScanning {
                            Button("Stop scan", role: .destructive) { model.cancelScan() }
                        }
                        if featureCleanupPresets {
                            Section("Cleanup presets") {
                                ForEach(CleanupPreset.allCases) { preset in
                                    Button {
                                        filters = preset.filters(botThreshold: botSensitivityRaw)
                                    } label: {
                                        Label(preset.title, systemImage: "sparkles")
                                    }
                                }
                            }
                        }
                        Toggle("Dry-run unfollow (preview only)", isOn: $unfollowDryRun)
                        if !model.accounts.isEmpty {
                            Button {
                                Task { await model.deepAnalyzeEngagement() }
                            } label: {
                                Label("Deep analyze (engaged audience)", systemImage: "heart.text.square")
                            }
                            .disabled(model.isScanning)
                            Button {
                                startGhostVerify()
                            } label: {
                                Label(
                                    "Verify flagged ghosts (\(flaggedGhostCandidateCount))",
                                    systemImage: "moon.stars"
                                )
                            }
                            .disabled(model.isScanning
                                      || ghostVerifyTask != nil
                                      || flaggedGhostCandidateCount == 0)
                            Button {
                                presentAfterMenuDismisses { showExportSheet = true }
                            } label: {
                                Label("Export…", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: {
                        Image(systemName: "scope")
                    }
                    .accessibilityLabel("Scan menu")
                    .accessibilityHint("Start or stop the follower scan, or export results")
                }
                // Select toggle moved inline above the list — toolbar
                // items are hidden when .searchable is focused, which
                // would block the search-then-select flow entirely.
            }
            .environment(\.editMode, $editMode)
            .sheet(item: $detailAccount) { acc in
                AccountDetailView(account: acc, dryRunUnfollow: unfollowDryRun) {
                    Task {
                        let (_, errors) = await model.unfollow(dids: [acc.did], dryRun: unfollowDryRun)
                        await MainActor.run {
                            if unfollowDryRun {
                                if errors.isEmpty {
                                    dryRunBannerMessage =
                                        "Dry run — would unfollow @\(acc.handle). No changes sent to Bluesky."
                                } else {
                                    dryRunBannerMessage = "Dry run — \(errors.joined(separator: "; "))"
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showExportSheet, onDismiss: {
                if let payload = pendingSharePayload {
                    pendingSharePayload = nil
                    sharePayload = payload
                }
            }) {
                ExportSheet(
                    title: "Followers scan",
                    subtitleHeader: model.currentHandle.map { "Signed in as @\($0)" },
                    itemCount: model.accounts.count,
                    jsonProducer: { [accounts = model.accounts, handle = model.currentHandle] in
                        try Exporter.followersJSON(accounts, handle: handle)
                    },
                    csvProducer: { [accounts = model.accounts] in
                        Exporter.followersCSV(accounts)
                    },
                    onShare: { payload in
                        pendingSharePayload = payload
                    }
                )
            }
            .sheet(item: $sharePayload) { payload in
                ActivityView(activityItems: payload.urls)
            }
            .sheet(isPresented: $showFilterSheet) {
                BluescreenFilterSheet(draft: $draftFilters)
                    .onDisappear {
                        // Apply on dismiss only if Apply was tapped —
                        // the sheet only updates draft when Apply runs.
                        // Comparing draft vs filters is the safe way:
                        // if the user tapped Cancel, draft is unchanged
                        // and we don't replace.
                        filters = draftFilters
                    }
            }
            .confirmationDialog(
                unfollowTitle,
                isPresented: unfollowBinding,
                presenting: pendingUnfollow
            ) { batch in
                if unfollowDryRun {
                    Button("Simulate unfollow (\(batch.count))") {
                        Task {
                            dryRunBannerMessage = "Dry run — would unfollow \(batch.count) account(s). No changes sent to Bluesky."
                            pendingUnfollow = nil
                            selection.removeAll()
                        }
                    }
                    .accessibilityLabel("Simulate unfollow for \(batch.count) accounts")
                } else {
                    Button("Unfollow \(batch.count)", role: .destructive) {
                        Task {
                            // Bulk preset path: refuse to act on accounts
                            // whose activity we couldn't read reliably.
                            _ = await model.unfollow(
                                dids: batch, requireKnownActivity: true
                            )
                            selection.removeAll()
                            pendingUnfollow = nil
                        }
                    }
                    .accessibilityLabel("Unfollow \(batch.count) accounts")
                }
                Button("Cancel", role: .cancel) { pendingUnfollow = nil }
            } message: { batch in
                if botSensitivityRaw < 0.5 && batch.count >= 5 {
                    Text("⚠︎ Loose sensitivity is on — this list almost certainly includes real humans. Unfollows \(batch.count) account\(batch.count == 1 ? "" : "s"). They keep their content; you keep yours. Unfollows go through the rate-limit safety net.")
                } else {
                    Text("Removes you as a follower of \(batch.count) account\(batch.count == 1 ? "" : "s"). They keep their content; you keep yours. Unfollows go through the same rate-limit safety net as deletes — bulk runs may pause briefly.")
                }
            }
            .alert("Dry run", isPresented: Binding(
                get: { dryRunBannerMessage != nil },
                set: { if !$0 { dryRunBannerMessage = nil } }
            )) {
                Button("OK", role: .cancel) { dryRunBannerMessage = nil }
            } message: {
                Text(dryRunBannerMessage ?? "")
            }
            .onAppear {
                ColdLaunchSignposts.event("tab_followers_appear")
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
