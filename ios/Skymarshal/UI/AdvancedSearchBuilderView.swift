import SwiftUI
import SkymarshalCore

/// Power search: upstream-style keyword grammar (+required, -excluded,
/// "phrase", OR plain terms, `\bword\b`) plus subject URI substring filter.
@available(iOS 17, *)
struct AdvancedSearchBuilderView: View {

    @Binding var keyword: String
    @Binding var filters: SearchRequest
    @Environment(\.dismiss) private var dismiss

    @State private var parseSummary: String = ""

    private var grammarOn: Binding<Bool> {
        Binding(
            get: { filters.advancedKeywordGrammar == true },
            set: { filters.advancedKeywordGrammar = $0 ? true : nil }
        )
    }

    private var subjectUriBinding: Binding<String> {
        Binding(
            get: { filters.subjectUriContains ?? "" },
            set: { filters.subjectUriContains = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }

    private var subjectHandleBinding: Binding<String> {
        Binding(
            get: { filters.subjectHandleContains ?? "" },
            set: { filters.subjectHandleContains = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Advanced keyword grammar", isOn: grammarOn)
                        .accessibilityHint("When on, use plus for required terms, minus to exclude, quotes for phrases, or space-separated OR terms.")
                } header: {
                    Text("Grammar")
                } footer: {
                    Text("Examples: +cats -dogs \"hot take\" hello world  OR  \\bcat\\b for whole-word match.")
                }

                Section {
                    TextField("Expression", text: $keyword, axis: .vertical)
                        .lineLimit(3...8)
                        .font(.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Keyword expression")
                } footer: {
                    Text(parseSummary)
                        .foregroundStyle(parseSummary.hasPrefix("Parse error") ? Theme.danger : .secondary)
                }

                Section {
                    TextField("Substring in at:// URI", text: subjectUriBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Substring in subject handle", text: subjectHandleBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Subject (likes & reposts)")
                } footer: {
                    Text("URI filter matches the liked/reposted post's at:// URI. Handle filter matches the subject author's handle (populated when you load content). Posts and replies are not filtered by these fields.")
                }

                Section {
                    TextField("DID substring in URI", text: Binding(
                        get: { filters.authorDid ?? "" },
                        set: { filters.authorDid = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                } header: {
                    Text("Author DID")
                }
            }
            .navigationTitle("Advanced search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: refreshParseSummary)
            .onChange(of: keyword) { _, _ in refreshParseSummary() }
            .onChange(of: filters.advancedKeywordGrammar) { _, _ in refreshParseSummary() }
        }
    }

    private func refreshParseSummary() {
        guard filters.advancedKeywordGrammar == true else {
            parseSummary = "Plain substring search uses the main search field."
            return
        }
        let raw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            parseSummary = "Enter an expression to preview."
            return
        }
        do {
            let clauses = try SearchKeywordGrammar.parse(raw)
            parseSummary = clauses.isEmpty
                ? "No clauses — matches everything on other filter axes."
                : "\(clauses.count) clause\(clauses.count == 1 ? "" : "s") parsed OK."
        } catch {
            parseSummary = "Parse error — fix quotes or \\b…\\b pairs before relying on results."
        }
    }
}
