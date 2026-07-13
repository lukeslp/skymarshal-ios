import SwiftUI
import SkymarshalCore

/// Full filter editor for the Followers tab — exposes all 25 axes
/// of FollowerFilters that previously lived only in the model.
/// Modeled on FilterSheet (the Content tab's filter editor), with
/// a draft/applied split so partial edits don't refilter mid-stream.
@available(iOS 17, *)
struct BluescreenFilterSheet: View {

    @Binding var draft: FollowerFilters
    @Environment(\.dismiss) private var dismiss

    @State private var minBotPct: String = ""
    @State private var maxBotPct: String = ""
    @State private var minFollowers: String = ""
    @State private var maxFollowers: String = ""
    @State private var minFollowing: String = ""
    @State private var maxFollowing: String = ""
    @State private var minAgeDays: String = ""
    @State private var maxAgeDays: String = ""
    @State private var minPostsPerDay: String = ""
    @State private var maxPostsPerDay: String = ""
    @State private var minCompletenessPct: String = ""

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                botScoreSection
                influenceSection
                accountAgeSection
                activitySection
                profileBitsSection
                sortSection
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
                if draft.hasActiveFilters {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Reset", role: .destructive) {
                            draft = FollowerFilters()
                            prefill()
                        }
                    }
                }
            }
            .onAppear(perform: prefill)
        }
        .cinematicSheetChrome()
        .tint(Theme.cinematicAccentA)
    }

    // MARK: - Sections

    @ViewBuilder
    private var statusSection: some View {
        Section("Status") {
            Toggle("Bots only (score ≥ 0.6)", isOn: $draft.showBots)
            Toggle("Inactive only", isOn: $draft.showInactive)
            Toggle("Deleted only", isOn: $draft.showDeleted)
            Toggle("Disengaged only", isOn: $draft.showDisengaged)
            Toggle("Mutuals only", isOn: $draft.showMutualOnly)
            Toggle("Non-mutuals only", isOn: $draft.showNonMutualOnly)
            Toggle("Muted only", isOn: $draft.showMuted)
            Toggle("Blocked-by only", isOn: $draft.showBlocked)
            Toggle("Follows-heavy (ratio < 0.1)", isOn: $draft.showBadRatio)
        }
    }

    @ViewBuilder
    private var botScoreSection: some View {
        Section {
            HStack {
                TextField("min %", text: $minBotPct)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                Text("–").foregroundStyle(.secondary)
                TextField("max %", text: $maxBotPct)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
            }
        } header: {
            Text("Bot score")
        } footer: {
            Text("0–100. Set min to 60 to find probable bots; min 30 catches looser suspects.")
        }
    }

    @ViewBuilder
    private var influenceSection: some View {
        Section("Followers / Following / Influence") {
            rangeRow("Followers", min: $minFollowers, max: $maxFollowers)
            rangeRow("Following", min: $minFollowing, max: $maxFollowing)
            Picker("Influence tier", selection: $draft.influenceTier) {
                Text("Any").tag(InfluenceTier?.none)
                ForEach(InfluenceTier.allCases, id: \.self) { tier in
                    Text(tier.label).tag(InfluenceTier?.some(tier))
                }
            }
        }
    }

    @ViewBuilder
    private var accountAgeSection: some View {
        Section {
            rangeRow("Age (days)", min: $minAgeDays, max: $maxAgeDays)
            rangeRow("Posts / day", min: $minPostsPerDay, max: $maxPostsPerDay, decimal: true)
        } header: {
            Text("Account age & activity")
        } footer: {
            Text("Posts/day above 50 is unusual for a real user.")
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        Section("Profile completeness") {
            HStack {
                Text("Min %").foregroundStyle(.secondary)
                Spacer()
                TextField("0", text: $minCompletenessPct)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
            }
        }
    }

    @ViewBuilder
    private var profileBitsSection: some View {
        Section("Profile bits") {
            tristate("Has avatar", value: $draft.hasAvatar)
            tristate("Has description", value: $draft.hasDescription)
            tristate("Has banner", value: $draft.hasBanner)
            tristate("Has labels", value: $draft.hasLabels)
        }
    }

    @ViewBuilder
    private var sortSection: some View {
        Section("Sort") {
            Picker("Sort by", selection: $draft.sortField) {
                ForEach(FollowerFilters.SortField.allCases) { field in
                    Text(field.label).tag(field)
                }
            }
            Picker("Direction", selection: $draft.sortDirection) {
                Text("Descending").tag(FollowerFilters.SortDirection.desc)
                Text("Ascending").tag(FollowerFilters.SortDirection.asc)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func rangeRow(
        _ label: String,
        min: Binding<String>,
        max: Binding<String>,
        decimal: Bool = false
    ) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            TextField("min", text: min)
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 70)
                .accessibilityLabel("\(label) minimum")
            Text("–").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField("max", text: max)
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 70)
                .accessibilityLabel("\(label) maximum")
        }
    }

    @ViewBuilder
    private func tristate(_ label: String, value: Binding<Bool?>) -> some View {
        Picker(label, selection: value) {
            Text("Any").tag(Bool?.none)
            Text("Yes").tag(Bool?.some(true))
            Text("No").tag(Bool?.some(false))
        }
    }

    private func prefill() {
        // Bot score 0-1 → render 0-100
        if let v = draft.minBotScore { minBotPct = String(Int(v * 100)) } else { minBotPct = "" }
        if let v = draft.maxBotScore { maxBotPct = String(Int(v * 100)) } else { maxBotPct = "" }

        if let v = draft.minFollowers { minFollowers = String(v) } else { minFollowers = "" }
        if let v = draft.maxFollowers { maxFollowers = String(v) } else { maxFollowers = "" }
        if let v = draft.minFollowing { minFollowing = String(v) } else { minFollowing = "" }
        if let v = draft.maxFollowing { maxFollowing = String(v) } else { maxFollowing = "" }
        if let v = draft.minAccountAgeDays { minAgeDays = String(v) } else { minAgeDays = "" }
        if let v = draft.maxAccountAgeDays { maxAgeDays = String(v) } else { maxAgeDays = "" }
        if let v = draft.minPostsPerDay { minPostsPerDay = String(v) } else { minPostsPerDay = "" }
        if let v = draft.maxPostsPerDay { maxPostsPerDay = String(v) } else { maxPostsPerDay = "" }
        if let v = draft.minProfileCompleteness {
            minCompletenessPct = String(Int(v * 100))
        } else {
            minCompletenessPct = ""
        }
    }

    private func apply() {
        draft.minBotScore = parsePercent(minBotPct)
        draft.maxBotScore = parsePercent(maxBotPct)
        draft.minFollowers = parseInt(minFollowers)
        draft.maxFollowers = parseInt(maxFollowers)
        draft.minFollowing = parseInt(minFollowing)
        draft.maxFollowing = parseInt(maxFollowing)
        draft.minAccountAgeDays = parseInt(minAgeDays)
        draft.maxAccountAgeDays = parseInt(maxAgeDays)
        draft.minPostsPerDay = parseDouble(minPostsPerDay)
        draft.maxPostsPerDay = parseDouble(maxPostsPerDay)
        draft.minProfileCompleteness = parsePercent(minCompletenessPct)
        dismiss()
    }

    private func parseInt(_ s: String) -> Int? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : Int(t)
    }

    private func parseDouble(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : Double(t)
    }

    private func parsePercent(_ s: String) -> Double? {
        guard let i = parseInt(s) else { return nil }
        return Double(min(max(i, 0), 100)) / 100.0
    }
}
