import SwiftUI
import SkymarshalCore

/// Alpha hub for account / interaction / timeline visualizations. Gated by
/// ``FeatureFlags/visualizationHubKey``. Shows explicit completeness — data is
/// derived from the local cache only, not a full social graph.
@available(iOS 17, *)
struct VisualizationHubView: View {

    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AccountGraphVizView()
                    } label: {
                        hubRow(
                            title: "Account graph",
                            subtitle: "Scanned follow graph — ego summary",
                            completeness: model.accounts.isEmpty ? "Unknown" : "Partial"
                        )
                    }
                    NavigationLink {
                        InteractionGraphVizView()
                    } label: {
                        hubRow(
                            title: "Interaction graph",
                            subtitle: "Replies, likes, reposts in your archive",
                            completeness: model.items.isEmpty ? "Unknown" : "Partial"
                        )
                    }
                    NavigationLink {
                        TimelineHeatmapVizView(items: model.items)
                    } label: {
                        hubRow(
                            title: "Timeline heatmap",
                            subtitle: "Posts + replies by hour and weekday",
                            completeness: model.items.isEmpty ? "Unknown" : "Partial"
                        )
                    }
                } header: {
                    Text("Visualizations")
                } footer: {
                    Text("Coverage is partial until every relationship is materialized. Nothing here leaves your device.")
                }
            }
            .navigationTitle("Scope")
            .navigationBarTitleDisplayMode(.large)
            .cinematicListChrome()
            .onAppear {
                ColdLaunchSignposts.event("tab_scope_appear")
                ScopeExperimentTelemetry.recordScopeHubAppearance()
            }
            .task { await model.refreshGraphSnapshots() }
        }
    }

    private func hubRow(title: String, subtitle: String, completeness: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                ScopePill(
                    value: completeness,
                    emphasis: completeness == "Unknown" ? .muted : .scope
                )
            }
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle). Data completeness \(completeness).")
    }
}

// MARK: - Account graph (alpha)

@available(iOS 17, *)
private struct AccountGraphVizView: View {

    @Environment(AppModel.self) private var model

    private var topByFollowers: [AnalyzedAccount] {
        model.accounts.sorted { $0.profile.followersCount > $1.profile.followersCount }.prefix(24).map { $0 }
    }

    @ViewBuilder
    private func persistedFooter(kind: GraphSnapshotKind, explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(explanation)
            if let raw = model.graphSnapshotSummaries[kind.rawValue] {
                Text(raw)
                    .font(Theme.Display.metricRegular(.caption2))
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Accounts in scan", value: "\(model.accounts.count)")
                LabeledContent("Completeness", value: model.accounts.isEmpty ? "Unknown" : "Partial")
            } footer: {
                persistedFooter(
                    kind: .accountGraph,
                    explanation: "Shows your scanned follow list only — not the entire Bluesky graph."
                )
            }

            if topByFollowers.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No follower scan",
                        systemImage: "person.2.slash",
                        description: Text("Run a scan on the Patterns tab, then return here.")
                    )
                }
            } else {
                Section("Top by followers (local scan)") {
                    ForEach(topByFollowers, id: \.did) { acct in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(acct.handle)
                                .font(.subheadline.weight(.semibold))
                            Text("\(acct.profile.followersCount) followers · ratio \(String(format: "%.2f", acct.ratio))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Account graph")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Interaction graph (alpha)

@available(iOS 17, *)
private struct InteractionGraphVizView: View {

    @Environment(AppModel.self) private var model

    private var replyWithParent: Int {
        model.items.filter { $0.contentType == .replies && $0.parentReplyURI != nil }.count
    }

    private var likesCount: Int { model.items.filter { $0.contentType == .likes }.count }
    private var repostsCount: Int { model.items.filter { $0.contentType == .reposts }.count }

    @ViewBuilder
    private func persistedFooter(kind: GraphSnapshotKind, explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(explanation)
            if let raw = model.graphSnapshotSummaries[kind.rawValue] {
                Text(raw)
                    .font(Theme.Display.metricRegular(.caption2))
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Replies with parent link", value: "\(replyWithParent)")
                LabeledContent("Likes (edges to posts)", value: "\(likesCount)")
                LabeledContent("Reposts", value: "\(repostsCount)")
                LabeledContent("Completeness", value: model.items.isEmpty ? "Unknown" : "Partial")
            } footer: {
                persistedFooter(
                    kind: .interactionGraph,
                    explanation: "Counts come from your downloaded archive only — not live thread fetches."
                )
            }
        }
        .navigationTitle("Interactions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Timeline heatmap (alpha)

@available(iOS 17, *)
private struct TimelineHeatmapVizView: View {

    let items: [ContentItem]
    @Environment(AppModel.self) private var model

    private var snapshot: AnalyticsSnapshot {
        AnalyticsService.buildSnapshot(from: items)
    }

    private static let weekdaySymbols: [String] = {
        var cal = Calendar.current
        cal.locale = Locale.current
        return cal.shortWeekdaySymbols
    }()

    @ViewBuilder
    private func persistedFooter(explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(explanation)
            if let raw = model.graphSnapshotSummaries[GraphSnapshotKind.timelineHeatmap.rawValue] {
                Text(raw)
                    .font(Theme.Display.metricRegular(.caption2))
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        List {
            Section {
                hourRow
            } header: {
                Text("Local hour (0–23)")
            }

            Section {
                weekdayRow
            } header: {
                Text("Weekday")
            }

            Section {
                LabeledContent("Completeness", value: items.isEmpty ? "Unknown" : "Partial")
            } footer: {
                persistedFooter(explanation: "Same buckets as Insights — posts and replies with timestamps only.")
            }
        }
        .navigationTitle("Heatmap")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hourRow: some View {
        let maxH = max(snapshot.postsByHourLocal.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<24, id: \.self) { h in
                    let v = snapshot.postsByHourLocal[h]
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(Theme.scope.opacity(0.12 + 0.88 * Double(v) / Double(maxH)))
                        .frame(height: 28)
                        .accessibilityLabel("Hour \(h), \(v) posts")
                }
            }
            Text("0h–23h local")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var weekdayRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { i in
                let v = snapshot.postsByWeekday[i]
                VStack(spacing: 4) {
                    Text(Self.weekdaySymbols[i])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(v)")
                        .font(.caption.monospacedDigit())
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }
}
