import SwiftUI
import SkymarshalCore

/// The main authenticated screen: list of own content with searchable
/// keyword + searchScopes content-type segmented control + filter sheet
/// + active-filter chips + swipe-delete + EditMode multi-select +
/// confirmationDialog(presenting:) for bulk delete.
@available(iOS 17, *)
struct ContentListView: View {

    @Environment(AppModel.self) private var model

    @State private var keyword: String = ""
    @State private var scope: ContentType = .all
    @State private var filters: SearchRequest = SearchRequest()
    @State private var showFilterSheet: Bool = false
    @State private var draftFilters: SearchRequest = SearchRequest()
    @State private var pendingDeletion: [String]? = nil
    @State private var selection: Set<String> = []
    @State private var editMode: EditMode = .inactive
    @State private var detailItem: ContentItem? = nil

    private var effectiveRequest: SearchRequest {
        var req = filters
        let k = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        req.keyword = k.isEmpty ? nil : k
        req.contentTypes = scope == .all ? nil : [scope]
        return req
    }

    private var filteredItems: [ContentItem] {
        effectiveRequest.apply(to: model.items)
    }

    private var allFilteredSelected: Bool {
        !filteredItems.isEmpty && selection == Set(filteredItems.map(\.uri))
    }

    private func pruneSelectionToVisible() {
        guard editMode.isEditing, !selection.isEmpty else { return }
        let visible = Set(filteredItems.map(\.uri))
        selection.formIntersection(visible)
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            VStack(spacing: 0) {
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
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .accessibilityLabel(editMode.isEditing ? "Exit selection mode" : "Enter selection mode")
                }
                .padding(.horizontal)
                .padding(.top, 2)
                .padding(.bottom, 4)

                ActiveFilterChips(filters: $filters)

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
                            let all = Set(filteredItems.map(\.uri))
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
                                    selection.contains(item.uri)
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
                                        pendingDeletion = [item.uri]
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .tag(item.uri)
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
                        Button("Sign out", role: .destructive) {
                            Task { await model.logout() }
                        }
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        draftFilters = filters
                        showFilterSheet = true
                    } label: {
                        Image(systemName: filters.hasActiveFilters
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
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
            // `selection` still holds the 47 URIs but the user can't
            // see them — they could bulk-delete content they didn't
            // intend. Drop any selected URI that's no longer visible
            // under the new filter.
            .onChange(of: keyword) { pruneSelectionToVisible() }
            .onChange(of: scope) { pruneSelectionToVisible() }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(draft: $draftFilters)
                    .onDisappear {
                        // Apply on dismiss only if the apply button was hit
                        // — FilterSheet mutates its own binding, so we copy.
                        filters = draftFilters
                    }
            }
            .sheet(item: $detailItem) { item in
                PostDetailView(item: item) {
                    Task {
                        _ = await model.delete(uris: [item.uri])
                    }
                }
            }
            .confirmationDialog(
                deletionTitle,
                isPresented: deletionBinding,
                presenting: pendingDeletion
            ) { batch in
                Button("Delete \(batch.count)", role: .destructive) {
                    Task {
                        let result = await model.delete(uris: batch)
                        selection.removeAll()
                        pendingDeletion = nil
                        if !result.errors.isEmpty {
                            // For MVP, errors surface via model.errorMessage
                            // through the underlying service if individual
                            // calls fail; bulk-error UI is a follow-on.
                        }
                    }
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: { batch in
                Text("\(batch.count) item\(batch.count == 1 ? "" : "s") leaves the building. There's no carry-on for this — deletion is permanent.")
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
        return "Delete \(count) item\(count == 1 ? "" : "s")?"
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
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
            Capsule()
                .fill(item.contentType.stripeColor)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: item.contentType.sfSymbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(item.contentType.stripeColor)
                    Text(item.contentType.label.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(0.4)
                        .foregroundStyle(.secondary)
                    if let date = item.createdAt {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(date, style: .date)
                            .font(.caption2)
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
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 1)
            }
        }
        .padding(.vertical, 6)
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
                .font(.system(size: 9))
            Text("\(score)")
                .font(.caption2.weight(.semibold).monospacedDigit())
        }
        .foregroundStyle(.tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.tint.opacity(0.12), in: .capsule)
    }
}
