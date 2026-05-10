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
                Picker("Type", selection: $scope) {
                    ForEach(ContentType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 6)

                ActiveFilterChips(filters: $filters)

                if let progress = model.loadProgress, !progress.isComplete {
                    LoadProgressBanner(progress: progress) {
                        model.cancelLoad()
                    }
                }

                List(selection: $selection) {
                    if model.items.isEmpty && !model.isLoading {
                        ContentUnavailableView(
                            "No content loaded yet",
                            systemImage: "tray",
                            description: Text("Pull to refresh or tap the refresh button.")
                        )
                    } else if filteredItems.isEmpty {
                        ContentUnavailableView.search(text: keyword)
                    } else {
                        ForEach(filteredItems) { item in
                            ContentRow(item: item)
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
            .navigationTitle(model.currentHandle ?? "Skymarshal")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if editMode.isEditing {
                        // Far from the search-bar clear-X (which sits in
                        // the navigationBarDrawer below). Toggling
                        // against `filteredItems` makes the search-then-
                        // bulk-act flow one tap. Per technical-committee
                        // architect verdict.
                        Button(allFilteredSelected ? "Deselect All" : "Select All") {
                            let all = Set(filteredItems.map(\.uri))
                            selection = allFilteredSelected ? [] : all
                        }
                    } else {
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
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                if editMode.isEditing && !selection.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            pendingDeletion = Array(selection)
                        } label: {
                            Label("Delete \(selection.count)", systemImage: "trash")
                        }
                    }
                }
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
                Text("This permanently removes \(batch.count) item\(batch.count == 1 ? "" : "s") from your Bluesky account. This cannot be undone.")
            }
            .overlay {
                if model.isLoading && model.items.isEmpty && model.loadProgress == nil {
                    ProgressView("Connecting to Bluesky…")
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: typeIcon)
                    .foregroundStyle(.tint)
                    .font(.caption)
                Text(item.contentType.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if let date = item.createdAt {
                    Text(date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if item.engagementScore > 0 {
                    Label("\(Int(item.engagementScore))", systemImage: "flame")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let text = item.text, !text.isEmpty {
                Text(text)
                    .font(.callout)
                    .lineLimit(3)
            }
            HStack(spacing: 16) {
                Label("\(item.likeCount)", systemImage: "heart")
                Label("\(item.repostCount)", systemImage: "arrow.2.squarepath")
                Label("\(item.replyCount)", systemImage: "bubble.left")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var typeIcon: String {
        switch item.contentType {
        case .all:     return "tray"
        case .posts:   return "doc.text"
        case .replies: return "arrowshape.turn.up.left"
        case .reposts: return "arrow.2.squarepath"
        case .likes:   return "heart"
        }
    }
}
