import SwiftUI
import SkymarshalCore

/// Canonical filter editor — dates, engagement, media, advanced keyword
/// grammar, and likes/reposts subject filters. Keyword text lives in the
/// main `.searchable` field; this sheet configures how that text is
/// interpreted plus non-keyword axes.
@available(iOS 17, *)
struct FilterSheet: View {

    @Binding var draft: SearchRequest
    @Binding var keyword: String
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var enableStartDate: Bool = false
    @State private var enableEndDate: Bool = false

    @State private var minLikes: String = ""
    @State private var maxLikes: String = ""
    @State private var minReposts: String = ""
    @State private var maxReposts: String = ""
    @State private var minReplies: String = ""
    @State private var maxReplies: String = ""

    @State private var parseSummary: String = ""

    private var grammarOn: Binding<Bool> {
        Binding(
            get: { draft.advancedKeywordGrammar == true },
            set: { draft.advancedKeywordGrammar = $0 ? true : nil }
        )
    }

    private var subjectUriBinding: Binding<String> {
        Binding(
            get: { draft.subjectUriContains ?? "" },
            set: {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                draft.subjectUriContains = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    private var subjectHandleBinding: Binding<String> {
        Binding(
            get: { draft.subjectHandleContains ?? "" },
            set: {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                draft.subjectHandleContains = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Advanced keyword grammar", isOn: grammarOn)
                        .accessibilityHint("When on, the search field uses plus for required terms, minus to exclude, and quotes for phrases.")
                } header: {
                    Text("Search field")
                        .font(Theme.Mono.kicker())
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Examples: +cats -dogs \"hot take\" hello world  OR  \\bcat\\b for whole-word match.")
                        Text(parseSummary)
                            .foregroundStyle(parseSummary.hasPrefix("Parse error") ? Theme.danger : .secondary)
                    }
                }
                .listRowBackground(Theme.elev1)

                Section {
                    Picker("Media", selection: $draft.mediaFilter) {
                        Text("Any").tag(SearchRequest.MediaFilter?.none)
                        ForEach(SearchRequest.MediaFilter.allCases) { filter in
                            Text(filter.label).tag(SearchRequest.MediaFilter?.some(filter))
                        }
                    }
                    Toggle("Search alt text too", isOn: $draft.includeAltTextInKeyword)
                } header: {
                    Text("Photos & video")
                        .font(Theme.Mono.kicker())
                } footer: {
                    Text("Alt-text search lets you find that capybara post even when you didn't write the word \"capybara.\"")
                }
                .listRowBackground(Theme.elev1)

                Section {
                    Toggle("After…", isOn: $enableStartDate)
                    if enableStartDate {
                        DatePicker(
                            "Earliest",
                            selection: $startDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
                    Toggle("Before…", isOn: $enableEndDate)
                    if enableEndDate {
                        DatePicker(
                            "Latest",
                            selection: $endDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text("Dates")
                        .font(Theme.Mono.kicker())
                }
                .listRowBackground(Theme.elev1)

                engagementSection(title: "Likes", min: $minLikes, max: $maxLikes)
                engagementSection(title: "Reposts", min: $minReposts, max: $maxReposts)
                engagementSection(title: "Replies", min: $minReplies, max: $maxReplies)

                Section {
                    TextField("Substring in at:// URI", text: subjectUriBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Substring in subject handle", text: subjectHandleBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Subject (likes & reposts)")
                        .font(Theme.Mono.kicker())
                } footer: {
                    Text("URI filter matches the liked or reposted post. Handle filter matches the subject author. Posts and replies ignore these fields.")
                }
                .listRowBackground(Theme.elev1)

                Section {
                    TextField("DID substring in URI", text: Binding(
                        get: { draft.authorDid ?? "" },
                        set: {
                            let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                            draft.authorDid = trimmed.isEmpty ? nil : trimmed
                        }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                } header: {
                    Text("Author DID")
                        .font(Theme.Mono.kicker())
                }
                .listRowBackground(Theme.elev1)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .cinematicListChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply() }
                }
            }
            .onAppear {
                prefill()
                refreshParseSummary()
            }
            .onChange(of: keyword) { _, _ in refreshParseSummary() }
            .onChange(of: draft.advancedKeywordGrammar) { _, _ in refreshParseSummary() }
        }
        .cinematicSheetChrome()
        .tint(Theme.cinematicAccentA)
    }

    @ViewBuilder
    private func engagementSection(title: String, min: Binding<String>, max: Binding<String>) -> some View {
        Section {
            HStack {
                TextField("min", text: min)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(Theme.Mono.tabular(15))
                    .accessibilityLabel("\(title) minimum")
                Text("–").foregroundStyle(.secondary).accessibilityHidden(true)
                TextField("max", text: max)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(Theme.Mono.tabular(15))
                    .accessibilityLabel("\(title) maximum")
            }
        } header: {
            Text(title)
                .font(Theme.Mono.kicker())
        }
        .listRowBackground(Theme.elev1)
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
        }
    }

    private func refreshParseSummary() {
        guard draft.advancedKeywordGrammar == true else {
            parseSummary = "Plain substring search uses the search field above the list."
            return
        }
        let raw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            parseSummary = "Enter a search term to preview grammar parsing."
            return
        }
        do {
            let clauses = try SearchKeywordGrammar.parse(raw)
            parseSummary = clauses.isEmpty
                ? "No clauses — other filters still apply."
                : "\(clauses.count) clause\(clauses.count == 1 ? "" : "s") parsed OK."
        } catch {
            parseSummary = "Parse error — fix quotes or \\b…\\b pairs before relying on results."
        }
    }
}
