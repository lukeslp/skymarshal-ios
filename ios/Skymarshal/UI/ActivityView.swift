// ActivityView.swift
//
// `UIActivityViewController` wrapped for SwiftUI. Replaces the
// `ShareLink` + `Transferable` + `FileRepresentation` chain that crashes
// with `EXC_GUARD` / `XPC_EXIT_REASON_FAULT` inside the `BSXPCService…`
// plumbing on iOS 26 when the share sheet tries to materialize a
// Transferable from the toolbar `Menu`. Hosting `UIActivityViewController`
// directly via `UIViewControllerRepresentable` is the proven
// crash-free path (mirrors the pattern used in screenshat-ios's
// `ActivityView`).
//
// Hosted inside SwiftUI `.sheet(item:)` as a child view controller, the
// activity controller fills the form-sheet envelope on iPad — its
// `popoverPresentationController` is nil at construction time, so
// popover anchoring below is intentionally omitted (matches
// screenshat-ios's minimal ActivityView).
//
// Inputs:   `activityItems` — `[Any]` of file URLs / Data / Strings.
// Outputs:  a `View` that hosts a `UIActivityViewController`.

import SwiftUI
import UIKit

@available(iOS 17, *)
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Identifiable share payload — fits `.sheet(item:)`. Carries the
/// already-prepared file URLs (or any other share types) so the share
/// sheet just hands the bytes off without re-encoding on the main
/// thread inside the menu body.
@available(iOS 17, *)
struct SharePayload: Identifiable {
    let id = UUID()
    let urls: [URL]
}
