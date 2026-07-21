import SwiftUI
import SkymarshalCore

/// How About is hosted — sheet keeps Done; tab is a first-class root surface
/// matching the Figma Make IA (Content / Patterns / Scope / About).
@available(iOS 17, *)
enum AboutPresentation {
    case sheet
    case tab
}

/// The "About Skymarshal" surface. Modeled on whatcolor's
/// `UITableViewController.insetGrouped` shape but native SwiftUI.
///
/// Seven sections — Header / Privacy / Feature lab / Data / Accessibility / Credit / Source.
/// No marketing copy, no jargon. The privacy paragraph is the
/// load-bearing claim of this product; it deserves the second slot.
@available(iOS 17, *)
struct AboutView: View {
    var presentation: AboutPresentation = .sheet

    @Environment(\.dismiss) private var dismiss
    @AppStorage("sm.reduceMotionOverride") private var motionOverride: Bool = false
    @AppStorage(FeatureFlags.backupRestoreKey) private var featureBackupRestore: Bool = false
    @AppStorage(FeatureFlags.visualizationHubKey) private var featureVisualizationHub: Bool = true
    @AppStorage(FeatureFlags.advancedSearchGrammarKey) private var featureAdvancedSearchGrammar: Bool = false
    @AppStorage(FeatureFlags.wordPatternsKey) private var featureWordPatterns: Bool = false
    @AppStorage(FeatureFlags.contentPowerToolsExpandedKey) private var contentPowerToolsExpanded: Bool = false

    private var versionLine: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "v\(v) · build \(b)"
    }

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                privacySection
                featureLabSection
                dataToolsSection
                accessibilitySection
                creditSection
                sourceSection
            }
            .cinematicListChrome()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if presentation == .sheet {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        Section {
            VStack(alignment: .center, spacing: 8) {
                Text("✦")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.cinematicTitleGradient)
                    .accessibilityHidden(true)
                Text("Skymarshal")
                    .font(Theme.Display.title(.title2))
                    .foregroundStyle(Theme.cinematicTitleGradient)
                Text("Air-traffic control for your Bluesky.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(versionLine)
                    .font(Theme.Mono.caption())
                    .foregroundStyle(.tertiary)
                    .textCase(.none)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Theme.elev1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Skymarshal. Air-traffic control for your Bluesky. \(versionLine)")
        }
    }

    @ViewBuilder
    private var privacySection: some View {
        Section {
            Text("Data Not Collected in App Store terms: nothing is sent to Skymarshal servers — there are none. Your handle, archive, and scans stay on this device except when Skymarshal calls Bluesky’s XRPC APIs. No third-party analytics SDKs. Optional Feature lab counters (for example Scope navigation experiments) are stored **only** in local preferences on this device and are never transmitted.")
                .font(.callout)
                .foregroundStyle(.primary)
                .listRowBackground(Theme.elev1)
        } header: {
            Text("Privacy")
                .font(Theme.Mono.kicker())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }

    @ViewBuilder
    private var featureLabSection: some View {
        Section {
            Toggle("Scope tab (visualization hub)", isOn: $featureVisualizationHub)
                .listRowBackground(Theme.elev1)
            Toggle("Advanced search grammar", isOn: $featureAdvancedSearchGrammar)
                .listRowBackground(Theme.elev1)
            Toggle("Word patterns in Insights", isOn: $featureWordPatterns)
                .listRowBackground(Theme.elev1)
            Toggle("Full Content tools strip", isOn: $contentPowerToolsExpanded)
                .listRowBackground(Theme.elev1)
        } header: {
            Text("Feature lab")
                .font(Theme.Mono.kicker())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityIdentifier("about_feature_lab_section_header")
        } footer: {
            Text("Scope ships on by default (Make parity). Other optional surfaces stay opt-in. Content strip shows counts and average engagement under the search bar.")
                .font(.caption2)
        }
    }

    @ViewBuilder
    private var dataToolsSection: some View {
        Section {
            Toggle("Experimental backup & restore", isOn: $featureBackupRestore)
                .listRowBackground(Theme.elev1)
            if featureBackupRestore {
                NavigationLink {
                    BackupRestoreView()
                } label: {
                    Text("Backup & restore…")
                }
                .listRowBackground(Theme.elev1)
            }
        } header: {
            Text("Data")
                .font(Theme.Mono.kicker())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        } footer: {
            Text("Off by default. Import only JSON you exported from Skymarshal for the **same** signed-in handle; the app blocks handle or DID mismatches. Use a trusted device.")
                .font(.caption2)
        }
    }

    @ViewBuilder
    private var accessibilitySection: some View {
        Section {
            Toggle(isOn: $motionOverride) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reduce motion")
                        .font(.callout)
                    Text("In addition to the system setting. Skymarshal already honors Settings → Accessibility → Motion → Reduce Motion; this toggle forces it on for this app only.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Theme.elev1)
            .accessibilityHint("When on, suppresses animations even when the system Reduce Motion is off")

            NavigationLink {
                GuidedModeSettingsView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Guided Mode")
                        .font(.callout)
                    Text("Larger targets, simpler screens, and confirmation styles that suit switch, dwell, and voice access.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Theme.elev1)
            .accessibilityHint("Opens Guided Mode access settings")
        } header: {
            Text("Accessibility")
                .font(Theme.Mono.kicker())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }

    @ViewBuilder
    private var creditSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.cinematicAccentA)
                    .accessibilityHidden(true)
                Text("Made by Luke Steuber")
                    .font(.callout)
            }
            .listRowBackground(Theme.elev1)

            Link(destination: URL(string: "https://lukesteuber.com")!) {
                row(icon: "globe", text: "lukesteuber.com")
            }
            .listRowBackground(Theme.elev1)
            .accessibilityHint("Opens in Safari")

            Link(destination: URL(string: "https://bsky.app/profile/lukesteuber.com")!) {
                row(icon: "at", text: "@lukesteuber.com on Bluesky")
            }
            .listRowBackground(Theme.elev1)
            .accessibilityHint("Opens Bluesky profile in Safari")

            Link(destination: URL(string: "mailto:luke@lukesteuber.com")!) {
                row(icon: "envelope", text: "luke@lukesteuber.com")
            }
            .listRowBackground(Theme.elev1)
            .accessibilityHint("Composes a new email")
        } header: {
            Text("Credit")
                .font(Theme.Mono.kicker())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }

    @ViewBuilder
    private var sourceSection: some View {
        Section {
            Link(destination: URL(string: "https://github.com/lukeslp/skymarshal-ios")!) {
                row(icon: "chevron.left.forwardslash.chevron.right",
                    text: "GitHub: lukeslp/skymarshal-ios")
            }
            .listRowBackground(Theme.elev1)
            .accessibilityHint("Opens repo in Safari")

            Link(destination: URL(string: "https://github.com/lukeslp/skymarshal-ios/blob/main/LICENSE")!) {
                row(icon: "doc.text", text: "MIT License")
            }
            .listRowBackground(Theme.elev1)
            .accessibilityHint("Opens license file in Safari")

            Link(destination: URL(string: "https://github.com/IBM/plex/blob/master/LICENSE.txt")!) {
                row(icon: "textformat", text: "Typography: IBM Plex Mono · SIL OFL 1.1")
            }
            .listRowBackground(Theme.elev1)
            .accessibilityHint("Opens IBM Plex Mono Open Font License in Safari")
        } header: {
            Text("Source")
                .font(Theme.Mono.kicker())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        } footer: {
            Text("Open-source. Free. Not for sale. Skymarshal is not affiliated with Bluesky Social PBC. IBM Plex Mono © 2017 IBM Corp., bundled under SIL OFL 1.1.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func row(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(Theme.cinematicAccentA)
                .symbolRenderingMode(.monochrome)
                .accessibilityHidden(true)
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }
}

@available(iOS 17, *)
#Preview {
    AboutView(presentation: .sheet)
}
