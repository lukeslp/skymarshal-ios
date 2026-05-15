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
    @State private var scope: ContentType = .all
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
    @AppStorage(FeatureFlags.advancedSearchGrammarKey) private var featureAdvancedSearch: Bool = false
    @AppStorage(FeatureFlags.contentPowerToolsExpandedKey) private var contentPowerToolsExpanded: Bool = false

    @State private var showAdvancedSearch: Bool = false
    @State private var showBackgroundGraphRefreshNote: Bool = false

    /// Remember-last-choice for the Export submenu. The format the
    /// user picked previously shows first; the alternative shows
    /// second. Both are always reachable — no setting is buried.
    @AppStorage("sm.lastExportFormat") private var lastExportFormat: String = "json"

    /// Threshold for routing through TypedConfirmSheet instead of the
    /// standard confirmationDialog. Set high enough that single-post and
    /// small-batch deletes stay fast.
    private static let typedConfirmThreshold = 100

    private var effectiveRequest: SearchRequest {
        var req = filters
        let k = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        req.keyword = k.isEmpty ? nil : k
        req.contentTypes = scope == .all ? nil : [scope]
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

    /// Build a JSON ExportPayload synchronously for the share menu.
    /// Throws are unlikely (Encodable on plain structs) — fall back to
    /// an empty CSV-shaped payload if encoding fails so the share sheet
    /// never appears with a stale file.
    private func makeContentJSON() -> ExportPayload {
        do {
            return try Exporter.contentJSON(model.items, handle: model.currentHandle, did: model.currentDid)
        } catch {
            return Exporter.contentCSV([])
        }
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
                // Pill-chip row — lifted from skymarshal-web's
                // ContentManagement pattern. Each chip carries its
                // category count, so a glance tells you "9,832 Posts,
                // 856 Replies" without opening anything.
                TypeChipsRow(scope: $scope, counts: model.summary)

                HStack {
                    if let handle = model.currentHandle {
                        Text(handle)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
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
                    .foregroundStyle(.tint)
                    .accessibilityLabel(editMode.isEditing ? "Exit selection mode" : "Enter selection mode")
                }
                .padding(.horizontal)
                .padding(.top, 2)
                .padding(.bottom, 4)

                ActiveFilterChips(filters: $filters)

                if contentPowerToolsExpanded && !filteredItems.isEmpty {
                    HStack {
                        Text("\(filteredItems.count) visible")
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(String(format: "avg engagement %.0f", filteredAverageEngagement))
                    }
                    .font(Theme.Mono.tabular(11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(filteredItems.count) items visible, average engagement \(Int(filteredAverageEngagement))")
                }

                // "Last scanned 3h ago" — only when no live load is
                // running and we have a hydrated snapshot to credit.
                if let lastScanned = model.lastContentScannedAt,
                   model.loadProgress == nil,
                   !model.isLoading {
                    LastScannedBanner(lastScannedAt: lastScanned) {
                        model.startLoad(forceRefresh: true)
                    }
                }

                if let progress = model.loadProgress, !progress.isComplete {
                    LoadProgressBanner(progress: progress) {
                        model.cancelLoad()
                    }
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
                                    selection.contains(item.id)
                                    ? Color.accentColor.opacity(0.08)
                                    : Color(.systemBackground)
                                )
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
                                .tag(item.id)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    model.startLoad(forceRefresh: true)
                }
            }
            .navigationTitle("My Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Refresh") {
                            model.startLoad(forceRefresh: true)
                        }
                        Section("Export") {
                            // Last-chosen format shows first. Sheet
                            // dismissal can't be observed cleanly from
                            // ShareLink, so we write the choice on tap
                            // via simultaneousGesture — fires whether
                            // the share completes or is dismissed.
                            let jsonLink = ShareLink(
                                item: ExportItem(payload: makeContentJSON()),
                                preview: SharePreview(
                                    "Skymarshal — content (JSON)",
                                    image: Image(systemName: "doc.text")
                                )
                            ) {
                                Label("As JSON", systemImage: "curlybraces")
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                lastExportFormat = "json"
                            })

                            let csvLink = ShareLink(
                                item: ExportItem(payload: Exporter.contentCSV(model.items)),
                                preview: SharePreview(
                                    "Skymarshal — content (CSV)",
                                    image: Image(systemName: "tablecells")
                                )
                            ) {
                                Label("As CSV", systemImage: "tablecells")
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                lastExportFormat = "csv"
                            })

                            if lastExportFormat == "csv" {
                                csvLink
                                jsonLink
                            } else {
                                jsonLink
                                csvLink
                            }
                        }
                        Button {
                            showAbout = true
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
                        Button {
                            draftFilters = filters
                            showFilterSheet = true
                        } label: {
                            Label("Filters…", systemImage: filters.hasActiveFilters
                                  ? "line.3.horizontal.decrease.circle.fill"
                                  : "line.3.horizontal.decrease.circle")
                        }

                        Section("Sort") {
                            Picker("Sort", selection: $sortOrder) {
                                ForEach(ContentSortOrder.allCases) { order in
                                    Text(order.label).tag(order)
                                }
                            }
                            .pickerStyle(.inline)
                        }

                        if featureAnalytics {
                            Button {
                                showInsights = true
                            } label: {
                                Label("Insights…", systemImage: "chart.bar.xaxis")
                            }
                        }

                        if featureAdvancedSearch {
                            Button {
                                showAdvancedSearch = true
                            } label: {
                                Label("Advanced search…", systemImage: "text.magnifyingglass")
                            }
                        }

                        if featureSavedSearch {
                            Section("Saved searches") {
                                Button {
                                    newPresetName = ""
                                    showSavePresetAlert = true
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
                            Text("When on, shows the result stats strip (count and average engagement). Filter chips still appear whenever filters are active.")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("View options — filters, sort, insights, saved searches, display")
                }
                // EditButton intentionally removed — the inline Select
                // toggle in the picker row handles entering/exiting
                // EditMode and remains reachable while .searchable is
                // focused. Bulk delete lives in the inline EditActionBar
                // above the List, not the bottom toolbar (keyboard
                // occlusion).
            }
            .environment(\.editMode, $editMode)
            .searchable(text: $keyword, placement: .navigationBarDrawer(displayMode: .always))
            // Safety pin per technical-committee Greybeard/Safety verdict:
            // if the user types "Trump" → 47 results → Edit → Select All →
            // then mis-taps the search clear-X, keyword resets to "" and
            // the visible list jumps to thousands. Without this guard,
            // `selection` still holds the 47 item IDs but the user can't
            // see them — they could bulk-delete content they didn't
            // intend. Drop any selected item that's no longer visible
            // under the new filter.
            .onChange(of: keyword) { pruneSelectionToVisible() }
            .onChange(of: scope) { pruneSelectionToVisible() }
            .onChange(of: filters) { _, _ in pruneSelectionToVisible() }
            .onChange(of: sortOrder) { _, _ in pruneSelectionToVisible() }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(draft: $draftFilters)
                    .onDisappear {
                        // Apply on dismiss only if the apply button was hit
                        // — FilterSheet mutates its own binding, so we copy.
                        filters = draftFilters
                    }
            }
            .sheet(isPresented: $showAdvancedSearch) {
                AdvancedSearchBuilderView(keyword: $keyword, filters: $filters)
            }
            .sheet(item: $detailItem) { item in
                PostDetailView(item: item) {
                    Task {
                        _ = await model.delete(itemIDs: [item.id])
                    }
                }
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showInsights) {
                AnalyticsInsightsView(items: model.items)
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
                guard let ids = newVal, !ids.isEmpty else {
                    deletePreflight = nil
                    return
                }
                Task {
                    let s = await model.preflightDelete(itemIDs: ids)
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
            if let types = req.contentTypes {
                if types.count == 1, let only = types.first, only != .all {
                    scope = only
                } else {
                    scope = .all
                }
            } else {
                scope = .all
            }
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
                        .tracking(0.15)
                        .foregroundStyle(.secondary)
                    if let date = item.createdAt {
                        Text("·")
                            .font(Theme.Mono.caption(11))
                            .foregroundStyle(.tertiary)
                        Text(date, style: .date)
                            .font(Theme.Mono.tabular(11))
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
        .foregroundStyle(.tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(.tint.opacity(0.18))
        )
        .accessibilityLabel("Engagement score \(score)")
    }
}
