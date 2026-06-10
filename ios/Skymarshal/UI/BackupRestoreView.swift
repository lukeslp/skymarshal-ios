import SwiftUI
import UniformTypeIdentifiers
import SkymarshalCore

/// JSON backup import with integrity checks and merge/replace apply.
@available(iOS 17, *)
struct BackupRestoreView: View {

    @Environment(AppModel.self) private var model
    @State private var showImporter = false
    @State private var importError: String?
    @State private var outcome: ContentBackupImport.DecodeOutcome?
    @State private var preview: ContentBackupImport.RestorePreviewSummary?
    @State private var mode: ContentService.BackupImportMode = .mergeByURI
    @State private var isApplying = false

    var body: some View {
        Form {
            Section {
                Button("Choose JSON backup…") { showImporter = true }
                    .disabled(!model.isAuthenticated)
                if !model.isAuthenticated {
                    StatusLine(
                        style: .warning,
                        title: "Sign in required",
                        subtitle: "Handle/DID must match the backup envelope before import."
                    )
                }
                if let err = importError {
                    StatusLine(
                        style: .danger,
                        title: "Couldn't import that file",
                        subtitle: err
                    )
                }
            } footer: {
                Text("Exports from this app include handle and DID. Import applies only while signed in; both values must match the backup envelope. Any malformed or cross-account delete target blocks the entire import. Replace all clears cached content rows for this signed-in owner on this device, then writes the import.")
            }

            if let outcome {
                Section {
                    if let preview {
                        LabeledContent("Rows to import", value: "\(preview.importedCount)")
                        LabeledContent("Rows in archive", value: "\(preview.currentCount)")
                        LabeledContent("New URIs", value: "\(preview.onlyInImport)")
                        LabeledContent("URIs only in archive", value: "\(preview.onlyInCurrent)")
                        if preview.skippedUnsafeLikeRepost > 0 {
                            LabeledContent("Skipped (unsafe like/repost)", value: "\(preview.skippedUnsafeLikeRepost)")
                        }
                    }
                    Picker("Apply mode", selection: $mode) {
                        Text("Merge by URI").tag(ContentService.BackupImportMode.mergeByURI)
                        Text("Replace all").tag(ContentService.BackupImportMode.replaceAll)
                    }
                    // Lifted from a plain `Button` to ActionRow so the
                    // primary destination of this screen has a touchable
                    // surface that matches Skymarshal's other action
                    // surfaces (Export, Scan). Keeps the existing
                    // disabled-during-apply behavior + ProgressView via
                    // ActionRow's busy state.
                    ActionRow(
                        role: mode == .replaceAll ? .destructive : .scope,
                        systemImage: mode == .replaceAll ? "arrow.triangle.2.circlepath" : "tray.and.arrow.down",
                        title: mode == .replaceAll
                            ? "Replace device archive"
                            : "Apply to device archive",
                        caption: applyCaption,
                        isBusy: isApplying,
                        isDisabled: outcome.items.isEmpty
                    ) {
                        Task { await apply() }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Preview")
                } footer: {
                    Text("Replace all clears cached content rows for this owner, then writes the import. Merge updates overlapping URIs only.")
                }
            }
        }
        .navigationTitle("Backup & restore")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
    }

    /// Caption for the Apply ActionRow — surfaces the mode's effect in
    /// plain language so a misclick on the "Replace all" picker reads
    /// loudly before the user taps. Mirrors the Section footer copy
    /// but in a tighter, action-adjacent form.
    private var applyCaption: String {
        if isApplying { return "Writing rows…" }
        switch mode {
        case .mergeByURI:
            return "Updates overlapping URIs only — adds missing rows."
        case .replaceAll:
            return "Clears this owner's cached rows first, then writes the import."
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        importError = nil
        outcome = nil
        preview = nil
        switch result {
        case .failure(let e):
            importError = e.localizedDescription
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Could not read the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                let decoded = try ContentBackupImport.decodeContentItems(
                    from: data,
                    expectedHandle: model.currentHandle,
                    expectedDid: model.currentDid
                )
                outcome = decoded
                preview = ContentBackupImport.restorePreview(
                    currentItems: model.items,
                    importedItems: decoded.items,
                    skippedUnsafeLikeRepost: decoded.skippedLikeRepostWithoutDeletionURI
                )
            } catch let e as ContentBackupImport.ImportError {
                switch e {
                case .handleMismatch(let exp, let found):
                    importError = "Handle mismatch (expected \(exp), found \(found ?? "nil"))."
                case .didMismatch(let exp, let found):
                    importError = "DID mismatch (expected \(exp), found \(found ?? "nil"))."
                case .missingEnvelopeIdentity(let field):
                    importError = "This backup is missing its \(field). Export a new backup while signed in."
                case .invalidContentType(let type):
                    importError = "This backup contains an unsupported content type: \(type)."
                case .unsafeDeletionURI(let uri, let reason):
                    importError = "Unsafe delete target \(uri ?? "nil"): \(reason). Nothing was imported."
                }
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func apply() async {
        guard let outcome else { return }
        isApplying = true
        defer { isApplying = false }
        await model.applyBackupImport(importedItems: outcome.items, mode: mode)
    }
}
