import SwiftUI
import UIKit
import SkymarshalCore

/// The main authenticated screen: list of own content with searchable
/// keyword + searchScopes content-type segmented control + filter sheet
/// + active-filter chips + swipe-delete + EditMode multi-select +
/// confirmationDialog(presenting:) for bulk delete.
@available(iOS 17, *)
struct ContentListView: View {

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { ReduceMotion.shouldReduce(systemReduceMotion: systemReduceMotion) }

    @State private var keyword: String = ""
    /// Default to posts + replies — most archives are dominated by likes,
    /// and likes are the noise people least want on landing. Multi-select:
    /// the chip row toggles each type and "All" adds the rest back.
    @State private var selectedTypes: Set<ContentType> = [.posts, .replies]
    @State private var filters: SearchRequest = SearchRequest()
    @State private var showFilterSheet: Bool = false
    @State private var draftFilters: SearchRequest = SearchRequest()
    @State private var pendingDeletion: [String]? = nil
    @State private var deletePreflight: DeletePreflightSummary?
    @State private var selection: Set<String> = []
    @State private var editMode: EditMode = .inactive
    @State private var detailItem: ContentItem? = nil
    @State private var showAbout: Bool = false
    @State private var showInsights: Bool = false
    @State private var sortOrder: ContentSortOrder = .newestCreated
    @State private var savedPresets: [SavedSearchPresetRecord] = []
    @State private var showSavePresetAlert: Bool = false
    @State private var newPresetName: String = ""

    @AppStorage(FeatureFlags.analyticsInsightsKey) private var featureAnalytics: Bool = true
    @AppStorage(FeatureFlags.savedSearchPresetsKey) private var featureSavedSearch: Bool = true
    @AppStorage(FeatureFlags.contentPowerToolsExpandedKey) private var contentPowerToolsExpanded: Bool = false

    @State private var showBackgroundGraphRefreshNote: Bool = false

    /// Export sheet presentation. Replaces the previous Menu-embedded
    /// `ShareLink` + `Transferable` chain that crashed on iOS 26 with
    /// `EXC_GUARD` / `XPC_EXIT_REASON_FAULT` inside `BSXPCService…` when
    /// the share sheet tried to materialize a Transferable from the
    /// toolbar Menu. Now: tap "Export" → open `ExportSheet` → async
    /// prepare on a detached Task → set `sharePayload` → present
    /// `ActivityView` (UIActivityViewController). Sidesteps the fault
    /// path entirely.
    @State private var showExportSheet: Bool = false
    @State private var sharePayload: SharePayload?
    /// Buffered share payload — set by `ExportSheet`'s `onShare`
    /// callback, then promoted to `sharePayload` inside the export
    /// sheet's `.onDismiss` so we never have two sheets racing in the
    /// same MainActor tick. iPad form sheets in particular dropped the
    /// second presentation when both bindings flipped together.
    @State private var pendingSharePayload: SharePayload?
    /// In-flight delete preflight — cancelled when `pendingDeletion` changes
    /// so a stale result cannot land in a new confirmation dialog.
    @State private var deletePreflightTask: Task<Void, Never>?

    /// Threshold for routing through TypedConfirmSheet instead of the
    /// standard confirmationDialog. Set high enough that single-post and
    /// small-batch deletes stay fast.
    private static let typedConfirmThreshold = 100

    private var effectiveRequest: SearchRequest {
        var req = filters
        let k = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        req.keyword = k.isEmpty ? nil : k
        // A full set (all four) means "no content-type filter" — let it pass
        // as nil so downstream treats it as unfiltered.
        req.contentTypes = selectedTypes.isSuperset(of: ContentType.selectable) ? nil : selectedTypes
        return req
    }

    private var filteredItems: [ContentItem] {
        let base = effectiveRequest.apply(to: model.items)
        return sortOrder.sort(Array(base))
    }

    /// Quick stats for the **filtered** result set.
    private var filteredAverageEngagement: Double {
        let xs = filteredItems
        guard !xs.isEmpty else { return 0 }
        return xs.map(\.engagementScore).reduce(0, +) / Double(xs.count)
    }

    private var allFilteredSelected: Bool {
        !filteredItems.isEmpty && selection == Set(filteredItems.map(\.id))
    }

    private var loadProgressAccessibilityLabel: String {
        var parts = ["\(filteredItems.count) items visible"]
        if let progress = model.loadProgress, !progress.isComplete {
            parts.append("\(model.items.count) loaded so far, scan in progress")
        }
        parts.append("average engagement \(Int(filteredAverageEngagement))")
        return parts.joined(separator: ", ")
    }

    private func pruneSelectionToVisible() {
        guard editMode.isEditing, !selection.isEmpty else { return }
        let before = selection.count
        let visible = Set(filteredItems.map(\.id))
        selection.formIntersection(visible)
        let removed = before - selection.count
        // VoiceOver / Switch Control users won't see the count change
        // in the EditActionBar — post a live-region announcement so
        // the drop is audible. WCAG 4.1.3 Status Messages.
        if removed > 0 {
            UIAccessibility.post(
                notification: .announcement,
                argument: "\(removed) items removed from selection — outside the new filter"
            )
        }
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            VStack(spacing: 0) {
                if showBackgroundGraphRefreshNote {
                    Text("Scope summaries were refreshed in the background from your saved archive.")
                        .font(.caption)
                        .foregroundStyle(Theme.info)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Theme.info.opacity(0.12))
                        .accessibilityIdentifier("content_bg_scope_refresh_note")
                }

                CinematicScreenHeader(
                    title: "Content",
                    subtitle: model.currentHandle.map { "@\($0)" } ?? "YOUR BLUESKY ARCHIVE"
                )

                // Make Content: search well → type chips → sort/select.
                CinematicSearchField(
                    text: $keyword,
                    prompt: "Search posts, replies, likes…",
                    onAdvanced: {
                        draftFilters = filters
                        showFilterSheet = true
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 6)

                // Pill-chip row — lifted from skymarshal-web's
                // ContentManagement pattern. Each chip carries its
                // category count, so a glance tells you "9,832 Posts,
                // 856 Replies" without opening anything.
                TypeChipsRow(selected: $selectedTypes, counts: model.summary)

                // Inline Sort + Select — always reachable (custom search
                // no longer collapses the toolbar the way `.searchable` did).
                HStack(spacing: 12) {
                    Menu {
                        Picker("Sort", selection: $sortOrder) {
                            ForEach(ContentSortOrder.allCases) { order in
                                Text(order.label).tag(order)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.footnote)
                            Text("Sort")
                                .font(.footnote.weight(.medium))
                        }
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(Theme.cinematicAccentA)
                    }
                    .accessibilityLabel("Sort: \(sortOrder.label)")
                    .accessibilityHint("Tap to change sort order")

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
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.cinematicAccentA)
                    .accessibilityLabel(editMode.isEditing ? "Exit selection mode" : "Enter selection mode")
                }
                .padding(.horizontal)
                .padding(.top, 2)
                .padding(.bottom, 4)
                .cinematicChromeStrip()

                ActiveFilterChips(filters: $filters)

                if let progress = model.loadProgress, !progress.isComplete {
                    Text("Filters search \(model.items.count.formatted()) loaded items — \(progress.phase.rawValue.lowercased()) still running.")
                        .font(.caption)
                        .foregroundStyle(Theme.caution)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .accessibilityLabel("Archive scan in progress. \(model.items.count) items loaded. Filters apply to loaded items only.")
                }

                if contentPowerToolsExpanded && !filteredItems.isEmpty {
                    HStack {
                        Text("\(filteredItems.count) visible")
                        if let progress = model.loadProgress, !progress.isComplete {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("of \(model.items.count) loaded")
                                .foregroundStyle(Theme.caution)
                        }
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(String(format: "avg engagement %.0f", filteredAverageEngagement))
                    }
                    .font(Theme.Display.metricRegular(.caption))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(loadProgressAccessibilityLabel)
                }

                // "Last scanned 3h ago" — only when no live load is
                // running and we have a hydrated snapshot to credit.
                if let lastScanned = model.lastContentScannedAt,
                   model.loadProgress == nil,
                   !model.isLoading {
                    LastScannedBanner(lastScannedAt: lastScanned) {
                        model.startMostRecentContentRefresh()
                    }
                }

                if let progress = model.loadProgress, !progress.isComplete {
                    LoadProgressBanner(progress: progress) {
                        model.cancelLoad()
                    }
                }

                if model.isDeleting, let deleteProgress = model.deleteProgress {
                    DeleteProgressBanner(
                        deleted: deleteProgress.deleted,
                        total: deleteProgress.total,
                        rateLimitWaitSeconds: model.deleteRateLimitWaitSeconds
                    ) {
                        model.cancelDelete()
                    }
                }

                if model.archiveTruncated {
                    Label {
                        Text("Showing the most recent \(ContentService.maxPagesPerEndpoint * 100, format: .number) items per category. Older items exist on Bluesky beyond this view.")
                            .font(Theme.Mono.caption(11))
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Theme.caution)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cinematicChromeStrip()
                    .accessibilityElement(children: .combine)
                }

                if editMode.isEditing {
                    EditActionBar(
                        selectionCount: selection.count,
                        visibleCount: filteredItems.count,
                        allSelected: allFilteredSelected,
                        onToggleAll: {
                            let all = Set(filteredItems.map(\.id))
                            selection = allFilteredSelected ? [] : all
                        },
                        onDelete: { pendingDeletion = Array(selection) }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                List(selection: $selection) {
                    if model.items.isEmpty && !model.isLoading {
                        ContentUnavailableView(
                            "Nothing on the radar yet",
                            systemImage: "scope",
                            description: Text("Pull down to scan your Bluesky archive.")
                        )
                    } else if filteredItems.isEmpty {
                        ContentUnavailableView(
                            "No matches in range",
                            systemImage: "binoculars",
                            description: Text("Try a wider net — clear a filter or change the type tab.")
                        )
                    } else {
                        ForEach(filteredItems) { item in
                            ContentRow(item: item)
                                .listRowBackground(
                                    Theme.cinematicRowFill(selected: selection.contains(item.id))
                                )
                                .cinematicListRows()
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !editMode.isEditing {
                                        detailItem = item
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        pendingDeletion = [item.id]
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                // Non-gesture path so Switch Control /
                                // VoiceOver users reach the same delete
                                // action without invoking the rotor.
                                .accessibilityAction(named: Text("Delete")) {
                                    pendingDeletion = [item.id]
                                }
                                // The combined row element flattens the
                                // tap target — re-expose open-details so
                                // AT users keep the same path sighted
                                // users get from a plain tap.
                                .accessibilityAction(named: Text("Open post details")) {
                                    if !editMode.isEditing {
                                        detailItem = item
                                    }
                                }
                                .tag(item.id)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await model.refreshMostRecentContent()
                }
            }
            .navigationTitle("Content")
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
                        Button("Refresh recent") {
                            model.startMostRecentContentRefresh()
                        }
                        Button("Refresh full archive") {
                            model.startLoad(forceRefresh: true)
                        }
                        Button {
                            presentAfterMenuDismisses { showExportSheet = true }
                        } label: {
                            Label("Export…", systemImage: "square.and.arrow.up")
                        }
                        .disabled(model.items.isEmpty)
                        Button {
                            presentAfterMenuDismisses { showAbout = true }
                        } label: {
                            Label("About Skymarshal", systemImage: "info.circle")
                        }
                        Button("Sign out", role: .destructive) {
                            Task { await model.logout() }
                        }
                    } label: {
                        Image(systemName: "person.circle")
                    }
                    .accessibilityLabel("Account menu")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if featureAnalytics {
                            Button {
                                presentAfterMenuDismisses { showInsights = true }
                            } label: {
                                Label("Insights…", systemImage: "chart.bar.xaxis")
                            }
                        }

                        if featureSavedSearch {
                            Section("Saved searches") {
                                Button {
                                    presentAfterMenuDismisses {
                                        newPresetName = ""
                                        showSavePresetAlert = true
                                    }
                                } label: {
                                    Label("Save current search…", systemImage: "square.and.arrow.down")
                                }
                                if savedPresets.isEmpty {
                                    Text("No saved searches yet")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(savedPresets, id: \.id) { preset in
                                        Menu {
                                            Button("Apply") { applyPreset(preset) }
                                            Button("Delete", role: .destructive) {
                                                deletePreset(id: preset.id)
                                            }
                                        } label: {
                                            Text(preset.name)
                                        }
                                    }
                                }
                            }
                        }

                        Section {
                            Toggle("Full Content tools", isOn: $contentPowerToolsExpanded)
                        } footer: {
                            Text("When on, shows the result stats strip (count and average engagement). Sort and Filter sit above the list.")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "ellipsis.circle")
                            Text("More")
                                .font(.footnote.weight(.medium))
                        }
                    }
                    .accessibilityLabel("More — insights, saved searches, display options")
                }
                // EditButton intentionally removed — the inline Select
                // toggle in the picker row handles entering/exiting
                // EditMode and remains reachable while .searchable is
                // focused. Bulk delete lives in the inline EditActionBar
                // above the List, not the bottom toolbar (keyboard
                // occlusion).
            }
            .environment(\.editMode, $editMode)
            // Safety pin per technical-committee Greybeard/Safety verdict:
            // if the user types "Trump" → 47 results → Edit → Select All →
            // then clears search, keyword resets to "" and the visible
            // list jumps to thousands. Without this guard, `selection`
            // still holds the 47 item IDs but the user can't see them —
            // they could bulk-delete content they didn't intend. Drop any
            // selected item that's no longer visible under the new filter.
            .onChange(of: keyword) { pruneSelectionToVisible() }
            .onChange(of: selectedTypes) { pruneSelectionToVisible() }
            .onChange(of: filters) { _, _ in pruneSelectionToVisible() }
            .onChange(of: sortOrder) { _, _ in pruneSelectionToVisible() }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(
                    draft: $draftFilters,
                    keyword: $keyword,
                    selectedTypes: $selectedTypes,
                    items: model.items,
                    onApply: { filters = draftFilters }
                )
            }
            .sheet(item: $detailItem) { item in
                PostDetailView(item: item) {
                    Task {
                        _ = await model.delete(itemIDs: [item.id])
                    }
                }
            }
            .sheet(isPresented: $showAbout) {
                AboutView(presentation: .sheet)
            }
            .sheet(isPresented: $showInsights) {
                AnalyticsInsightsView(items: model.items)
                    .environment(model)
            }
            .sheet(isPresented: $showExportSheet, onDismiss: {
                if let payload = pendingSharePayload {
                    pendingSharePayload = nil
                    sharePayload = payload
                }
            }) {
                ExportSheet(
                    title: "My content",
                    subtitleHeader: model.currentHandle.map { "Signed in as @\($0)" },
                    itemCount: model.items.count,
                    jsonProducer: { [items = model.items, handle = model.currentHandle, did = model.currentDid] in
                        try Exporter.contentJSON(items, handle: handle, did: did)
                    },
                    csvProducer: { [items = model.items] in
                        Exporter.contentCSV(items)
                    },
                    onShare: { payload in
                        pendingSharePayload = payload
                    }
                )
            }
            .sheet(item: $sharePayload) { payload in
                ActivityView(activityItems: payload.urls)
            }
            .alert("Save search", isPresented: $showSavePresetAlert) {
                TextField("Preset name", text: $newPresetName)
                Button("Save") { saveCurrentPreset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Stores keyword, type tab, filters, and sort for this handle.")
            }
            .alert(
                "Interrupted delete",
                isPresented: Binding(
                    get: { model.deleteInterruptionNotice != nil },
                    set: { newValue in
                        if !newValue { model.dismissDeleteInterruptionRecovery() }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    model.dismissDeleteInterruptionRecovery()
                }
            } message: {
                Text(model.deleteInterruptionNotice ?? "")
            }
            .onAppear {
                ColdLaunchSignposts.event("tab_content_appear")
                reloadSavedPresets()
                if ProcessInfo.processInfo.environment["UITEST_FORCE_BG_SCOPE_NOTE"] == "1" {
                    showBackgroundGraphRefreshNote = true
                } else if UserDefaults.standard.bool(forKey: BackgroundGraphRefreshNotice.pendingUserDefaultsKey) {
                    showBackgroundGraphRefreshNote = true
                    UserDefaults.standard.set(false, forKey: BackgroundGraphRefreshNotice.pendingUserDefaultsKey)
                }
            }
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-uitestOpenInsights") else { return }
                try? await Task.sleep(nanoseconds: 150_000_000)
                showInsights = true
            }
            .onChange(of: featureSavedSearch) { _, _ in
                reloadSavedPresets()
            }
            .onChange(of: pendingDeletion) { _, newVal in
                deletePreflightTask?.cancel()
                deletePreflightTask = nil
                guard let ids = newVal, !ids.isEmpty else {
                    deletePreflight = nil
                    return
                }
                deletePreflightTask = Task {
                    let s = await model.preflightDelete(itemIDs: ids)
                    guard !Task.isCancelled else { return }
                    await MainActor.run { deletePreflight = s }
                }
            }
            // Small batches (< threshold) go through the standard
            // confirmationDialog. Large batches go through
            // TypedConfirmSheet — see the .sheet binding below.
            .confirmationDialog(
                deletionTitle,
                isPresented: smallDeletionBinding,
                presenting: pendingDeletion
            ) { batch in
                Button("Delete \(deletePreflight?.totalCount ?? batch.count)", role: .destructive) {
                    Task { await performDeletion(batch) }
                }
                .accessibilityLabel("Delete \(deletePreflight?.totalCount ?? batch.count) posts permanently")
                .accessibilityHint("This action cannot be undone")
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: { batch in
                deletionConfirmationMessage(selectedCount: batch.count)
            }
            .sheet(isPresented: bigDeletionBinding) {
                if let batch = pendingDeletion {
                    TypedConfirmSheet(
                        count: batch.count,
                        preflight: deletePreflight,
                        onConfirm: { Task { await performDeletion(batch) } },
                        onCancel: { pendingDeletion = nil }
                    )
                }
            }
            .overlay {
                if model.isLoading && model.items.isEmpty && model.loadProgress == nil {
                    ProgressView("Boarding…")
                        .padding()
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                }
            }
        }
    }

    private var deletionTitle: String {
        let count = pendingDeletion?.count ?? 0
        return "Delete \(count) post\(count == 1 ? "" : "s")?"
    }

    /// Active only when there's a pending deletion under the
    /// typed-confirm threshold. The standard confirmationDialog
    /// handles these.
    private var smallDeletionBinding: Binding<Bool> {
        Binding(
            get: { (pendingDeletion?.count ?? 0) > 0 &&
                   (pendingDeletion?.count ?? 0) < Self.typedConfirmThreshold },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    /// Active only when the pending deletion is at or above the
    /// threshold — routes to TypedConfirmSheet for the intent gate.
    private var bigDeletionBinding: Binding<Bool> {
        Binding(
            get: { (pendingDeletion?.count ?? 0) >= Self.typedConfirmThreshold },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private func deletionConfirmationMessage(selectedCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let p = deletePreflight {
                Text("Bluesky records to delete: \(p.totalCount) (of \(selectedCount) selected).")
                    .font(.body)
                if !p.resolutionErrors.isEmpty {
                    Text("\(p.resolutionErrors.count) selected item(s) have no deletable record (for example likes missing a viewer delete URI).")
                        .font(.caption)
                        .foregroundStyle(Theme.caution)
                }
            } else {
                Text("Checking delete scope…")
                    .foregroundStyle(.secondary)
            }
            Text("This permanently removes matching records from Bluesky. It cannot be undone.")
                .font(.callout)
        }
    }

    private func performDeletion(_ batch: [String]) async {
        _ = await model.delete(itemIDs: batch)
        selection.removeAll()
        pendingDeletion = nil
        deletePreflight = nil
    }

    private func reloadSavedPresets() {
        guard featureSavedSearch else {
            savedPresets = []
            return
        }
        savedPresets = (try? model.fetchSavedSearchPresets()) ?? []
    }

    private func saveCurrentPreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            try model.saveSearchPreset(
                name: name,
                request: effectiveRequest,
                sort: sortOrder
            )
            reloadSavedPresets()
        } catch {
            // rare persistence failure — silent; power users can retry
        }
    }

    private func applyPreset(_ preset: SavedSearchPresetRecord) {
        do {
            let req = try preset.decodedRequest()
            filters = req
            sortOrder = preset.contentSortOrder
            keyword = req.keyword ?? ""
            let presetTypes = req.contentTypes?.subtracting([.all]) ?? []
            selectedTypes = presetTypes.isEmpty ? Set(ContentType.selectable) : presetTypes
            pruneSelectionToVisible()
        } catch {
            // decode failure — ignore
        }
    }

    private func deletePreset(id: UUID) {
        try? model.deleteSavedSearchPreset(id: id)
        reloadSavedPresets()
    }
}

@available(iOS 17, *)
struct ContentRow: View {
    let item: ContentItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 3pt leading hairline — Things-3-style category cue. Subtle
            // enough not to compete with text; visible enough to give the
            // eye a rhythm when scrolling through hundreds of rows.
            // The stripe encodes content type by color — paired with the
            // SF Symbol below so VoiceOver and colorblind users see the
            // same category cue.
            Capsule()
                .fill(item.contentType.stripeColor)
                .frame(width: 3)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: item.contentType.sfSymbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(item.contentType.stripeColor)
                    Text(item.contentType.label.uppercased())
                        .font(Theme.Mono.kicker(11))
                        .foregroundStyle(.secondary)
                    if let date = item.createdAt {
                        Text("·")
                            .font(Theme.Mono.caption(11))
                            .foregroundStyle(.tertiary)
                        Text(date, style: .date)
                            .font(Theme.Mono.caption(11))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if item.engagementScore > 0 {
                        EngagementBadge(score: Int(item.engagementScore))
                    }
                }

                if let text = item.text, !text.isEmpty {
                    Text(text)
                        .font(.callout)
                        .lineLimit(3)
                }

                if !item.media.isEmpty {
                    MediaThumbnailRow(media: item.media)
                }

                HStack(spacing: 14) {
                    metric(count: item.likeCount, symbol: "heart")
                    metric(count: item.repostCount, symbol: "arrow.2.squarepath")
                    metric(count: item.replyCount, symbol: "bubble.left")
                }
                .font(Theme.Mono.tabular(11))
                .foregroundStyle(.secondary)
                .padding(.top, 1)
            }
        }
        .padding(.vertical, 6)
        .frame(minHeight: 56)
        // One swipe stop per row for VoiceOver / Switch Control instead
        // of six. The composed label carries type, date, body, and
        // engagement in reading order; interactive paths (open, delete,
        // select) are re-exposed by the parent list as accessibility
        // actions since combining flattens nested elements.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    /// Plain-language summary of the whole row. Numbers become words
    /// ("12 likes"), long post bodies truncate at ~120 characters.
    private var rowAccessibilityLabel: String {
        var parts: [String] = [item.contentType.label]
        if let date = item.createdAt {
            parts.append(date.formatted(date: .abbreviated, time: .omitted))
        }
        if let text = item.text, !text.isEmpty {
            parts.append(text.count > 120 ? "\(text.prefix(120))…" : text)
        }
        if !item.media.isEmpty {
            parts.append("\(item.media.count) media attachment\(item.media.count == 1 ? "" : "s")")
        }
        parts.append("\(item.likeCount) like\(item.likeCount == 1 ? "" : "s")")
        parts.append("\(item.repostCount) repost\(item.repostCount == 1 ? "" : "s")")
        parts.append("\(item.replyCount) repl\(item.replyCount == 1 ? "y" : "ies")")
        if item.engagementScore > 0 {
            parts.append("engagement score \(Int(item.engagementScore))")
        }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func metric(count: Int, symbol: String) -> some View {
        Label("\(count)", systemImage: symbol)
            .labelStyle(.titleAndIcon)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(count == 0 ? .tertiary : .secondary)
    }
}

/// The number is the point of a "find dead threads / find bangers"
/// workflow; render it as a deliberate badge, not floating text.
@available(iOS 17, *)
struct EngagementBadge: View {
    let score: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(Theme.Mono.kicker(11))
                .symbolRenderingMode(.monochrome)
                .accessibilityHidden(true)
            Text("\(score)")
                .font(Theme.Mono.tabular(11))
        }
        .foregroundStyle(Theme.cinematicAccentA)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(Theme.cinematicAccentA.opacity(0.18))
        )
        .accessibilityLabel("Engagement score \(score)")
    }
}
