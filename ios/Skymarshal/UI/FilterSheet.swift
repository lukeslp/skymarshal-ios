import SwiftUI
import SkymarshalCore

/// Make-style advanced search editor backed by the native SearchRequest model.
///
/// Inputs: draft filters, the visible keyword, selected content types, and the
/// already-loaded archive. Output: an applied grammar expression and filters;
/// the live estimate is local-only and never triggers a network request.
@available(iOS 17, *)
struct FilterSheet: View {
    @Binding var draft: SearchRequest
    @Binding var keyword: String
    @Binding var selectedTypes: Set<ContentType>
    let items: [ContentItem]
    /// True while the archive scan is still paginating — the estimate
    /// only covers what's loaded so far, and the card says so.
    var isArchiveLoading: Bool = false
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var requiredTerms: [String] = []
    @State private var excludedTerms: [String] = []
    @State private var preservedClauses: [String] = []
    @State private var exactPhrase = ""
    @State private var pendingTerm = ""
    @State private var termMode: TermMode = .required
    @State private var draftTypes: Set<ContentType> = []

    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var enableStartDate = false
    @State private var enableEndDate = false

    @State private var minLikes = ""
    @State private var maxLikes = ""
    @State private var minReposts = ""
    @State private var maxReposts = ""
    @State private var minReplies = ""
    @State private var maxReplies = ""
    @State private var showMoreFilters = false
    @State private var didPrefill = false
    @State private var originalKeyword = ""
    @State private var originalAdvancedGrammar = false
    @State private var keywordBuilderEdited = false
    @FocusState private var focusedEngagementField: EngagementField?

    private enum TermMode: String, CaseIterable, Identifiable {
        case required
        case excluded

        var id: String { rawValue }
        var label: String { self == .required ? "+ Required" : "− Exclude" }
        var color: Color { self == .required ? Theme.cinematicAccentA : Theme.danger }
    }

    private enum EngagementField: Hashable {
        case likesMin, likesMax
        case repostsMin, repostsMax
        case repliesMin, repliesMax
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    keywordSection
                    phraseSection
                    contentTypesSection
                    datesSection
                    estimateCard
                    moreFiltersSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .cinematicListChrome()
            .navigationTitle("Advanced Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply Search") { apply() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedEngagementField = nil
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Apply Search") { apply() }
                    .buttonStyle(SaturnButton(emphasis: .primaryCinematic))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.elev1)
            }
            .onAppear(perform: prefill)
        }
        .cinematicSheetChrome()
        .tint(Theme.cinematicAccentA)
    }

    private var keywordSection: some View {
        searchCard(title: "KEYWORDS") {
            HStack(spacing: 6) {
                ForEach(TermMode.allCases) { mode in
                    Button {
                        termMode = mode
                    } label: {
                        Text(mode.label)
                            .font(Theme.Mono.kicker(10))
                            .foregroundStyle(
                                termMode == mode ? Color.primary : Color.secondary
                            )
                            .padding(.horizontal, 9)
                            .frame(minHeight: 44)
                            .background {
                                RoundedRectangle(
                                    cornerRadius: Theme.Radius.sm,
                                    style: .continuous
                                )
                                .fill(
                                    termMode == mode
                                        ? Theme.chipTint(mode.color)
                                        : Theme.elev2
                                )
                                .overlay {
                                    RoundedRectangle(
                                        cornerRadius: Theme.Radius.sm,
                                        style: .continuous
                                    )
                                    .strokeBorder(
                                        termMode == mode
                                            ? mode.color.opacity(0.4)
                                            : Theme.hairline,
                                        lineWidth: 1
                                    )
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(termMode == mode ? [.isSelected] : [])
                }
            }

            HStack(spacing: 8) {
                TextField("Add keyword…", text: $pendingTerm)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(addPendingTerm)
                    .cinematicInputWell()

                Button(action: addPendingTerm) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .symbolRenderingMode(.monochrome)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(termMode.color)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.chipTint(termMode.color))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(termMode.color.opacity(0.4), lineWidth: 1)
                        }
                }
                .accessibilityLabel("Add \(termMode.rawValue) keyword")
            }

            if !requiredTerms.isEmpty || !excludedTerms.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 94), spacing: 5)],
                    alignment: .leading,
                    spacing: 5
                ) {
                    ForEach(requiredTerms, id: \.self) { term in
                        termChip(term, mode: .required)
                    }
                    ForEach(excludedTerms, id: \.self) { term in
                        termChip(term, mode: .excluded)
                    }
                }
            }
        }
    }

    private var phraseSection: some View {
        searchCard(title: "EXACT PHRASE") {
            HStack(spacing: 8) {
                Image(systemName: "number")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                TextField(#""must appear together""#, text: Binding(
                    get: { exactPhrase },
                    set: {
                        exactPhrase = $0
                        keywordBuilderEdited = true
                    }
                ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .cinematicInputWell()
        }
    }

    private var contentTypesSection: some View {
        searchCard(title: "CONTENT TYPES") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 80), spacing: 6)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(ContentType.selectable) { type in
                    let active = draftTypes.contains(type)
                    Button {
                        if active { draftTypes.remove(type) }
                        else { draftTypes.insert(type) }
                    } label: {
                        Text(type.label)
                            .font(.subheadline)
                            .foregroundStyle(active ? Color.primary : Color.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background {
                                RoundedRectangle(
                                    cornerRadius: Theme.Radius.sm,
                                    style: .continuous
                                )
                                .fill(
                                    active
                                        ? Theme.cinematicAccentA.opacity(0.14)
                                        : Theme.elev2
                                )
                                .overlay {
                                    RoundedRectangle(
                                        cornerRadius: Theme.Radius.sm,
                                        style: .continuous
                                    )
                                    .strokeBorder(
                                        active
                                            ? Theme.cinematicAccentA.opacity(0.45)
                                            : Theme.hairline,
                                        lineWidth: 1
                                    )
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? [.isSelected] : [])
                }
            }
        }
    }

    private var datesSection: some View {
        searchCard(title: "DATE RANGE") {
            Toggle("From date", isOn: $enableStartDate)
            if enableStartDate {
                DatePicker(
                    "From",
                    selection: $startDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            }
            Toggle("To date", isOn: $enableEndDate)
            if enableEndDate {
                DatePicker(
                    "To",
                    selection: $endDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            }
        }
    }

    private var estimateCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(estimatedMatches.formatted())
                    .font(Theme.Mono.tabular(20))
                    .fontWeight(.bold)
                Text(isArchiveLoading
                     ? "ESTIMATED MATCHES (archive still loading)"
                     : "ESTIMATED MATCHES")
                    .font(Theme.Mono.kicker(10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if hasNoNarrowingFilters {
                Text("Add filters to narrow")
                    .font(Theme.Mono.caption(10))
                    .foregroundStyle(Theme.caution)
            }
        }
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.elev2)
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isArchiveLoading
                ? "\(estimatedMatches) estimated matches in the loaded archive. The archive is still loading, so this count is incomplete."
                : "\(estimatedMatches) estimated matches in the loaded archive"
        )
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var moreFiltersSection: some View {
        DisclosureGroup("More filters", isExpanded: $showMoreFilters) {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Photos & video", selection: $draft.mediaFilter) {
                    Text("Any").tag(SearchRequest.MediaFilter?.none)
                    ForEach(SearchRequest.MediaFilter.allCases) { filter in
                        Text(filter.label).tag(SearchRequest.MediaFilter?.some(filter))
                    }
                }
                Toggle("Search alt text too", isOn: $draft.includeAltTextInKeyword)

                engagementRange(
                    "Likes",
                    min: $minLikes,
                    max: $maxLikes,
                    minField: .likesMin,
                    maxField: .likesMax
                )
                engagementRange(
                    "Reposts",
                    min: $minReposts,
                    max: $maxReposts,
                    minField: .repostsMin,
                    maxField: .repostsMax
                )
                engagementRange(
                    "Replies",
                    min: $minReplies,
                    max: $maxReplies,
                    minField: .repliesMin,
                    maxField: .repliesMax
                )

                TextField(
                    "Subject at:// URI (likes & reposts)",
                    text: optionalBinding(\.subjectUriContains)
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .cinematicInputWell()

                TextField(
                    "Subject handle (likes & reposts)",
                    text: optionalBinding(\.subjectHandleContains)
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .cinematicInputWell()

                TextField("Author DID", text: optionalBinding(\.authorDid))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .cinematicInputWell()
            }
            .padding(.top, 12)
        }
        .font(.subheadline.weight(.semibold))
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.elev1)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }
        }
    }

    private func searchCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.Mono.kicker())
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func termChip(_ term: String, mode: TermMode) -> some View {
        HStack(spacing: 4) {
            Image(systemName: mode == .required ? "plus" : "minus")
                .font(.system(size: 9, weight: .bold))
                .accessibilityHidden(true)
            Text(term)
                .font(Theme.Mono.caption(10))
                .lineLimit(1)
            Button {
                keywordBuilderEdited = true
                if mode == .required {
                    requiredTerms.removeAll { $0 == term }
                } else {
                    excludedTerms.removeAll { $0 == term }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(mode.rawValue) keyword \(term)")
        }
        .foregroundStyle(mode.color)
        .padding(.leading, 7)
        .padding(.trailing, 2)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(Theme.chipTint(mode.color))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .strokeBorder(mode.color.opacity(0.4), lineWidth: 1)
                }
        }
    }

    private func engagementRange(
        _ title: String,
        min: Binding<String>,
        max: Binding<String>,
        minField: EngagementField,
        maxField: EngagementField
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(Theme.Mono.kicker(10))
                .foregroundStyle(.tertiary)
            HStack {
                TextField("min", text: min)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(Theme.Mono.tabular(14))
                    .cinematicInputWell()
                    .focused($focusedEngagementField, equals: minField)
                    .accessibilityLabel("\(title) minimum")
                Text("–").foregroundStyle(.secondary).accessibilityHidden(true)
                TextField("max", text: max)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(Theme.Mono.tabular(14))
                    .cinematicInputWell()
                    .focused($focusedEngagementField, equals: maxField)
                    .accessibilityLabel("\(title) maximum")
            }
        }
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<SearchRequest, String?>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                draft[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    private var composedKeyword: String {
        var parts = preservedClauses
        parts.append(contentsOf: requiredTerms.map { "+\(escapedToken($0))" })
        parts.append(contentsOf: excludedTerms.map { "-\(escapedToken($0))" })
        let phrase = exactPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        if !phrase.isEmpty {
            parts.append("\"\(phrase.replacingOccurrences(of: "\"", with: ""))\"")
        }
        return parts.joined(separator: " ")
    }

    private var estimatedMatches: Int {
        var request = draft
        let expression = composedKeyword
        request.keyword = expression.isEmpty ? nil : expression
        request.advancedKeywordGrammar = expression.isEmpty ? nil : true
        request.contentTypes = draftTypes.isSuperset(of: ContentType.selectable)
            ? nil
            : draftTypes
        request.startDate = enableStartDate ? startDate : nil
        request.endDate = enableEndDate ? endDate : nil
        request.likes = makeRange(minLikes, maxLikes)
        request.reposts = makeRange(minReposts, maxReposts)
        request.replies = makeRange(minReplies, maxReplies)
        return request.apply(to: items).count
    }

    private var hasNoNarrowingFilters: Bool {
        composedKeyword.isEmpty
            && draftTypes.isSuperset(of: ContentType.selectable)
            && !enableStartDate
            && !enableEndDate
            && !draft.hasActiveFilters
    }

    private func prefill() {
        guard !didPrefill else { return }
        originalKeyword = keyword
        originalAdvancedGrammar = draft.advancedKeywordGrammar == true
        draftTypes = selectedTypes.isEmpty ? Set(ContentType.selectable) : selectedTypes
        if let date = draft.startDate { startDate = date; enableStartDate = true }
        if let date = draft.endDate { endDate = date; enableEndDate = true }
        if let range = draft.likes {
            minLikes = "\(range.lowerBound)"
            maxLikes = range.upperBound == Int.max ? "" : "\(range.upperBound)"
        }
        if let range = draft.reposts {
            minReposts = "\(range.lowerBound)"
            maxReposts = range.upperBound == Int.max ? "" : "\(range.upperBound)"
        }
        if let range = draft.replies {
            minReplies = "\(range.lowerBound)"
            maxReplies = range.upperBound == Int.max ? "" : "\(range.upperBound)"
        }
        prefillKeywordParts()
        didPrefill = true
    }

    private func prefillKeywordParts() {
        let raw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        guard draft.advancedKeywordGrammar == true,
              let clauses = try? SearchKeywordGrammar.parse(raw) else {
            // Preserve ordinary substring semantics if the user opens and
            // applies Advanced Search without editing the keyword builder.
            // If they add a structured clause later, quoting this text keeps
            // the original multi-word substring requirement intact.
            exactPhrase = raw
            return
        }
        for clause in clauses {
            switch clause {
            case .required(let value):
                requiredTerms = uniqueAppending(value, to: requiredTerms)
            case .excluded(let value):
                excludedTerms = uniqueAppending(value, to: excludedTerms)
            case .phrase(let value):
                if exactPhrase.isEmpty {
                    exactPhrase = value
                } else {
                    preservedClauses.append("\"\(value)\"")
                }
            case .plain(let value):
                preservedClauses.append(value)
            case .wordBoundary(let value):
                preservedClauses.append("\\b\(value)\\b")
            }
        }
    }

    private func addPendingTerm() {
        let value = pendingTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        keywordBuilderEdited = true
        if termMode == .required {
            requiredTerms = uniqueAppending(value, to: requiredTerms)
        } else {
            excludedTerms = uniqueAppending(value, to: excludedTerms)
        }
        pendingTerm = ""
    }

    private func uniqueAppending(_ value: String, to values: [String]) -> [String] {
        guard !values.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else {
            return values
        }
        return values + [value]
    }

    private func escapedToken(_ value: String) -> String {
        value
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private func apply() {
        if keywordBuilderEdited {
            keyword = composedKeyword
            draft.advancedKeywordGrammar = composedKeyword.isEmpty ? nil : true
        } else {
            keyword = originalKeyword
            draft.advancedKeywordGrammar = originalAdvancedGrammar ? true : nil
        }
        selectedTypes = draftTypes
        draft.startDate = enableStartDate ? startDate : nil
        draft.endDate = enableEndDate ? endDate : nil
        draft.likes = makeRange(minLikes, maxLikes)
        draft.reposts = makeRange(minReposts, maxReposts)
        draft.replies = makeRange(minReplies, maxReplies)
        onApply()
        dismiss()
    }

    private func makeRange(_ minString: String, _ maxString: String) -> ClosedRange<Int>? {
        let lower = Int(minString.trimmingCharacters(in: .whitespaces))
        let upper = Int(maxString.trimmingCharacters(in: .whitespaces))
        switch (lower, upper) {
        case (nil, nil): return nil
        case (let value?, nil): return value...Int.max
        case (nil, let value?): return 0...value
        case (let low?, let high?): return low <= high ? low...high : nil
        }
    }
}

@available(iOS 17, *)
private extension View {
    func cinematicInputWell() -> some View {
        padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.elev2)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    }
            }
    }
}
