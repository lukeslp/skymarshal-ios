// ExportSheet.swift
//
// Bottom-sheet export surface used by both ContentListView and
// BluescreenView. Replaces the previous `ShareLink` + `Transferable`
// + `FileRepresentation` pattern that crashed on iOS 26 with
// `EXC_GUARD` / `XPC_EXIT_REASON_FAULT` (see crash diagnostic
// `ExcUserFault_Skymarshal-2026-05-15-165147.ips` —
// `BSXPCServiceConnectionListener` faulting in
// `xpc_connection_copy_bundle_id`). Trying to materialize a Transferable
// from inside a toolbar `Menu`'s body is the trigger; lifting the work
// onto a `Task` and presenting `UIActivityViewController` directly
// sidesteps that XPC plumbing.
//
// UX shape mirrors screenshat-ios's results-export sheet (full-width
// pill rows, busy state on tap, single-line StatusLine feedback) but
// rendered in Skymarshal's idiom (Theme tokens, Plex Mono caption,
// scope-blue primary fill).
//
// Inputs:
//   - title / subtitle for the sheet header
//   - itemCount for the count badge in the header
//   - jsonProducer / csvProducer — sync closures that build an
//     `ExportPayload`. Run on a background `Task.detached` so the JSON
//     encode / CSV escape doesn't block the main thread.
//
// Outputs:
//   - calls `onShare(SharePayload)` when a temp file is ready, so the
//     parent view can present `.sheet(item:)` with `ActivityView`. The
//     sheet itself dismisses after handing off.

import SwiftUI
import SkymarshalCore

@available(iOS 17, *)
struct ExportSheet: View {

    enum Format: String { case json = "JSON", csv = "CSV" }

    let title: String
    let subtitleHeader: String?
    let itemCount: Int
    /// Closures that build an `ExportPayload`. Marked `@Sendable` so
    /// the detached Task that runs them on a background priority can
    /// take ownership without smuggling main-actor state across the
    /// boundary. Throwing producers surface an inline danger
    /// StatusLine without dismissing the sheet, which matches "share
    /// menu fails silently → user has no idea why" better than the
    /// previous fall-back-to-empty-CSV pattern.
    let jsonProducer: @Sendable () throws -> ExportPayload
    let csvProducer: @Sendable () -> ExportPayload
    let onShare: (SharePayload) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Tracks which format is being prepared so only the corresponding
    /// row spins. `nil` = idle.
    @State private var preparing: Format?
    /// Per-format error captions. Keying by Format avoids a stale JSON
    /// failure leaking into the CSV row's caption (and vice versa).
    @State private var errorByFormat: [Format: String] = [:]
    @State private var lastReady: ReadyInfo?
    /// Holds the in-flight prepare task so `.onDisappear` can cancel it
    /// — otherwise a fire-and-forget Task would resume after the sheet
    /// dismissed and surprise-present the share sheet to a user who
    /// already swiped away.
    @State private var prepareTask: Task<Void, Never>?

    @AppStorage("sm.lastExportFormat") private var lastExportFormat: String = "json"

    private struct ReadyInfo {
        let format: Format
        let bytes: Int
        let filename: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            VStack(spacing: 10) {
                if lastExportFormat == "csv" {
                    csvRow
                    jsonRow
                } else {
                    jsonRow
                    csvRow
                }
            }

            statusFooter
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
        .onDisappear {
            // Cancel any in-flight encoding so the user dismissing the
            // sheet mid-prepare doesn't get a surprise share sheet a
            // beat later. The Task itself swallows cancellation in
            // `prepare(_:)` and skips the `onShare` hand-off.
            prepareTask?.cancel()
            prepareTask = nil
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("EXPORT")
                    .font(Theme.Mono.kicker(11))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)
                Spacer()
                ScopePill(
                    value: itemCount.formatted() + (itemCount == 1 ? " item" : " items"),
                    emphasis: .scope,
                    leading: Image(systemName: "tray.full")
                )
            }
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .semibold))
            if let subtitleHeader, !subtitleHeader.isEmpty {
                Text(subtitleHeader)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Rows

    private var jsonRow: some View {
        ActionRow(
            role: rowRole(for: .json),
            systemImage: "curlybraces",
            title: "Save as JSON",
            caption: rowCaption(for: .json, fallback: "Pretty-printed envelope, machine-readable"),
            isBusy: preparing == .json,
            isDisabled: itemCount == 0
        ) {
            prepareTask = Task { await prepare(.json) }
        }
    }

    private var csvRow: some View {
        ActionRow(
            role: rowRole(for: .csv),
            systemImage: "tablecells",
            title: "Save as CSV",
            caption: rowCaption(for: .csv, fallback: "Tabular, RFC 4180 — opens in Numbers / Excel"),
            isBusy: preparing == .csv,
            isDisabled: itemCount == 0
        ) {
            prepareTask = Task { await prepare(.csv) }
        }
    }

    private func rowRole(for format: Format) -> ActionRow.Role {
        // The user's last-chosen format is the "scope" emphasis (visually
        // promoted). The other format stays neutral. New users default to
        // JSON — matches `lastExportFormat`'s @AppStorage default.
        let preferred = lastExportFormat == "csv" ? Format.csv : .json
        return format == preferred ? .scope : .neutral
    }

    private func rowCaption(for format: Format, fallback: String) -> String {
        if preparing == format { return "Preparing…" }
        if let err = errorByFormat[format] { return err }
        if let ready = lastReady, ready.format == format {
            return "\(byteString(ready.bytes)) · \(ready.filename)"
        }
        return fallback
    }

    // MARK: - Status footer

    @ViewBuilder
    private var statusFooter: some View {
        if let preparing {
            StatusLine(
                style: .progress,
                title: "Preparing \(preparing.rawValue)",
                meta: itemCount.formatted(),
                subtitle: "Encoding off the main thread."
            )
        } else if let err = errorByFormat.values.first {
            // The most recent failure is good-enough surface for the
            // footer; the per-row caption already discriminates which
            // format failed.
            StatusLine(
                style: .danger,
                title: "Couldn't prepare export",
                subtitle: err
            )
        } else if itemCount == 0 {
            StatusLine(
                style: .neutral,
                title: "Nothing to export",
                subtitle: "Load or scan first, then come back."
            )
        } else {
            StatusLine(
                style: .neutral,
                title: "Ready",
                meta: nil,
                subtitle: "Pick a format. The system share sheet appears next."
            )
        }
    }

    // MARK: - Async prepare → onShare

    private func prepare(_ format: Format) async {
        preparing = format
        errorByFormat[format] = nil
        // Capture the closures we need so the detached Task isn't holding
        // a reference to `self`'s SwiftUI state.
        let jsonClosure = jsonProducer
        let csvClosure = csvProducer

        let result: Result<(URL, Int, String), Error> = await Task.detached(priority: .userInitiated) {
            do {
                let payload: ExportPayload = try {
                    switch format {
                    case .json: return try jsonClosure()
                    case .csv:  return csvClosure()
                    }
                }()
                let url = try writeToTemp(payload)
                return .success((url, payload.data.count, payload.suggestedFilename))
            } catch {
                return .failure(error)
            }
        }.value

        preparing = nil
        // If the user dismissed the sheet while the encoder was running,
        // skip the parent hand-off entirely. The temp file would just
        // sit on disk; clean it up to keep `tmp` from drifting.
        guard !Task.isCancelled else {
            if case .success(let (url, _, _)) = result {
                try? FileManager.default.removeItem(at: url)
            }
            return
        }
        switch result {
        case .success(let (url, bytes, name)):
            lastReady = ReadyInfo(format: format, bytes: bytes, filename: name)
            lastExportFormat = (format == .json) ? "json" : "csv"
            // Hand the prepared payload to the parent, then dismiss
            // self. The parent buffers the payload and only opens the
            // share sheet AFTER our `.onDisappear` completes — that
            // ordering is the conservative path past a known SwiftUI
            // dismiss-then-present race on iPad form sheets.
            onShare(SharePayload(urls: [url]))
            dismiss()
        case .failure(let err):
            errorByFormat[format] = err.localizedDescription
        }
    }

    private func byteString(_ bytes: Int) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(bytes),
            countStyle: .file
        )
    }
}

/// Top-level helper kept outside the View so the detached Task body
/// (a `@Sendable` closure) can call it without capturing SwiftUI state.
@available(iOS 17, *)
private func writeToTemp(_ payload: ExportPayload) throws -> URL {
    let url = FileManager.default
        .temporaryDirectory
        .appendingPathComponent(payload.suggestedFilename)
    try payload.data.write(to: url, options: .atomic)
    return url
}
