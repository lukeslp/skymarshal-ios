import SwiftUI
import SkymarshalCore

/// The "About Skymarshal" sheet. Modeled on whatcolor's
/// `UITableViewController.insetGrouped` shape but native SwiftUI.
///
/// Seven sections — Header / Privacy / Feature lab / Data / Accessibility / Credit / Source.
/// No marketing copy, no jargon. The privacy paragraph is the
/// load-bearing claim of this product; it deserves the second slot.
@available(iOS 17, *)
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("sm.reduceMotionOverride") private var motionOverride: Bool = false
    @AppStorage(FeatureFlags.backupRestoreKey) private var featureBackupRestore: Bool = false
    @AppStorage(FeatureFlags.visualizationHubKey) private var featureVisualizationHub: Bool = false
    @AppStorage(FeatureFlags.advancedSearchGrammarKey) private var featureAdvancedSearchGrammar: Bool = false
    @AppStorage(FeatureFlags.wordPatternsKey) private var featureWordPatterns: Bool = false
    @AppStorage(FeatureFlags.contentPowerToolsExpandedKey) private var contentPowerToolsExpanded: Bool = false

    private var versionLine: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Version \(v) (build \(b))"
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
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Skymarshal")
                    .font(.title2.weight(.semibold))
                Text("Air-traffic control for your Bluesky.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(versionLine)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .padding(.vertical, 4)
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
        } header: {
            Text("Privacy").font(.subheadline.weight(.semibold))
        }
    }

    @ViewBuilder
    private var featureLabSection: some View {
        Section {
            Toggle("Scope tab (visualization hub)", isOn: $featureVisualizationHub)
            Toggle("Advanced search grammar", isOn: $featureAdvancedSearchGrammar)
            Toggle("Word patterns in Insights", isOn: $featureWordPatterns)
            Toggle("Full Content tools strip", isOn: $contentPowerToolsExpanded)
        } header: {
            Text("Feature lab")
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("about_feature_lab_section_header")
        } footer: {
            Text("Optional surfaces default off except where noted. Scope adds a third tab when on. Content strip shows counts and average engagement under the search bar.")
                .font(.caption2)
        }
    }

    @ViewBuilder
    private var dataToolsSection: some View {
        Section {
            Toggle("Experimental backup & restore", isOn: $featureBackupRestore)
            if featureBackupRestore {
                NavigationLink {
                    BackupRestoreView()
                } label: {
                    Text("Backup & restore…")
                }
            }
        } header: {
            Text("Data").font(.subheadline.weight(.semibold))
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
            .accessibilityHint("When on, suppresses animations even when the system Reduce Motion is off")
        } header: {
            Text("Accessibility").font(.subheadline.weight(.semibold))
        }
    }

    @ViewBuilder
    private var creditSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Made by Luke Steuber")
                    .font(.callout)
            }

            Link(destination: URL(string: "https://lukesteuber.com")!) {
                row(icon: "globe", text: "lukesteuber.com")
            }
            .accessibilityHint("Opens in Safari")

            Link(destination: URL(string: "https://bsky.app/profile/lukesteuber.com")!) {
                row(icon: "at", text: "@lukesteuber.com on Bluesky")
            }
            .accessibilityHint("Opens Bluesky profile in Safari")

            Link(destination: URL(string: "mailto:luke@lukesteuber.com")!) {
                row(icon: "envelope", text: "luke@lukesteuber.com")
            }
            .accessibilityHint("Composes a new email")
        } header: {
            Text("Credit").font(.subheadline.weight(.semibold))
        }
    }

    @ViewBuilder
    private var sourceSection: some View {
        Section {
            Link(destination: URL(string: "https://github.com/lukeslp/skymarshal-ios")!) {
                row(icon: "chevron.left.forwardslash.chevron.right",
                    text: "GitHub: lukeslp/skymarshal-ios")
            }
            .accessibilityHint("Opens repo in Safari")

            Link(destination: URL(string: "https://github.com/lukeslp/skymarshal-ios/blob/main/LICENSE")!) {
                row(icon: "doc.text", text: "MIT License")
            }
            .accessibilityHint("Opens license file in Safari")
        } header: {
            Text("Source").font(.subheadline.weight(.semibold))
        } footer: {
            Text("Open-source. Free. Not for sale. Skymarshal is not affiliated with Bluesky Social PBC.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func row(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.tint)
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
    AboutView()
}
