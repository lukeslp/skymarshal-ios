import WidgetKit
import SwiftUI
import SkymarshalCore

// MARK: - 1. Follow Snapshot

struct HygieneSummaryWidget: Widget {
    let kind = "HygieneSummaryWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            HygieneSummaryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Follow Snapshot")
        .description("Plain-language follower, following, and inactive-account counts.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HygieneSummaryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SkymarshalEntry

    private var h: WidgetSnapshot.HygieneSummary { entry.snapshot.hygieneSummary }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetKicker(text: "Follow snapshot")
            if family == .systemSmall {
                VStack(alignment: .leading, spacing: 6) {
                    WidgetStat(value: "\(h.followers)", label: "Followers", tint: Theme.scope)
                    WidgetStat(value: "\(h.follows)", label: "Following", tint: Theme.success)
                    WidgetStat(value: "\(h.inactive)", label: "Inactive", tint: Theme.warn)
                }
            } else {
                HStack(alignment: .top, spacing: 14) {
                    WidgetStat(value: "\(h.followers)", label: "Followers", tint: Theme.scope)
                    WidgetStat(value: "\(h.follows)", label: "Following", tint: Theme.success)
                    WidgetStat(value: "\(h.inactive)", label: "Inactive", tint: Theme.warn)
                }
                Spacer(minLength: 0)
                Text("Updated after your latest scan")
                    .font(WidgetStyle.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

}

// MARK: - 2. Worth Joining

struct PeopleToEngageWidget: Widget {
    let kind = "PeopleToEngageWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            PeopleToEngageView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Worth Joining")
        .description("Rising posts from people who regularly engage with you.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct PeopleToEngageView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SkymarshalEntry

    private var rowLimit: Int { family == .systemLarge ? 6 : 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetKicker(text: "Worth joining", tint: Theme.caution)
            let posts = Array((entry.snapshot.recommendedPosts ?? []).prefix(rowLimit))
            if posts.isEmpty {
                Text("Run a follower scan to find timely posts from people who engage with you.")
                    .font(WidgetStyle.body)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(posts) { post in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(post.authorTitle)
                                    .font(WidgetStyle.body)
                                    .lineLimit(1)
                                Text(post.text)
                                    .font(WidgetStyle.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            Text("\(post.likeCount)♥")
                                .font(WidgetStyle.metric(13))
                                .foregroundStyle(Theme.caution)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 3. Post Taking Off (Trending post insights widget, modern sans-serif font)

struct PostTakingOffWidget: Widget {
    let kind = "PostTakingOffWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            PostTakingOffView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Your Top Post")
        .description("Your own best-performing recent post at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PostTakingOffView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SkymarshalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetKicker(text: "Your top post", tint: Theme.like)
            if let post = entry.snapshot.topPost {
                Text(post.text.isEmpty ? "(no text)" : post.text)
                    .font(WidgetStyle.body)
                    .lineLimit(family == .systemSmall ? 2 : 3)
                Spacer(minLength: 0)
                HStack(spacing: family == .systemSmall ? 10 : 16) {
                    metric("\(post.likeCount)", "likes", Theme.like)
                    metric("\(post.repostCount)", "reposts", Theme.success)
                    if family != .systemSmall {
                        metric("\(post.replyCount)", "replies", Theme.scope)
                    }
                }
                Text(post.indexedAt.widgetRelative + " ago")
                    .font(WidgetStyle.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No posts yet. Load your content to see what is taking off.")
                    .font(WidgetStyle.body)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func metric(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(WidgetStyle.metric(16)).foregroundStyle(tint)
            Text(label.uppercased()).font(WidgetStyle.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - 4. Follower Trend (Follower count and recent trend sparkline, all text in classy sans-serif)

struct FollowerTrendWidget: Widget {
    let kind = "FollowerTrendWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            FollowerTrendView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Follower Trend")
        .description("Your follower count with a recent sparkline.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FollowerTrendView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SkymarshalEntry

    private var history: [WidgetSnapshot.FollowerPoint] { entry.snapshot.followerHistory }
    private var latest: Int { history.last?.count ?? entry.snapshot.hygieneSummary.followers }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetKicker(text: "Followers", tint: Theme.scope)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(latest)")
                    .font(WidgetStyle.metric(family == .systemSmall ? 22 : 28))
                    .foregroundStyle(.primary)
                if let delta = delta {
                    Text(delta >= 0 ? "+\(delta)" : "\(delta)")
                        .font(WidgetStyle.metric(12))
                        .foregroundStyle(delta >= 0 ? Theme.success : Theme.danger)
                }
            }
            Sparkline(points: history.map { $0.count })
                .stroke(Theme.scope, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(height: family == .systemSmall ? 28 : 44)
                .opacity(history.count > 1 ? 1 : 0.25)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var delta: Int? {
        guard let first = history.first?.count, history.count > 1 else { return nil }
        return latest - first
    }
}

/// Hand-drawn sparkline Path — no Swift Charts dependency, keeps the
/// extension lean.
struct Sparkline: Shape {
    let points: [Int]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else {
            // Flat baseline when there is only one (or no) point.
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
        let minV = points.min() ?? 0
        let maxV = points.max() ?? 0
        let span = max(1, maxV - minV)
        let stepX = rect.width / CGFloat(points.count - 1)
        for (index, value) in points.enumerated() {
            let x = rect.minX + CGFloat(index) * stepX
            let normalized = CGFloat(value - minV) / CGFloat(span)
            let y = rect.maxY - normalized * rect.height
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

// MARK: - 5. Worth Joining Spotlight

struct ReplyBackOfTheDayWidget: Widget {
    let kind = "ReplyBackOfTheDayWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            ReplyBackOfTheDayView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Join In")
        .description("One timely post from someone who regularly engages with you.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct ReplyBackOfTheDayView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SkymarshalEntry

    /// Deterministic per-day pick so the spotlight is stable through the
    /// day and rotates across the neglected set day to day.
    private var pick: WidgetSnapshot.RecommendedPost? {
        let posts = entry.snapshot.recommendedPosts ?? []
        guard !posts.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return posts[day % posts.count]
    }

    var body: some View {
        if family == .accessoryRectangular {
            lockScreen
        } else {
            homeScreen
        }
    }

    @ViewBuilder private var homeScreen: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetKicker(text: "Worth joining", tint: Theme.caution)
            if let post = pick {
                Text(post.authorTitle)
                    .font(WidgetStyle.metric(16))
                    .lineLimit(1)
                Text(post.text)
                    .font(WidgetStyle.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text("\(post.likeCount) likes · \(post.replyCount) replies")
                    .font(WidgetStyle.body)
                    .foregroundStyle(Theme.caution)
            } else {
                Text("Run a follower scan to find a timely post.")
                    .font(WidgetStyle.body)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("WORTH JOINING")
                .font(WidgetStyle.caption.weight(.semibold))
            if let post = pick {
                Text(post.authorTitle).font(WidgetStyle.body).lineLimit(1)
                Text("\(post.likeCount) likes · \(post.replyCount) replies")
                    .font(WidgetStyle.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Run a scan").font(WidgetStyle.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bundle

@main
struct SkymarshalWidgetBundle: WidgetBundle {
    var body: some Widget {
        HygieneSummaryWidget()
        PeopleToEngageWidget()
        PostTakingOffWidget()
        FollowerTrendWidget()
        ReplyBackOfTheDayWidget()
    }
}
