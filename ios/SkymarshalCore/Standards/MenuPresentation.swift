// MenuPresentation.swift
//
// Shared helpers for presenting sheets/alerts after toolbar `Menu`
// actions. Toolbar `Menu` buttons run while UIKit is still tearing down
// the context menu; mutating presentation state in the same turn races
// that dismissal — reproducible crash on device and a stuck options menu.
//
// Primary API: ``presentAfterMenuDismisses(_:)`` — hop to the next
// main-queue pass before flipping `@State` that drives `.sheet` /
// `.confirmationDialog`.
//
// Inputs:  a `@MainActor` closure that mutates presentation state.
// Outputs: schedules `work` on the main queue (async, next turn).

import Foundation

/// Toolbar `Menu` buttons run while UIKit is still tearing down the
/// context menu. Hop to the next main-queue pass before mutating
/// presentation state, or you'll race the dismissal and get a stuck
/// menu / crash on real device.
@available(iOS 17, *)
@MainActor
public func presentAfterMenuDismisses(_ work: @escaping @MainActor () -> Void) {
    DispatchQueue.main.async {
        work()
    }
}
