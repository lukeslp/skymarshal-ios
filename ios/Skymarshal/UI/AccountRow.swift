import SwiftUI
import SkymarshalCore

/// Sibling of `ContentRow` for the followers/bluescreen list. Same
/// rhythm: leading color stripe + inline metadata + body + metric row.
/// The leading stripe color encodes status tier (red bot/deleted,
/// orange suspect, yellow inactive, accent mutual, gray default).
@available(iOS 17, *)
struct AccountRow: View {
    let account: AnalyzedAccount

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Min 56pt outer target — dense bio + badges; HIG floor 44pt
            // with padding for comfortable tap targets at default type.
            Capsule()
                .fill(stripeColor)
                .frame(width: 3)
                .frame(maxHeight: .infinity)
                .accessibilityLabel(stripeAccessibilityLabel)

            VStack(alignment: .leading, spacing: 5) {
                // Header: avatar + name + handle on the left, status
                // pills on the right (mutual / inactive / deleted /
                // bot score). Pills are the smallest possible — the
                // metric line below is for numbers only.
                HStack(spacing: 8) {
                    AccountAvatar(url: account.profile.avatar, handle: account.handle)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(account.profile.displayName ?? account.handle)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text("@\(account.handle)")
                            .font(Theme.Mono.caption(11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    StatusPills(account: account)
                }

                if let bio = account.profile.description, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Metric row: numbers only, all on one line. Single
                // overflow rule (truncate at the right). Influence
                // tier sits at the trailing edge in muted text.
                HStack(spacing: 14) {
                    metric("\(short(account.profile.followersCount))", "person.fill")
                    metric("\(short(account.profile.followsCount))", "person.crop.circle.badge.plus")
                    metric(ratioLabel, "arrow.left.arrow.right")
                    Spacer(minLength: 4)
                    Text(account.influenceTier.label.lowercased())
                        .font(Theme.Mono.caption(11))
                        .foregroundStyle(.tertiary)
                }
                .font(Theme.Mono.tabular(11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
        .frame(minHeight: 56)
    }

    private var stripeColor: Color {
        if account.isDeleted { return Theme.danger }
        // Whitelist override: a user-confirmed real human shouldn't
        // wear a danger/caution stripe just because of low post volume.
        if !account.userWhitelisted {
            if account.botScore >= 0.6 { return Theme.danger }
            if account.botScore >= 0.3 { return Theme.caution }
        }
        if account.isInactive { return Theme.warn }
        if account.isMutual { return Theme.scope }
        return Color.gray.opacity(0.6)
    }

    /// Plain-language summary of what the stripe color means. The
    /// 3pt visual cue is redundant; this label is the non-visual
    /// equivalent that Switch Control / VoiceOver users hear.
    private var stripeAccessibilityLabel: String {
        if account.isDeleted { return "Deleted account" }
        if !account.userWhitelisted {
            if account.botScore >= 0.6 { return "High automation signals" }
            if account.botScore >= 0.3 { return "Moderate automation signals" }
        }
        if account.isInactive { return "Inactive account" }
        if account.isMutual { return "Mutual follow" }
        return "Account"
    }

    private var ratioLabel: String {
        if account.ratio >= 999 { return "∞" }
        return account.ratio < 10
            ? String(format: "%.2f", account.ratio)
            : String(format: "%.0f", account.ratio)
    }

    /// Compact number formatter so 15,195 → "15.2K" and the metric row
    /// stays on a single line. Avoids overlap with status pills above
    /// 1,000-follower influencers.
    private func short(_ n: Int) -> String {
        if n < 1_000 { return n.formatted() }
        if n < 1_000_000 {
            let v = Double(n) / 1_000
            return v >= 100 ? "\(Int(v))K" : String(format: "%.1fK", v)
        }
        let v = Double(n) / 1_000_000
        return v >= 100 ? "\(Int(v))M" : String(format: "%.1fM", v)
    }

    @ViewBuilder
    private func metric(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .labelStyle(.titleAndIcon)
            .symbolRenderingMode(.hierarchical)
    }
}

/// Header status pills: mutual icon + bot/inactive/deleted badges.
/// Each is small and only appears when relevant; collectively they
/// fit on one line inside the AccountRow header without wrapping.
@available(iOS 17, *)
private struct StatusPills: View {
    let account: AnalyzedAccount

    var body: some View {
        HStack(spacing: 4) {
            if account.isMutual {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Mutual")
            }
            if account.isDeleted {
                Pill(systemImage: "xmark.octagon.fill", text: "del", color: Theme.danger)
                    .accessibilityLabel("Deleted account")
            } else if account.isInactive {
                Pill(systemImage: "moon.zzz.fill", text: "idle", color: Theme.caution)
                    .accessibilityLabel("Inactive account")
            }
            // Show the badge only at high-confidence (≥0.6) and only
            // when the user hasn't whitelisted the account. Below 0.6
            // the leading stripe already carries the suspicion signal;
            // a permanent number-badge on the row is dignity-costly
            // when the analyzer is just speculating.
            if account.botScore >= 0.6 && !account.userWhitelisted {
                BotScoreBadge(score: account.botScore)
            }
            // Ghost badge: shown ONLY from the already-cached verdict.
            // Tapping a row never fetches — list scroll stays O(0)
            // network. An uncomputed row (ghostVerdict == nil) and a
            // fail-safe `.unknown` both show nothing; only a confirmed
            // ghost earns the badge.
            if account.ghostVerdict == .ghost {
                Image(systemName: "moon.stars.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.danger)
                    .accessibilityLabel("Ghost — never engages you")
            }
        }
    }

    private struct Pill: View {
        let systemImage: String
        let text: String
        let color: Color

        var body: some View {
            HStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(Theme.Mono.kicker(11))
                    .symbolRenderingMode(.monochrome)
                Text(text.uppercased())
                    .font(Theme.Mono.kicker(11))
                    .tracking(0.1)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(Theme.chipTint(color))
            )
        }
    }
}

@available(iOS 17, *)
struct BotScoreBadge: View {
    let score: Double

    var body: some View {
        ScopePill(
            value: "\(Int(score * 100))",
            label: nil,
            emphasis: emphasis,
            leading: Image(systemName: "ant.fill")
        )
        .accessibilityLabel("Automation signals: \(Int(score * 100)) of 100")
    }

    private var emphasis: ScopePill.Emphasis {
        if score >= 0.6 { return .danger }
        if score >= 0.3 { return .caution }
        return .muted
    }
}

@available(iOS 17, *)
private struct AccountAvatar: View {
    let url: String?
    let handle: String

    var body: some View {
        Group {
            if let url = url.flatMap(URL.init(string:)) {
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
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.tertiary, lineWidth: 0.5))
    }

    private var placeholder: some View {
        Circle()
            .fill(.tint.opacity(0.15))
            .overlay {
                Text(String(handle.first ?? "?").uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }
    }
}
