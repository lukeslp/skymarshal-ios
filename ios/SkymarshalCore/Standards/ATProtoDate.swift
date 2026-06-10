import Foundation

/// Parses AT Protocol timestamp strings.
///
/// The official Bluesky clients write `createdAt` with fractional seconds
/// (`2024-03-01T18:22:47.123Z`), which a bare `ISO8601DateFormatter`
/// rejects, returning nil. A nil date here is not cosmetic: nil-dated
/// items used to pass date-range filters, so a date-scoped bulk delete
/// could select the whole archive. Every string→Date parse of a
/// server-supplied timestamp must go through this type.
public enum ATProtoDate {
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let whole: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    public static func parse(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return fractional.date(from: string) ?? whole.date(from: string)
    }
}
