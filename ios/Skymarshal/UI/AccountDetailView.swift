import SwiftUI
import SkymarshalCore

/// Sheet shown when the user taps an AccountRow. Mirrors the shape of
/// PostDetailView. Surfaces the bot-flag breakdown that the analyzer
/// produces but the row never renders — until now users could see a
/// "0.85" bot score with no evidence; the section "Why we flagged this
/// account" lists each triggered factor with a severity-bucketed icon.
@available(iOS 17, *)
struct AccountDetailView: View {
    let account: AnalyzedAccount
    /// When true, confirmation offers a simulate action and copy matches bulk dry-run mode.
    var dryRunUnfollow: Bool = false
    let onUnfollow: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppModel.self) private var model

    @State private var showUnfollowConfirm: Bool = false
    @State private var showInteractions: Bool = false
    @State private var mutuals: MutualFollowResult?
    @State private var mutualsLoading: Bool = false
    @State private var showProfileExplorer: Bool = false

    /// Lazily-resolved ghost verdict for this account. Seeded from the
    /// passed-in `account` (instant on re-open from cache); computed in
    /// `.task` on first open when nil.
    @State private var ghostVerdict: GhostVerdict?
    @State private var reciprocityInbound: Int?
    @State private var ghostChecking: Bool = false

    @AppStorage(FeatureFlags.profileExplorerKey) private var featureProfileExplorer: Bool = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    bannerHeader
                    identitySection
                    statusPills
                    statsGrid

                    if !account.botFlags.isEmpty {
                        botFlagsSection
                    }

                    ghostReciprocitySection

                    if account.lastPostDate != nil || account.isInactive {
                        activitySection
                    }

                    mutualsSection

                    Divider().padding(.vertical, 4)

                    actions
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .ignoresSafeArea(edges: .top)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .confirmationDialog(
                dryRunUnfollow
                    ? "Simulate unfollow @\(account.handle)?"
                    : "Unfollow @\(account.handle)?",
                isPresented: $showUnfollowConfirm
            ) {
                if dryRunUnfollow {
                    Button("Simulate unfollow") {
                        onUnfollow()
                        dismiss()
                    }
                    .accessibilityLabel("Simulate unfollow for @\(account.handle)")
                } else {
                    Button("Unfollow", role: .destructive) {
                        onUnfollow()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if dryRunUnfollow {
                    Text("Preview only — no changes are sent to Bluesky. Turn off “Dry-run unfollow” in the followers toolbar to unfollow for real.")
                } else {
                    Text("Removes you as a follower. They keep their content; you keep yours. Unfollows go through the same rate-limit safety net as deletes.")
                }
            }
            .sheet(isPresented: $showInteractions) {
                InteractionHistoryView(target: account)
            }
            .sheet(isPresented: $showProfileExplorer) {
                ProfileExplorerView(actorHandle: account.handle)
            }
            .task(id: account.did) {
                await loadMutuals()
            }
            .task(id: account.did) {
                await resolveGhostReciprocity()
            }
        }
    }

    /// Lazy per-account ghost/reciprocity resolve. If the passed-in
    /// account already carries a cached verdict, seed instantly and skip
    /// the network. Otherwise fire one cheap user-initiated read, stamp
    /// the model, and reflect the result locally so the chip updates.
    private func resolveGhostReciprocity() async {
        if let cached = account.ghostVerdict {
            ghostVerdict = cached
            reciprocityInbound = account.reciprocityGapInboundCount
            return
        }
        guard ghostVerdict == nil, !ghostChecking else { return }
        ghostChecking = true
        defer { ghostChecking = false }
        if let stamped = await model.ghostReciprocity(forDID: account.did) {
            ghostVerdict = stamped.ghostVerdict
            reciprocityInbound = stamped.reciprocityGapInboundCount
        }
    }

    private func loadMutuals() async {
        guard mutuals == nil, !mutualsLoading else { return }
        mutualsLoading = true
        defer { mutualsLoading = false }
        do {
            let result = try await model.followers.loadMutualFollows(withDID: account.did)
            self.mutuals = result
        } catch {
            // Silent fail — section just doesn't appear. Common path
            // is the target's follow list is private or rate-limited.
        }
    }

    // MARK: - Banner + identity

    @ViewBuilder
    private var bannerHeader: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let url = account.profile.banner.flatMap(URL.init(string:)) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: bannerPlaceholder
                        }
                    }
                } else {
                    bannerPlaceholder
                }
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.25)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 60)
            }

            avatar
                .frame(width: 76, height: 76)
                .padding(.leading, 20)
                .offset(y: 38)
        }
        .padding(.bottom, 38)  // leave room for the avatar overlap
        .padding(.horizontal, -16)  // banner edge-to-edge
    }

    private var bannerPlaceholder: some View {
        LinearGradient(
            colors: [.accentColor.opacity(0.6), .accentColor.opacity(0.2)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var avatar: some View {
        Group {
            if let url = account.profile.avatar.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 4))
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(.tint.opacity(0.15))
            .overlay {
                Text(String(account.handle.first ?? "?").uppercased())
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.tint)
            }
    }

    @ViewBuilder
    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let name = account.profile.displayName, !name.isEmpty {
                Text(name)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
            }
            Text("@\(account.handle)")
                .font(.subheadline.monospaced())
                .foregroundStyle(.secondary)

            if let bio = account.profile.description, !bio.isEmpty {
                Text(bio)
                    .font(.callout)
                    .textSelection(.enabled)
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var statusPills: some View {
        let pills = activeStatusPills
        if !pills.isEmpty {
            HStack(spacing: 6) {
                ForEach(pills, id: \.label) { pill in
                    HStack(spacing: 4) {
                        Image(systemName: pill.icon)
                            .font(.caption)
                        Text(pill.label)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(pill.color)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(pill.color.opacity(0.15), in: .capsule)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(pill.label)
                }
                Spacer()
            }
        }
    }

    private var activeStatusPills: [(icon: String, label: String, color: Color)] {
        var out: [(String, String, Color)] = []
        if account.isMutual { out.append(("person.2.fill", "Mutual", .accentColor)) }
        if account.profile.hasUnverifiedHandle {
            out.append(("questionmark.circle", "Unverified handle", .secondary))
        }
        if account.isDeleted && !account.profile.hasUnverifiedHandle {
            out.append(("xmark.octagon.fill", "Deleted", Theme.danger))
        } else if account.isInactive {
            out.append(("moon.zzz.fill", "Inactive", Theme.caution))
        }
        if account.profile.viewer?.muted == true { out.append(("speaker.slash.fill", "Muted", .secondary)) }
        if account.profile.viewer?.blockedBy == true { out.append(("hand.raised.fill", "Blocks you", Theme.danger)) }
        if account.profile.viewer?.blocking != nil { out.append(("hand.raised.fill", "You block", .secondary)) }
        return out.map { (icon: $0.0, label: $0.1, color: $0.2) }
    }

    // MARK: - Stats

    @ViewBuilder
    private var statsGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        LazyVGrid(columns: columns, spacing: 12) {
            stat(short(account.profile.followersCount), "Followers")
            stat(short(account.profile.followsCount), "Following")
            stat(short(account.profile.postsCount), "Posts")
            stat(formatRatio(account.ratio), "Ratio")
            stat(formatAge(account.accountAgeDays), "Age")
            stat(account.influenceTier.label, "Tier")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Bot flags

    @ViewBuilder
    private var botFlagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Patterns we noticed about this account")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if account.botScore >= 0.6 && !account.userWhitelisted {
                    BotScoreBadge(score: account.botScore)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(account.botFlags, id: \.self) { flag in
                    BotFlagRow(flag: flag)
                }
            }

            Text("These are signals the scanner noticed — low post volume, profile incompleteness, follower asymmetry. A real human can match every one of them. Flip the toggle below if this isn't an automated account.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Toggle(isOn: whitelistBinding) {
                Label("This isn't an automated account", systemImage: "person.fill.checkmark")
                    .font(.callout.weight(.medium))
            }
            .toggleStyle(.switch)
            .padding(.top, 4)
            .accessibilityHint("Removes this account from the bots filter even when the analyzer's score is high")
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private var whitelistBinding: Binding<Bool> {
        Binding(
            get: { account.userWhitelisted },
            set: { newValue in
                Task { await model.setWhitelist(did: account.did, to: newValue) }
            }
        )
    }

    // MARK: - Ghost / reciprocity

    /// Per-account "does this account engage you?" verdict + reciprocity
    /// line. Spinner on first open; instant on re-open from cache. A
    /// `.unknown` verdict reads "couldn't read" in gray and the copy
    /// states plainly that an unreadable account is not a reason to
    /// unfollow (the engine's fail-safe contract surfaced in the UI).
    @ViewBuilder
    private var ghostReciprocitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right.circle")
                    .foregroundStyle(.secondary)
                Text("Do they engage you?")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            if let verdict = ghostVerdict {
                ghostChip(verdict)
                reciprocityLine(verdict)
                if verdict == .unknown {
                    Text("We couldn't read this account's activity reliably — likely throttled or it gates its feed from public reads. That is **not** a reason to unfollow.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Checking whether they engage you…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func ghostChip(_ verdict: GhostVerdict) -> some View {
        let spec: (icon: String, text: String, color: Color) = {
            switch verdict {
            case .engaged: return ("checkmark.circle.fill", "Engages you", Theme.scope)
            case .ghost:   return ("xmark.circle.fill", "Ghost — never engages you", Theme.danger)
            case .unknown: return ("questionmark.circle.fill", "Couldn't read", .secondary)
            }
        }()
        HStack(spacing: 6) {
            Image(systemName: spec.icon)
                .font(.callout)
            Text(spec.text)
                .font(.callout.weight(.semibold))
        }
        .foregroundStyle(spec.color)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Theme.chipTint(spec.color), in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spec.text)
    }

    @ViewBuilder
    private func reciprocityLine(_ verdict: GhostVerdict) -> some View {
        let inbound = reciprocityInbound ?? 0
        let userReciprocates = model.userOutboundEngagedDIDs.contains(account.did)
        Group {
            switch verdict {
            case .engaged where inbound > 0 && !userReciprocates:
                Text("They engaged you \(inbound)× — you haven't engaged them back.")
            case .engaged where inbound > 0:
                Text("They engaged you \(inbound)×; you engage them too.")
            case .engaged:
                Text("They engage you. You \(userReciprocates ? "engage them too" : "haven't engaged them back").")
            case .ghost:
                Text(userReciprocates
                     ? "You've engaged them, but they've never engaged you back."
                     : "No engagement either way in what we could read.")
            case .unknown:
                EmptyView()
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    // MARK: - Activity

    @ViewBuilder
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(account.isInactive ? Theme.caution : .secondary)
                Text("Activity")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            if let last = account.lastPostDate {
                HStack(spacing: 6) {
                    Text("Last posted")
                        .foregroundStyle(.secondary)
                    Text(last.formatted(date: .abbreviated, time: .omitted))
                    if let days = account.daysSinceLastPost {
                        Text("·").foregroundStyle(.tertiary)
                        Text("\(days)d ago")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout.monospacedDigit())
            } else if account.profile.postsCount == 0 {
                Text("Never posted")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Activity unknown")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if account.postsPerDay > 0 {
                Text("\(formatPostsPerDay(account.postsPerDay)) posts per day")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            if account.isInactive {
                Capsule()
                    .fill(Theme.caution)
                    .frame(width: 3)
            }
        }
    }

    // MARK: - Mutual follows

    @ViewBuilder
    private var mutualsSection: some View {
        if mutualsLoading {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking who you both follow…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        } else if let result = mutuals, !result.matches.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.crop.square.stack")
                        .foregroundStyle(.tint)
                    Text("You both follow \(result.matches.count)")
                        .font(.subheadline.weight(.semibold))
                    if result.truncated {
                        Text("(showing first 500)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(result.matches.prefix(40)) { mutual in
                            MutualTile(mutual: mutual)
                        }
                        if result.matches.count > 40 {
                            Text("+\(result.matches.count - 40)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 56, height: 56)
                                .background(Color(.tertiarySystemFill), in: Circle())
                        }
                    }
                }
                .scrollClipDisabled()
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        } else if mutuals != nil {
            // Loaded with empty result — explicit "no overlap" so the
            // user knows we checked.
            HStack(spacing: 8) {
                Image(systemName: "person.2.slash")
                    .foregroundStyle(.tertiary)
                Text("No mutual follows")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 8) {
            Button {
                showInteractions = true
            } label: {
                Label("Interactions with you", systemImage: "arrow.left.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                openURL(URL(string: "https://bsky.app/profile/\(account.did)")!)
            } label: {
                Label("View on Bluesky", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if featureProfileExplorer {
                Button {
                    showProfileExplorer = true
                } label: {
                    Label("Followers & following", systemImage: "person.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityHint("Read-only lists — not a full Bluesky client timeline.")
            }

            if dryRunUnfollow {
                Button {
                    showUnfollowConfirm = true
                } label: {
                    Label("Simulate unfollow", systemImage: "person.crop.circle.badge.minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(Theme.scope)
                .accessibilityHint("Preview only. No changes are sent to Bluesky.")
            } else {
                Button(role: .destructive) {
                    showUnfollowConfirm = true
                } label: {
                    Label("Unfollow", systemImage: "person.crop.circle.badge.minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.danger)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Formatters

    private func short(_ n: Int) -> String {
        if n < 1_000 { return n.formatted() }
        if n < 1_000_000 {
            let v = Double(n) / 1_000
            return v >= 100 ? "\(Int(v))K" : String(format: "%.1fK", v)
        }
        let v = Double(n) / 1_000_000
        return v >= 100 ? "\(Int(v))M" : String(format: "%.1fM", v)
    }

    private func formatRatio(_ ratio: Double) -> String {
        if ratio >= 999 { return "∞" }
        return ratio < 10
            ? String(format: "%.2f", ratio)
            : String(format: "%.0f", ratio)
    }

    private func formatAge(_ days: Int) -> String {
        if days <= 0 { return "?" }
        if days < 365 { return "\(days)d" }
        let years = Double(days) / 365
        return years >= 10
            ? "\(Int(years))y"
            : String(format: "%.1fy", years)
    }

    private func formatPostsPerDay(_ ppd: Double) -> String {
        if ppd < 0.01 { return "<0.01" }
        if ppd >= 100 { return String(format: "%.0f", ppd) }
        return String(format: "%.2f", ppd)
    }
}

// MARK: - Bot flag row + severity

/// Single flag in the "Why we flagged" list. Severity is derived from
/// substring match against the flag string itself — keeps the UI
/// decoupled from BluescreenAnalyzer's internal weights and scores.
@available(iOS 17, *)
struct BotFlagRow: View {
    let flag: String

    var body: some View {
        let severity = BotFlagSeverity.classify(flag)
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: severity.iconName)
                .foregroundStyle(severity.color)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 16, alignment: .center)
            Text(flag)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(severity.label) signal: \(flag)")
    }
}

/// Three-bucket severity classifier driven by flag-string content.
/// Public so the test target can verify each known flag maps to its
/// expected bucket — guards against drift if BluescreenAnalyzer ever
/// adds new flag strings that should be High/Medium but silently fall
/// to Low.
public enum BotFlagSeverity: Sendable, Equatable {
    case high
    case medium
    case low

    public var label: String {
        switch self {
        case .high:   return "High"
        case .medium: return "Medium"
        case .low:    return "Low"
        }
    }

    public var iconName: String {
        switch self {
        case .high:   return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle"
        case .low:    return "info.circle"
        }
    }

    public var color: Color {
        switch self {
        case .high:   return Theme.danger
        case .medium: return Theme.caution
        case .low:    return Theme.warn
        }
    }

    public static func classify(_ flag: String) -> BotFlagSeverity {
        let f = flag.lowercased()
        // High — confident bot signals (mass-follow spam pattern,
        // never-posted follower farms). The trailing keywords per bucket
        // ("mass following", "high following", …) are the pre-rename
        // flag strings still present in cached SwiftData rows — keep
        // them until every cache has been rescanned.
        if f.contains("far more accounts than follow")
            || f.contains("never posted")
            || f.contains("mass following")
            || f.contains("no posts despite") {
            return .high
        }
        // Medium — strong but not conclusive
        if f.contains("few following back")
            || f.contains("hardly ever posts")
            || f.contains("brand-new")
            || f.contains("weeks old")
            || f.contains("missing")
            || f.contains("very few posts")
            || f.contains("new account")
            || f.contains("high following") {
            return .medium
        }
        // Low — informational signals (round following counts, very high
        // follower ratio, mildly follows-heavy ratio).
        return .low
    }
}

// MARK: - Mutual avatar tile

@available(iOS 17, *)
private struct MutualTile: View {
    let mutual: MutualFollow

    var body: some View {
        VStack(spacing: 4) {
            avatar
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.tertiary, lineWidth: 0.5))
            Text("@\(mutual.handle)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 64)
        }
        .accessibilityLabel(mutual.displayName ?? mutual.handle)
        .accessibilityHint("Mutual follow")
    }

    private var avatar: some View {
        Group {
            if let url = mutual.avatar.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(.tint.opacity(0.15))
            .overlay {
                Text(String(mutual.handle.first ?? "?").uppercased())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
            }
    }
}
