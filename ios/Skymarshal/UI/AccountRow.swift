import SwiftUI
import SkymarshalCore

/// Sibling of `ContentRow` for the followers/bluescreen list. Same
/// rhythm: leading color stripe + inline metadata + body + metric row.
/// The leading stripe color encodes botScore tier (green/yellow/red);
/// the row's badges show the score, mutual status, and influence tier.
@available(iOS 17, *)
struct AccountRow: View {
    let account: AnalyzedAccount

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(stripeColor)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    AccountAvatar(url: account.profile.avatar, handle: account.handle)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(account.profile.displayName ?? account.handle)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text("@\(account.handle)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if account.isMutual {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Mutual")
                    }
                    if account.botScore > 0 {
                        BotScoreBadge(score: account.botScore)
                    }
                }

                if let bio = account.profile.description, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    metric("\(account.profile.followersCount.formatted())", "person.fill")
                    metric("\(account.profile.followsCount.formatted())", "person.crop.circle.badge.plus")
                    metric(ratioLabel, "arrow.left.arrow.right")
                    if account.isInactive {
                        Label("inactive", systemImage: "moon.zzz")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    if account.isDeleted {
                        Label("deleted", systemImage: "xmark.octagon")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    Text(account.influenceTier.label.lowercased())
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var stripeColor: Color {
        if account.isDeleted { return .red }
        if account.botScore >= 0.6 { return .red }
        if account.botScore >= 0.3 { return .orange }
        if account.isInactive { return .yellow }
        if account.isMutual { return .accentColor }
        return Color.gray.opacity(0.6)
    }

    private var ratioLabel: String {
        if account.ratio >= 999 { return "∞" }
        return account.ratio < 10
            ? String(format: "%.2f", account.ratio)
            : String(format: "%.0f", account.ratio)
    }

    @ViewBuilder
    private func metric(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .labelStyle(.titleAndIcon)
            .symbolRenderingMode(.hierarchical)
    }
}

@available(iOS 17, *)
struct BotScoreBadge: View {
    let score: Double

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "ant.fill")
                .font(.system(size: 9))
            Text("\(Int(score * 100))")
                .font(.caption2.weight(.semibold).monospacedDigit())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15), in: .capsule)
        .accessibilityLabel("Bot score \(Int(score * 100)) of 100")
    }

    private var color: Color {
        if score >= 0.6 { return .red }
        if score >= 0.3 { return .orange }
        return .secondary
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
