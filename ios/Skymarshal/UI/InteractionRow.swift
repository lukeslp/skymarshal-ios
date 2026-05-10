import SwiftUI
import SkymarshalCore

/// One interaction in the InteractionHistoryView list. Same rhythm
/// as ContentRow / AccountRow: leading colored stripe by interaction
/// kind + inline metadata + body.
@available(iOS 17, *)
struct InteractionRow: View {
    let interaction: Interaction

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(stripeColor)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: kindIcon)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(stripeColor)
                    Text(label.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(0.4)
                        .foregroundStyle(.secondary)
                    if let date = interaction.timestamp {
                        Text("·").foregroundStyle(.tertiary)
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 4)
                }

                if let text = interaction.subjectText, !text.isEmpty {
                    Text(text)
                        .font(.callout)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var stripeColor: Color {
        switch interaction.kind {
        case .like:   return .pink
        case .reply:  return Color(red: 0.35, green: 0.78, blue: 0.98)
        case .repost: return Color(red: 0.20, green: 0.78, blue: 0.35)
        }
    }

    private var kindIcon: String {
        switch interaction.kind {
        case .like:   return "heart.fill"
        case .reply:  return "bubble.left.and.text.bubble.right"
        case .repost: return "arrow.2.squarepath"
        }
    }

    /// Direction-aware label so the user can scan "from you" vs
    /// "from them" without parsing the section header.
    private var label: String {
        switch (interaction.kind, interaction.direction) {
        case (.like, .outgoing):   return "You liked"
        case (.like, .incoming):   return "They liked"
        case (.reply, .outgoing):  return "You replied"
        case (.reply, .incoming):  return "They replied"
        case (.repost, .outgoing): return "You reposted"
        case (.repost, .incoming): return "They reposted"
        }
    }
}
