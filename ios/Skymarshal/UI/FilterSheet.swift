import SwiftUI
import SkymarshalCore

/// Filter editor — date range + paired min/max numeric inputs for the
/// engagement counts. Per the search-UI snippet, NOT range sliders:
/// engagement counts span 0 to "your most viral post" and sliders are
/// unusable across that distribution.
@available(iOS 17, *)
struct FilterSheet: View {

    @Binding var draft: SearchRequest
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date = .distantPast
    @State private var endDate: Date = .distantFuture
    @State private var enableStartDate: Bool = false
    @State private var enableEndDate: Bool = false

    @State private var minLikes: String = ""
    @State private var maxLikes: String = ""
    @State private var minReposts: String = ""
    @State private var maxReposts: String = ""
    @State private var minReplies: String = ""
    @State private var maxReplies: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Dates") {
                    Toggle("After…", isOn: $enableStartDate)
                    if enableStartDate {
                        DatePicker("Earliest", selection: $startDate, displayedComponents: .date)
                    }
                    Toggle("Before…", isOn: $enableEndDate)
                    if enableEndDate {
                        DatePicker("Latest", selection: $endDate, displayedComponents: .date)
                    }
                }

                engagementSection(title: "Likes", min: $minLikes, max: $maxLikes)
                engagementSection(title: "Reposts", min: $minReposts, max: $maxReposts)
                engagementSection(title: "Replies", min: $minReplies, max: $maxReplies)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply() }
                }
            }
            .onAppear(perform: prefill)
        }
    }

    @ViewBuilder
    private func engagementSection(title: String, min: Binding<String>, max: Binding<String>) -> some View {
        Section(title) {
            HStack {
                TextField("min", text: min)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                Text("–").foregroundStyle(.secondary)
                TextField("max", text: max)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func prefill() {
        if let s = draft.startDate { startDate = s; enableStartDate = true }
        if let e = draft.endDate { endDate = e; enableEndDate = true }
        if let r = draft.likes { minLikes = "\(r.lowerBound)"; maxLikes = "\(r.upperBound)" }
        if let r = draft.reposts { minReposts = "\(r.lowerBound)"; maxReposts = "\(r.upperBound)" }
        if let r = draft.replies { minReplies = "\(r.lowerBound)"; maxReplies = "\(r.upperBound)" }
    }

    private func apply() {
        draft.startDate = enableStartDate ? startDate : nil
        draft.endDate = enableEndDate ? endDate : nil
        draft.likes = makeRange(minLikes, maxLikes)
        draft.reposts = makeRange(minReposts, maxReposts)
        draft.replies = makeRange(minReplies, maxReplies)
        dismiss()
    }

    private func makeRange(_ minStr: String, _ maxStr: String) -> ClosedRange<Int>? {
        let lo = Int(minStr.trimmingCharacters(in: .whitespaces))
        let hi = Int(maxStr.trimmingCharacters(in: .whitespaces))
        switch (lo, hi) {
        case (nil, nil):       return nil
        case (let l?, nil):    return l...Int.max
        case (nil, let h?):    return 0...h
        case (let l?, let h?): return l <= h ? l...h : nil
        default:               return nil
        }
    }
}
