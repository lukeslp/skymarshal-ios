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
// iPad anchors the popover at the screen center as a fallback —
// `.sheet(item:)` presentations on iPhone get the regular bottom-sheet
// affordance for free.
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
        let vc = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        // iPad: anchor the popover so it doesn't crash the regular size class.
        // The sheet presentation envelope handles iPhone for us.
        if let pop = vc.popoverPresentationController {
            pop.permittedArrowDirections = []
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let window = scene.windows.first(where: \.isKeyWindow)
            {
                pop.sourceView = window
                pop.sourceRect = CGRect(
                    x: window.bounds.midX,
                    y: window.bounds.midY,
                    width: 0,
                    height: 0
                )
            }
        }
        return vc
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
