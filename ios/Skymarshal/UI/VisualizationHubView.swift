import SwiftUI
import SkymarshalCore

/// Alpha hub for account / interaction / timeline visualizations. Gated by
/// ``FeatureFlags/visualizationHubKey``. Visual language tracks the Figma Make
/// Scope hub: elev1 Cards with accent icon wells + completeness Mono.
@available(iOS 17, *)
struct VisualizationHubView: View {

    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    archiveScanCard

                    Text("VISUALIZATIONS")
                        .font(Theme.Mono.kicker())
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)

                    VStack(spacing: 8) {
                        NavigationLink {
                            AccountGraphVizView()
                        } label: {
                            hubCard(
                                title: "Account Graph",
                                subtitle: "Mutuals, bridges, clusters",
                                systemImage: "person.2",
                                completeness: model.accounts.isEmpty ? "Unknown" : "Partial"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            InteractionGraphVizView()
                        } label: {
                            hubCard(
                                title: "Interactions",
                                subtitle: "All interactions, both dirs",
                                systemImage: "chart.bar",
                                completeness: model.items.isEmpty ? "Unknown" : "Partial"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            TimelineHeatmapVizView(items: model.items)
                        } label: {
                            hubCard(
                                title: "Timeline Heatmap",
                                subtitle: "Posting hour × weekday",
                                systemImage: "clock",
                                completeness: model.items.isEmpty ? "Unknown" : "Partial"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Coverage is partial until every relationship is materialized. Nothing here leaves your device.")
                        .font(Theme.Mono.caption(11))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(16)
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

    private var archiveScanCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ARCHIVE SCAN")
                .font(Theme.Mono.kicker())
                .foregroundStyle(.tertiary)
            HStack(spacing: 22) {
                scanStat(value: model.items.count.formatted(), label: "records")
                scanStat(
                    value: model.accounts.isEmpty && model.items.isEmpty ? "—" : "Partial",
                    label: "coverage"
                )
                scanStat(
                    value: model.accounts.isEmpty ? "—" : model.accounts.count.formatted(),
                    label: "accounts"
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.elev1)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }
        }
    }

    private func scanStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.Mono.tabular(18))
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            Text(label)
                .font(Theme.Mono.kicker(10))
                .foregroundStyle(.tertiary)
        }
    }

    private func hubCard(
        title: String,
        subtitle: String,
        systemImage: String,
        completeness: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Theme.cinematicAccentA)
                .frame(width: 34, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Theme.cinematicAccentA.opacity(0.14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Theme.cinematicAccentA.opacity(0.35), lineWidth: 1)
                        }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(Theme.Mono.caption(11))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(completeness.uppercased())
                    .font(Theme.Mono.kicker(10))
                    .foregroundStyle(
                        completeness == "Unknown" ? Theme.danger : Theme.caution
                    )
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.elev1)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }
        }
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
                    .font(Theme.Mono.tabular(11))
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
        .cinematicListChrome()
        .listRowBackground(Theme.elev1)
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
                    .font(Theme.Mono.tabular(11))
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
        .cinematicListChrome()
        .listRowBackground(Theme.elev1)
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
                    .font(Theme.Mono.tabular(11))
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
        .cinematicListChrome()
        .listRowBackground(Theme.elev1)
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
                        .font(Theme.Mono.tabular(12))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }
}
