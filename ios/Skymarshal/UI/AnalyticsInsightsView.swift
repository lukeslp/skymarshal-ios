import SwiftUI
import SkymarshalCore

/// On-device archive analytics — no network.
@available(iOS 17, *)
struct AnalyticsInsightsView: View {

    let items: [ContentItem]
    @Environment(\.dismiss) private var dismiss

    private var snapshot: AnalyticsSnapshot {
        AnalyticsService.buildSnapshot(from: items)
    }

    private static let weekdaySymbols: [String] = {
        var cal = Calendar.current
        cal.locale = Locale.current
        return cal.shortWeekdaySymbols
    }()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Posts + replies", value: "\(snapshot.postAndReplyCount)")
                    LabeledContent("Dead threads (no engagement)", value: "\(snapshot.deadThreadCount)")
                    LabeledContent(
                        "High engagement (≥ \(snapshot.highEngagementThreshold))",
                        value: "\(snapshot.highEngagementCount)"
                    )
                } header: {
                    Text("Overview")
                }

                Section {
                    if snapshot.engagementHistogram.isEmpty {
                        Text("No data").foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(snapshot.engagementHistogram.enumerated()), id: \.offset) { idx, count in
                                let lo = idx * snapshot.engagementBucketWidth
                                let hi = lo + snapshot.engagementBucketWidth - 1
                                HStack {
                                    Text("\(lo)–\(hi)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 72, alignment: .leading)
                                    GeometryReader { geo in
                                        let maxC = max(snapshot.engagementHistogram.max() ?? 1, 1)
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.secondary.opacity(0.15))
                                            Capsule()
                                                .fill(Color.accentColor.opacity(0.55))
                                                .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxC))
                                        }
                                    }
                                    .frame(height: 10)
                                    Text("\(count)")
                                        .font(.caption.monospacedDigit())
                                        .frame(width: 36, alignment: .trailing)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Engagement distribution")
                }

                Section {
                    hourHeatRow
                } header: {
                    Text("Posting time (local hour)")
                }

                Section {
                    weekdayRow
                } header: {
                    Text("Posting day")
                }

                Section {
                    if snapshot.topTokens.isEmpty {
                        Text("No text to analyze").foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(snapshot.topTokens.prefix(20)), id: \.token) { pair in
                            HStack {
                                Text(pair.token)
                                Spacer()
                                Text("\(pair.count)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                } header: {
                    Text("Top words")
                } footer: {
                    Text("Words are counted from your post and reply text only — local tokenization, no cloud.")
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var hourHeatRow: some View {
        let maxH = max(snapshot.postsByHourLocal.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<24, id: \.self) { h in
                    let v = snapshot.postsByHourLocal[h]
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.15 + 0.85 * Double(v) / Double(maxH)))
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
