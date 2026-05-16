// CacheHydration.swift
//
// Predicate-scoped SwiftData reads for cold-start cache hydration.
// Replaces the unbounded `fetch` + in-memory `filter { ownerHandle }`
// pattern in `AppModel.hydrateFromCache()` with a two-step read:
//   1. `fetchLimit = 1` sorted by `scannedAt` → latest owner handle
//   2. `#Predicate { $0.ownerHandle == owner }` for that owner's rows
//
// Primary API: ``latestOwnerHandle(from:)``, ``contentRecords(for:context:)``,
// ``analyzedAccountRecords(for:context:)``.
//
// Inputs:  `ModelContext`, owner handle string.
// Outputs: optional owner handle, arrays of persisted records.

import Foundation
import SwiftData

@available(iOS 17, *)
public enum CacheHydration {

    /// Owner handle on the single most recently scanned content row, if any.
    public static func latestOwnerHandle(from context: ModelContext) -> String? {
        var tip = FetchDescriptor<ContentItemRecord>(
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )
        tip.fetchLimit = 1
        if let handle = try? context.fetch(tip).first?.ownerHandle {
            return handle
        }
        var accountTip = FetchDescriptor<AnalyzedAccountRecord>(
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )
        accountTip.fetchLimit = 1
        return try? context.fetch(accountTip).first?.ownerHandle
    }

    /// All cached content rows for one owner (predicate-scoped).
    public static func contentRecords(
        for ownerHandle: String,
        context: ModelContext
    ) -> [ContentItemRecord] {
        let owner = ownerHandle
        let descriptor = FetchDescriptor<ContentItemRecord>(
            predicate: #Predicate<ContentItemRecord> { $0.ownerHandle == owner },
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// All cached follower-scan rows for one owner (predicate-scoped).
    public static func analyzedAccountRecords(
        for ownerHandle: String,
        context: ModelContext
    ) -> [AnalyzedAccountRecord] {
        let owner = ownerHandle
        let descriptor = FetchDescriptor<AnalyzedAccountRecord>(
            predicate: #Predicate<AnalyzedAccountRecord> { $0.ownerHandle == owner },
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Legacy hydration path: unbounded fetch + filter. Used only in tests
    /// to prove predicate-scoped reads return the same row set.
    public static func contentRecordsLegacyUnbounded(
        for ownerHandle: String,
        context: ModelContext
    ) -> [ContentItemRecord] {
        let descriptor = FetchDescriptor<ContentItemRecord>(
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )
        guard let all = try? context.fetch(descriptor) else { return [] }
        return all.filter { $0.ownerHandle == ownerHandle }
    }

    public static func analyzedAccountRecordsLegacyUnbounded(
        for ownerHandle: String,
        context: ModelContext
    ) -> [AnalyzedAccountRecord] {
        let descriptor = FetchDescriptor<AnalyzedAccountRecord>(
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )
        guard let all = try? context.fetch(descriptor) else { return [] }
        return all.filter { $0.ownerHandle == ownerHandle }
    }
}
