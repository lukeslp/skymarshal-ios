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
                    Text("Sign in to verify handle/DID against the backup envelope.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let err = importError {
                    Text(err).foregroundStyle(Theme.danger)
                }
            } footer: {
                Text("Exports from this app include handle and optional DID. Likes/reposts without a viewer delete URI are skipped.")
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
                    Button {
                        Task { await apply() }
                    } label: {
                        if isApplying { ProgressView() }
                        else { Text("Apply to device archive") }
                    }
                    .disabled(isApplying || outcome.items.isEmpty)
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
                    importError = "DID mismatch (expected \(exp), found \(found))."
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
