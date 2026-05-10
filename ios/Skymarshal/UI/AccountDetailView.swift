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
    let onUnfollow: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showUnfollowConfirm: Bool = false
    @State private var showInteractions: Bool = false

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

                    if account.lastPostDate != nil || account.isInactive {
                        activitySection
                    }

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
                "Unfollow @\(account.handle)?",
                isPresented: $showUnfollowConfirm
            ) {
                Button("Unfollow", role: .destructive) {
                    onUnfollow()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes you as a follower. They keep their content; you keep yours. Unfollows go through the same rate-limit safety net as deletes.")
            }
            .sheet(isPresented: $showInteractions) {
                InteractionHistoryView(target: account)
            }
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
                }
                Spacer()
            }
        }
    }

    private var activeStatusPills: [(icon: String, label: String, color: Color)] {
        var out: [(String, String, Color)] = []
        if account.isMutual { out.append(("person.2.fill", "Mutual", .accentColor)) }
        if account.isDeleted { out.append(("xmark.octagon.fill", "Deleted", .red)) }
        else if account.isInactive { out.append(("moon.zzz.fill", "Inactive", .orange)) }
        if account.profile.viewer?.muted == true { out.append(("speaker.slash.fill", "Muted", .secondary)) }
        if account.profile.viewer?.blockedBy == true { out.append(("hand.raised.fill", "Blocks you", .red)) }
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
                Text("Why we flagged this account")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                BotScoreBadge(score: account.botScore)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(account.botFlags, id: \.self) { flag in
                    BotFlagRow(flag: flag)
                }
            }

            Text("Bot scoring weighs each factor differently. The score is a weighted average — not every flagged account is a bot.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Activity

    @ViewBuilder
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(account.isInactive ? .orange : .secondary)
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
                    .fill(.orange)
                    .frame(width: 3)
            }
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

            Button(role: .destructive) {
                showUnfollowConfirm = true
            } label: {
                Label("Unfollow", systemImage: "person.crop.circle.badge.minus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
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
        case .high:   return .red
        case .medium: return .orange
        case .low:    return .yellow
        }
    }

    public static func classify(_ flag: String) -> BotFlagSeverity {
        let f = flag.lowercased()
        // High — confident bot signals
        if f.contains("mass following")
            || f.contains("no posts despite")
            || f.contains("deleted account") {
            return .high
        }
        // Medium — strong but not conclusive
        if f.contains("high following")
            || f.contains("very few posts")
            || f.contains("new account")
            || f.contains("missing") {
            return .medium
        }
        // Low — informational signals (round numbers, suspiciously high
        // ratio, young account but sub-flooding, etc.)
        return .low
    }
}
