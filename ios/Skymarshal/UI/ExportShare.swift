import SwiftUI
import UniformTypeIdentifiers
import SkymarshalCore

/// Transferable wrapper that hands an `ExportPayload` to SwiftUI's
/// `ShareLink`, which in turn surfaces the iOS share sheet (Save to
/// Files, AirDrop, Mail, etc.). The .json/.csv MIME types are
/// preserved so receiving apps know how to handle the bytes.
@available(iOS 17, *)
struct ExportItem: Transferable {
    let payload: ExportPayload

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { item in
            try writeIfJSON(item.payload)
        }
        .suggestedFileName { $0.payload.suggestedFilename }

        FileRepresentation(exportedContentType: .commaSeparatedText) { item in
            try writeIfCSV(item.payload)
        }
        .suggestedFileName { $0.payload.suggestedFilename }

        // Catch-all: if the receiver asks for raw data, hand the bytes.
        DataRepresentation(exportedContentType: .data) { $0.payload.data }
            .suggestedFileName { $0.payload.suggestedFilename }
    }

    /// Write the payload to a temp file and return a SentTransferredFile
    /// — required by SwiftUI's FileRepresentation. Discriminates on the
    /// payload's mimeType so JSON exports don't get offered as CSV (the
    /// share sheet would happily save them with the wrong extension).
    private static func writeIfJSON(_ payload: ExportPayload) throws -> SentTransferredFile {
        guard payload.mimeType == "application/json" else {
            throw ExportError.wrongFormat
        }
        let url = try writeToTemp(payload)
        return SentTransferredFile(url, allowAccessingOriginalFile: false)
    }

    private static func writeIfCSV(_ payload: ExportPayload) throws -> SentTransferredFile {
        guard payload.mimeType == "text/csv" else {
            throw ExportError.wrongFormat
        }
        let url = try writeToTemp(payload)
        return SentTransferredFile(url, allowAccessingOriginalFile: false)
    }

    private static func writeToTemp(_ payload: ExportPayload) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent(payload.suggestedFilename)
        try payload.data.write(to: url, options: .atomic)
        return url
    }

    enum ExportError: Error { case wrongFormat }
}
