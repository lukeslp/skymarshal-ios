import SwiftUI
import UIKit
import SkymarshalCore

/// Local-data visualization hub matching the Figma Make Scope hierarchy.
///
/// Inputs: cached content, analyzed accounts, and persisted snapshot summaries.
/// Output: account, post, interaction, and timeline drill-ins. No mock records
/// or network requests are introduced by these views.
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

                    VStack(spacing: 8) {
                        NavigationLink {
                            AccountGraphVizView()
                        } label: {
                            hubCard(
                                title: "Account Graph",
                                subtitle: "Ego ring, signals, influence",
                                systemImage: "person.2",
                                completeness: accountCompleteness
                            )
                        }

                        NavigationLink {
                            PostGraphVizView(items: model.items)
                        } label: {
                            hubCard(
                                title: "Post Graph",
                                subtitle: "Reply and repost pathways",
                                systemImage: "point.3.connected.trianglepath.dotted",
                                completeness: contentCompleteness
                            )
                        }

                        NavigationLink {
                            InteractionGraphVizView(items: model.items)
                        } label: {
                            hubCard(
                                title: "Interactions",
                                subtitle: "Cached outgoing activity by account",
                                systemImage: "chart.bar",
                                completeness: interactionCompleteness
                            )
                        }

                        NavigationLink {
                            TimelineHeatmapVizView(items: model.items)
                        } label: {
                            hubCard(
                                title: "Timeline Heatmap",
                                subtitle: "Posting hour × weekday",
                                systemImage: "clock",
                                completeness: contentCompleteness
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    Text("Coverage reflects the archive currently stored on this device. Scope never invents missing relationships.")
                        .font(Theme.Mono.caption(11))
                        .foregroundStyle(.tertiary)
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

    private var accountCompleteness: String {
        model.accounts.isEmpty ? "Unknown" : "Partial"
    }

    private var contentCompleteness: String {
        model.items.isEmpty ? "Unknown" : model.archiveTruncated ? "Partial" : "Local"
    }

    private var interactionCompleteness: String {
        model.items.contains(where: { $0.subjectAuthorHandle != nil }) ? "Local" : "Unknown"
    }

    private var archiveScanCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ARCHIVE SCAN")
                .font(Theme.Mono.kicker())
                .foregroundStyle(.tertiary)
            HStack(spacing: 22) {
                scanStat(value: model.items.count.formatted(), label: "records")
                scanStat(
                    value: model.accounts.isEmpty ? "—" : model.accounts.count.formatted(),
                    label: "accounts"
                )
                scanStat(
                    value: model.archiveTruncated ? "Partial" : "Local",
                    label: "coverage"
                )
            }
        }
        .scopeCard()
    }

    private func scanStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.Mono.tabular(18))
                .fontWeight(.bold)
            Text(label.uppercased())
                .font(Theme.Mono.kicker(9))
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
                                .strokeBorder(
                                    Theme.cinematicAccentA.opacity(0.35),
                                    lineWidth: 1
                                )
                        }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(Theme.Mono.caption(11))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(completeness.uppercased())
                    .font(Theme.Mono.kicker(9))
                    .foregroundStyle(completeness == "Unknown" ? Theme.danger : Theme.success)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .scopeCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle). Data completeness \(completeness).")
    }
}

// MARK: - Account graph

@available(iOS 17, *)
private struct AccountGraphVizView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedID: String?

    private var nodes: [AnalyzedAccount] {
        Array(
            model.accounts
                .sorted {
                    if $0.engagementScore == $1.engagementScore {
                        return $0.profile.followersCount > $1.profile.followersCount
                    }
                    return $0.engagementScore > $1.engagementScore
                }
                .prefix(18)
        )
    }

    private var selectedAccount: AnalyzedAccount? {
        nodes.first { $0.did == selectedID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScopeDrillInHeader(
                    title: "Account Graph",
                    subtitle: "EGO RING · \(model.accounts.count.formatted()) ACCOUNTS"
                )

                legend

                if nodes.isEmpty {
                    ContentUnavailableView(
                        "No follower scan",
                        systemImage: "person.2.slash",
                        description: Text("Run a scan on the Patterns tab, then return here.")
                    )
                    .frame(minHeight: 280)
                } else {
                    if dynamicTypeSize.isAccessibilitySize {
                        accessibleNodeList
                    } else {
                        AccountRingGraph(
                            nodes: nodes,
                            selectedID: $selectedID,
                            centerLabel: model.currentHandle ?? "You"
                        )
                        .frame(height: 330)
                        .scopeCard(padding: 8)
                    }

                    if let selectedAccount {
                        selectedCard(selectedAccount)
                            .accessibilityAddTraits(.updatesFrequently)
                    } else {
                        Text("Tap a node to inspect")
                            .font(Theme.Mono.caption(11))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                Text("Edges show accounts in your scanned follow list, not relationships between those accounts.")
                    .font(Theme.Mono.caption(10))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .navigationTitle("Account Graph")
        .navigationBarTitleDisplayMode(.inline)
        .cinematicListChrome()
        .onChange(of: selectedID) { _, newValue in
            guard let account = nodes.first(where: { $0.did == newValue }) else { return }
            UIAccessibility.post(
                notification: .announcement,
                argument: "Selected @\(account.handle). Details follow the graph."
            )
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem("Low", Theme.success)
            legendItem("Review", Theme.caution)
            legendItem("High", Theme.danger)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Legend: low, review, and high automation signals")
    }

    private var accessibleNodeList: some View {
        VStack(spacing: 0) {
            ForEach(nodes) { account in
                Button {
                    selectedID = selectedID == account.did ? nil : account.did
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: signalSymbol(account.botScore))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(signalColor(account.botScore))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.profile.displayName ?? account.handle)
                                .font(.subheadline.weight(.semibold))
                            Text("@\(account.handle)")
                                .font(Theme.Mono.caption(10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(account.botScore * 100))%")
                            .font(Theme.Mono.tabular(11))
                            .foregroundStyle(.primary)
                    }
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedID == account.did ? [.isSelected] : [])

                if account.did != nodes.last?.did {
                    Divider().overlay(Theme.hairline)
                }
            }
        }
        .scopeCard()
    }

    private func legendItem(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label.uppercased())
                .font(Theme.Mono.kicker(8))
                .foregroundStyle(.tertiary)
        }
    }

    private func selectedCard(_ account: AnalyzedAccount) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.profile.displayName ?? account.handle)
                        .font(.subheadline.weight(.semibold))
                    Text("@\(account.handle)")
                        .font(Theme.Mono.caption(11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label(
                    signalLabel(account.botScore).uppercased(),
                    systemImage: signalSymbol(account.botScore)
                )
                    .font(Theme.Mono.kicker(9))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 22) {
                graphMetric(account.profile.followersCount.formatted(), "followers")
                graphMetric(String(format: "%.0f", account.engagementScore), "engagement")
                graphMetric("\(Int(account.botScore * 100))%", "signals")
            }
            AutomationScoreBar(score: account.botScore)

            if let url = URL(string: "https://bsky.app/profile/\(account.handle)") {
                Link(destination: url) {
                    Label("View profile", systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 40)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.cinematicAccentA)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.elev2)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        }
                }
            }
        }
        .scopeCard()
    }

    private func graphMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.Mono.tabular(15)).fontWeight(.bold)
            Text(label.uppercased())
                .font(Theme.Mono.kicker(8))
                .foregroundStyle(.tertiary)
        }
    }
}

@available(iOS 17, *)
private struct AccountRingGraph: View {
    let nodes: [AnalyzedAccount]
    @Binding var selectedID: String?
    let centerLabel: String

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            ZStack {
                Canvas { context, canvasSize in
                    let graphCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                    let innerRadius = min(canvasSize.width, canvasSize.height) * 0.25
                    let outerRadius = min(canvasSize.width, canvasSize.height) * 0.39

                    for radius in [innerRadius, outerRadius] {
                        let rect = CGRect(
                            x: graphCenter.x - radius,
                            y: graphCenter.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        context.stroke(
                            Path(ellipseIn: rect),
                            with: .color(Theme.hairlineMed),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 5])
                        )
                    }

                    for index in nodes.indices {
                        let point = nodePosition(
                            index: index,
                            count: nodes.count,
                            center: graphCenter,
                            innerRadius: innerRadius,
                            outerRadius: outerRadius
                        )
                        var edge = Path()
                        edge.move(to: graphCenter)
                        edge.addLine(to: point)
                        context.stroke(
                            edge,
                            with: .color(signalColor(nodes[index].botScore).opacity(0.28)),
                            lineWidth: max(0.6, min(2.5, nodes[index].engagementScore / 20))
                        )
                    }
                }
                .accessibilityHidden(true)

                Circle()
                    .fill(Theme.cinematicAccentA.opacity(0.2))
                    .overlay(Circle().strokeBorder(Theme.cinematicAccentA, lineWidth: 1.5))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Text("YOU")
                            .font(Theme.Mono.kicker(9))
                            .foregroundStyle(.primary)
                    }
                    .position(center)
                    .accessibilityLabel("You, @\(centerLabel)")

                ForEach(Array(nodes.enumerated()), id: \.element.did) { index, account in
                    let point = nodePosition(
                        index: index,
                        count: nodes.count,
                        center: center,
                        innerRadius: min(size.width, size.height) * 0.25,
                        outerRadius: min(size.width, size.height) * 0.39
                    )
                    let selected = selectedID == account.did
                    Button {
                        selectedID = selected ? nil : account.did
                    } label: {
                        VStack(spacing: 2) {
                            Circle()
                                .fill(signalColor(account.botScore).opacity(0.22))
                                .overlay {
                                    Circle().strokeBorder(
                                        signalColor(account.botScore),
                                        lineWidth: selected ? 2 : 1
                                    )
                                }
                                .frame(width: index.isMultiple(of: 2) ? 30 : 24)
                                .overlay {
                                    Image(systemName: signalSymbol(account.botScore))
                                        .font(.caption2.weight(.bold))
                                        .symbolRenderingMode(.monochrome)
                                        .foregroundStyle(.primary)
                                }
                            Text(account.handle.split(separator: ".").first.map(String.init) ?? account.handle)
                                .font(Theme.Mono.caption(7))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: 54)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .position(point)
                    .accessibilityLabel(
                        "@\(account.handle), \(signalLabel(account.botScore)) automation signals, engagement score \(Int(account.engagementScore))"
                    )
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
        }
    }
}

// MARK: - Post graph

@available(iOS 17, *)
private struct PostGraphVizView: View {
    let items: [ContentItem]
    @State private var selectedRootID: String?

    private var roots: [ContentItem] {
        items
            .filter { $0.contentType == .posts }
            .sorted { $0.engagementScore > $1.engagementScore }
    }

    private var root: ContentItem? {
        roots.first { $0.id == selectedRootID } ?? roots.first
    }

    private var directReplies: [ContentItem] {
        guard let root else { return [] }
        return items
            .filter { $0.contentType == .replies && $0.parentReplyURI == root.uri }
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    private var relatedReposts: [ContentItem] {
        guard let root else { return [] }
        return items.filter { $0.contentType == .reposts && $0.uri == root.uri }
    }

    private var relatedLikes: [ContentItem] {
        guard let root else { return [] }
        return items.filter { $0.contentType == .likes && $0.uri == root.uri }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScopeDrillInHeader(
                    title: "Post Graph",
                    subtitle: "THREAD · ENGAGEMENT · PATHWAYS"
                )

                if let root {
                    if roots.count > 1 {
                        Picker("Root post", selection: Binding(
                            get: { root.id },
                            set: { selectedRootID = $0 }
                        )) {
                            ForEach(roots.prefix(50)) { item in
                                Text(postPickerLabel(item)).tag(item.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    rootCard(root)

                    HStack(spacing: 8) {
                        graphCount(directReplies.count, "cached replies", Theme.cinematicAccentA)
                        graphCount(relatedReposts.count, "reposts", Theme.success)
                        graphCount(relatedLikes.count, "likes", Theme.like)
                    }

                    Text("REPLY PATHS")
                        .font(Theme.Mono.kicker())
                        .foregroundStyle(.tertiary)

                    if directReplies.isEmpty {
                        ContentUnavailableView(
                            "No cached reply paths",
                            systemImage: "arrow.triangle.branch",
                            description: Text("Only replies whose parent URI is in this archive can appear.")
                        )
                        .frame(minHeight: 180)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(directReplies) { reply in
                                ReplyPathRow(reply: reply)
                            }
                        }
                        .scopeCard()
                    }
                } else {
                    ContentUnavailableView(
                        "No posts loaded",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Load your Content archive, then return here.")
                    )
                    .frame(minHeight: 300)
                }

                Text("Scope shows only relationships materialized in your local archive.")
                    .font(Theme.Mono.caption(10))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .navigationTitle("Post Graph")
        .navigationBarTitleDisplayMode(.inline)
        .cinematicListChrome()
    }

    private func rootCard(_ item: ContentItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("ROOT POST", systemImage: "scope")
                    .font(Theme.Mono.kicker(9))
                    .foregroundStyle(Theme.cinematicAccentA)
                Spacer()
                if let date = item.createdAt {
                    Text(date, style: .date)
                        .font(Theme.Mono.caption(10))
                        .foregroundStyle(.tertiary)
                }
            }
            Text(item.text?.isEmpty == false ? item.text! : "Post text unavailable")
                .font(.callout)
                .foregroundStyle(item.text?.isEmpty == false ? .primary : .secondary)
            HStack(spacing: 16) {
                Label(item.likeCount.formatted(), systemImage: "heart")
                    .foregroundStyle(Theme.like)
                Label(item.repostCount.formatted(), systemImage: "arrow.2.squarepath")
                    .foregroundStyle(Theme.success)
                Label(item.replyCount.formatted(), systemImage: "bubble.left")
                    .foregroundStyle(Theme.cinematicAccentA)
            }
            .font(Theme.Mono.tabular(11))
        }
        .scopeCard()
    }

    private func graphCount(_ value: Int, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value.formatted())
                .font(Theme.Mono.tabular(16))
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(Theme.Mono.kicker(8))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.elev2)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }
        }
    }

    private func postPickerLabel(_ item: ContentItem) -> String {
        let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled post"
        return String(text.prefix(42))
    }
}

@available(iOS 17, *)
private struct ReplyPathRow: View {
    let reply: ContentItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Theme.cinematicAccentA)
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(Theme.hairlineMed)
                    .frame(width: 1)
                    .frame(minHeight: 48)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("YOUR REPLY")
                        .font(Theme.Mono.kicker(9))
                        .foregroundStyle(Theme.cinematicAccentA)
                    Spacer()
                    if let date = reply.createdAt {
                        Text(date, style: .relative)
                            .font(Theme.Mono.caption(9))
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(reply.text?.isEmpty == false ? reply.text! : "Reply text unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label(reply.likeCount.formatted(), systemImage: "heart")
                    .font(Theme.Mono.caption(9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Interactions

@available(iOS 17, *)
private struct InteractionGraphVizView: View {
    let items: [ContentItem]
    @State private var selectedHandle: String?

    private var handles: [String] {
        let counts = Dictionary(
            grouping: items.compactMap(\.subjectAuthorHandle),
            by: { $0 }
        )
        return counts.keys.sorted { counts[$0, default: []].count > counts[$1, default: []].count }
    }

    private var activeHandle: String? {
        if let selectedHandle, handles.contains(selectedHandle) { return selectedHandle }
        return handles.first
    }

    private var interactions: [ContentItem] {
        guard let activeHandle else { return [] }
        return items
            .filter { $0.subjectAuthorHandle == activeHandle }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScopeDrillInHeader(
                    title: "Interactions",
                    subtitle: "CACHED OUTGOING ACTIVITY · BY ACCOUNT"
                )

                if handles.isEmpty {
                    ContentUnavailableView(
                        "No attributed interactions",
                        systemImage: "arrow.left.arrow.right",
                        description: Text("Subject handles appear after likes and reposts are loaded.")
                    )
                    .frame(minHeight: 300)
                } else {
                    accountPicker
                    summaryCard

                    Text("TIMELINE · \(interactions.count) LOCAL")
                        .font(Theme.Mono.kicker())
                        .foregroundStyle(.tertiary)

                    LazyVStack(spacing: 9) {
                        ForEach(interactions) { item in
                            interactionRow(item)
                        }
                    }
                }

                Text("This view does not imply incoming engagement; it only summarizes activity present in your archive.")
                    .font(Theme.Mono.caption(10))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .navigationTitle("Interactions")
        .navigationBarTitleDisplayMode(.inline)
        .cinematicListChrome()
    }

    private var accountPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(handles, id: \.self) { handle in
                    let selected = activeHandle == handle
                    Button {
                        selectedHandle = handle
                    } label: {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    selected
                                        ? Theme.cinematicTitleGradient
                                        : LinearGradient(
                                            colors: [
                                                Theme.cinematicAccentA.opacity(0.18),
                                                Theme.cinematicAccentA.opacity(0.18),
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                )
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Text(String(handle.first ?? "?").uppercased())
                                        .font(.subheadline.weight(.bold))
                                }
                            Text(handle.split(separator: ".").first.map(String.init) ?? handle)
                                .font(Theme.Mono.caption(8))
                                .foregroundStyle(
                                    selected
                                        ? Color.primary
                                        : Color.secondary.opacity(0.7)
                                )
                                .lineLimit(1)
                        }
                        .frame(width: 60)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("@\(handle)")
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(.trailing, 24)
        }
    }

    private var summaryCard: some View {
        let likes = interactions.filter { $0.contentType == .likes }.count
        let reposts = interactions.filter { $0.contentType == .reposts }.count
        return VStack(alignment: .leading, spacing: 10) {
            Text(activeHandle.map { "@\($0)" } ?? "ACCOUNT")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 0) {
                interactionStat(interactions.count, "total", .secondary)
                Divider()
                interactionStat(likes, "likes", Theme.like)
                Divider()
                interactionStat(reposts, "reposts", Theme.success)
            }
            .frame(height: 48)
            .background(Theme.elev2)
            .clipShape(.rect(cornerRadius: 8))
        }
        .scopeCard()
    }

    private func interactionStat(_ value: Int, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value.formatted())
                .font(Theme.Mono.tabular(15))
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(Theme.Mono.kicker(8))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func interactionRow(_ item: ContentItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: interactionSymbol(item.contentType))
                .font(.caption.weight(.semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(interactionColor(item.contentType))
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.chipTint(interactionColor(item.contentType)))
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("YOU → \(activeHandle?.split(separator: ".").first.map(String.init) ?? "ACCOUNT")")
                        .font(Theme.Mono.kicker(8))
                        .foregroundStyle(.primary)
                    Spacer()
                    if let date = item.createdAt {
                        Text(date, style: .relative)
                            .font(Theme.Mono.caption(8))
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(item.text?.isEmpty == false ? item.text! : item.contentType.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .scopeCard(padding: 10)
    }

    private func interactionSymbol(_ type: ContentType) -> String {
        switch type {
        case .likes: return "heart"
        case .reposts: return "arrow.2.squarepath"
        case .replies: return "bubble.left"
        default: return "doc.text"
        }
    }

    private func interactionColor(_ type: ContentType) -> Color {
        switch type {
        case .likes: return Theme.like
        case .reposts: return Theme.success
        case .replies: return Theme.cinematicAccentA
        default: return .secondary
        }
    }
}

// MARK: - Timeline heatmap

@available(iOS 17, *)
private struct TimelineHeatmapVizView: View {
    let items: [ContentItem]

    private var snapshot: AnalyticsSnapshot {
        AnalyticsService.buildSnapshot(from: items)
    }

    private static let weekdaySymbols: [String] = {
        var calendar = Calendar.current
        calendar.locale = Locale.current
        return calendar.shortWeekdaySymbols
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScopeDrillInHeader(
                    title: "Timeline Heatmap",
                    subtitle: "POSTING HOUR × WEEKDAY · LOCAL TIME"
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("HOUR OF DAY")
                        .font(Theme.Mono.kicker())
                        .foregroundStyle(.tertiary)
                    hourRow
                }
                .scopeCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("WEEKDAY")
                        .font(Theme.Mono.kicker())
                        .foregroundStyle(.tertiary)
                    weekdayRow
                }
                .scopeCard()

                Text("Posts and replies with parseable timestamps only.")
                    .font(Theme.Mono.caption(10))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .navigationTitle("Heatmap")
        .navigationBarTitleDisplayMode(.inline)
        .cinematicListChrome()
    }

    private var hourRow: some View {
        let maximum = max(snapshot.postsByHourLocal.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 3) {
                ForEach(0..<24, id: \.self) { hour in
                    let value = snapshot.postsByHourLocal[hour]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            Theme.scope.opacity(
                                0.10 + 0.90 * Double(value) / Double(maximum)
                            )
                        )
                        .frame(height: 42)
                        .accessibilityLabel("Hour \(hour), \(value) posts")
                }
            }
            HStack {
                Text("00")
                Spacer()
                Text("12")
                Spacer()
                Text("23")
            }
            .font(Theme.Mono.caption(8))
            .foregroundStyle(.tertiary)
        }
    }

    private var weekdayRow: some View {
        let maximum = max(snapshot.postsByWeekday.max() ?? 1, 1)
        return HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { index in
                let value = snapshot.postsByWeekday[index]
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(
                            Theme.scope.opacity(
                                0.10 + 0.90 * Double(value) / Double(maximum)
                            )
                        )
                        .frame(height: 50)
                        .overlay {
                            Text(value.formatted())
                                .font(Theme.Mono.tabular(10))
                        }
                    Text(Self.weekdaySymbols[index])
                        .font(Theme.Mono.caption(8))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Shared Scope helpers

@available(iOS 17, *)
private struct ScopeDrillInHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.Display.title(.title2))
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(Theme.Mono.kicker(9))
                .foregroundStyle(.secondary)
        }
    }
}

private func signalColor(_ score: Double) -> Color {
    if score >= 0.6 { return Theme.danger }
    if score >= 0.3 { return Theme.caution }
    return Theme.success
}

private func signalLabel(_ score: Double) -> String {
    if score >= 0.6 { return "High" }
    if score >= 0.3 { return "Review" }
    return "Low"
}

private func signalSymbol(_ score: Double) -> String {
    if score >= 0.6 { return "exclamationmark.triangle.fill" }
    if score >= 0.3 { return "diamond.fill" }
    return "checkmark.circle.fill"
}

private func nodePosition(
    index: Int,
    count: Int,
    center: CGPoint,
    innerRadius: CGFloat,
    outerRadius: CGFloat
) -> CGPoint {
    let innerCount = min(count, 8)
    let inner = index < innerCount
    let ringCount = inner ? innerCount : max(count - innerCount, 1)
    let ringIndex = inner ? index : index - innerCount
    let angle = (Double(ringIndex) / Double(ringCount)) * .pi * 2 - .pi / 2
    let radius = inner ? innerRadius : outerRadius
    return CGPoint(
        x: center.x + radius * cos(angle),
        y: center.y + radius * sin(angle)
    )
}

@available(iOS 17, *)
private extension View {
    func scopeCard(padding: CGFloat = 13) -> some View {
        self
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.elev1)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    }
            }
    }
}
