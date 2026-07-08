import SwiftUI
import SkymarshalCore

/// Horizontally-scrolling chips above the result list, one per active
/// non-default filter. Each is tappable to clear that one filter — solves
/// "why are my results empty" without extra documentation.
@available(iOS 17, *)
struct ActiveFilterChips: View {

    @Binding var filters: SearchRequest

    var body: some View {
        let chips = describeChips()
        if chips.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.id) { chip in
                        Button {
                            chip.clear(&filters)
                        } label: {
                            HStack(spacing: 4) {
                                Text(chip.label)
                                    .font(.caption)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            // .primary foreground + a slightly heavier
                            // tint background — adapts cleanly across
                            // light/dark modes regardless of accent
                            // saturation. Per technical-committee tester
                            // verdict: the previous `.tint`-on-`.tint`
                            // chip was illegible in light mode.
                            .background(.tint.opacity(0.25), in: .capsule)
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
            .contentMargins(.trailing, 24, for: .scrollContent)
        }
    }

    private func describeChips() -> [Chip] {
        var chips: [Chip] = []
        if let start = filters.startDate {
            chips.append(Chip(id: "start", label: "after \(short(start))") { $0.startDate = nil })
        }
        if let end = filters.endDate {
            chips.append(Chip(id: "end", label: "before \(short(end))") { $0.endDate = nil })
        }
        if let r = filters.likes {
            chips.append(Chip(id: "likes", label: "likes \(rangeLabel(r))") { $0.likes = nil })
        }
        if let r = filters.reposts {
            chips.append(Chip(id: "reposts", label: "reposts \(rangeLabel(r))") { $0.reposts = nil })
        }
        if let r = filters.replies {
            chips.append(Chip(id: "replies", label: "replies \(rangeLabel(r))") { $0.replies = nil })
        }
        if let m = filters.mediaFilter {
            chips.append(Chip(id: "media", label: m.label.lowercased()) { $0.mediaFilter = nil })
        }
        if filters.advancedKeywordGrammar == true {
            chips.append(Chip(id: "grammar", label: "grammar mode") { $0.advancedKeywordGrammar = nil })
        }
        if let sub = filters.subjectUriContains, !sub.isEmpty {
            chips.append(Chip(id: "suburi", label: "uri ⊃ \(shortSnippet(sub))") { $0.subjectUriContains = nil })
        }
        if let handle = filters.subjectHandleContains, !handle.isEmpty {
            chips.append(Chip(id: "subhandle", label: "handle ⊃ \(shortSnippet(handle))") { $0.subjectHandleContains = nil })
        }
        if let did = filters.authorDid, !did.isEmpty {
            chips.append(Chip(id: "authordid", label: "author \(shortSnippet(did))") { $0.authorDid = nil })
        }
        return chips
    }

    private func shortSnippet(_ s: String) -> String {
        if s.count <= 18 { return s }
        return String(s.prefix(15)) + "…"
    }

    private func short(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func rangeLabel(_ r: ClosedRange<Int>) -> String {
        if r.upperBound >= Int.max { return "\(r.lowerBound)+" }
        if r.lowerBound == 0 { return "≤\(r.upperBound)" }
        return "\(r.lowerBound)–\(r.upperBound)"
    }

    private struct Chip {
        let id: String
        let label: String
        let clear: (inout SearchRequest) -> Void
    }
}
