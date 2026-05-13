import Foundation

// MARK: - File purpose
// Parses upstream-style keyword expressions: quoted phrases, +required,
// -excluded, plain OR-terms, and \bword\b boundaries. Used by SearchRequest
// when ``SearchRequest/useAdvancedKeywordGrammar`` is true.

/// One clause after parsing a keyword string.
public enum SearchKeywordClause: Hashable, Sendable, Codable {
    /// Must appear as a substring (case-insensitive).
    case phrase(String)
    /// Must appear (case-insensitive substring).
    case required(String)
    /// Must not appear anywhere in the haystack.
    case excluded(String)
    /// Plain token: OR group — at least one plain token must match if any exist.
    case plain(String)
    /// Word-boundary match (Unicode-aware via regex).
    case wordBoundary(String)
}

/// Parses and evaluates keyword expressions for local content search.
public enum SearchKeywordGrammar: Sendable {

    public enum ParseError: Error, Equatable, Sendable {
        case unterminatedQuote(Int)
    }

    /// Tokenize the raw keyword field into clauses. Whitespace splits OR tokens;
    /// `+` / `-` bind the following non-space run; `"..."` captures a phrase.
    /// `\bterm\b` captures a word-boundary term (term must not contain `\`).
    public static func parse(_ raw: String) throws -> [SearchKeywordClause] {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return [] }

        var clauses: [SearchKeywordClause] = []
        var i = s.startIndex

        func skipSpaces() {
            while i < s.endIndex, s[i].isWhitespace { s.formIndex(after: &i) }
        }

        while i < s.endIndex {
            skipSpaces()
            guard i < s.endIndex else { break }

            if s[i] == "\"" {
                let startQuote = s.distance(from: s.startIndex, to: i)
                s.formIndex(after: &i)
                let bodyStart = i
                while i < s.endIndex, s[i] != "\"" {
                    s.formIndex(after: &i)
                }
                guard i < s.endIndex else {
                    throw ParseError.unterminatedQuote(startQuote)
                }
                let inner = String(s[bodyStart..<i])
                s.formIndex(after: &i)
                if !inner.isEmpty { clauses.append(.phrase(inner)) }
                continue
            }

            if s[i] == "+" {
                s.formIndex(after: &i)
                let t = takeToken(from: s, index: &i)
                if !t.isEmpty { clauses.append(.required(t)) }
                continue
            }

            if s[i] == "-" {
                s.formIndex(after: &i)
                let t = takeToken(from: s, index: &i)
                if !t.isEmpty { clauses.append(.excluded(t)) }
                continue
            }

            // Word boundary: `\bterm\b` (term must not contain `\`).
            if s[i] == "\\", s.index(after: i) < s.endIndex, s[s.index(after: i)] == "b" {
                let openBackslash = i
                i = s.index(i, offsetBy: 2)
                let innerStart = i
                var closed = false
                while i < s.endIndex {
                    if s[i] == "\\", s.index(after: i) < s.endIndex, s[s.index(after: i)] == "b" {
                        let inner = String(s[innerStart..<i])
                        i = s.index(i, offsetBy: 2)
                        if !inner.isEmpty { clauses.append(.wordBoundary(inner)) }
                        closed = true
                        break
                    }
                    s.formIndex(after: &i)
                }
                if !closed {
                    let rest = String(s[openBackslash..<s.endIndex])
                    i = s.endIndex
                    if !rest.isEmpty { clauses.append(.plain(rest)) }
                }
                continue
            }

            let t = takeToken(from: s, index: &i)
            if !t.isEmpty { clauses.append(.plain(t)) }
        }

        return clauses
    }

    private static func takeToken(from s: String, index i: inout String.Index) -> String {
        let start = i
        while i < s.endIndex, !s[i].isWhitespace, s[i] != "\"" {
            if s[i] == "+" || s[i] == "-" { break }
            s.formIndex(after: &i)
        }
        return String(s[start..<i]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True if the haystack satisfies all clauses. `plain` clauses are OR'd:
    /// if there is at least one `.plain`, at least one must match. If there are
    /// no plain clauses, OR is vacuously satisfied.
    public static func matches(haystack: String, clauses: [SearchKeywordClause]) -> Bool {
        guard !clauses.isEmpty else { return true }
        let lowered = haystack.lowercased()

        var plains: [String] = []
        for c in clauses {
            switch c {
            case .phrase(let p):
                let t = p.lowercased()
                guard lowered.contains(t) else { return false }
            case .required(let p):
                let t = p.lowercased()
                guard lowered.contains(t) else { return false }
            case .excluded(let p):
                let t = p.lowercased()
                guard !lowered.contains(t) else { return false }
            case .plain(let p):
                plains.append(p)
            case .wordBoundary(let p):
                guard boundaryMatches(term: p, in: lowered) else { return false }
            }
        }

        if !plains.isEmpty {
            let any = plains.contains { lowered.contains($0.lowercased()) }
            guard any else { return false }
        }

        return true
    }

    private static func boundaryMatches(term: String, in loweredHaystack: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: term.lowercased())
        let pattern = "(?<!\\w)" + escaped + "(?!\\w)"
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else {
            return loweredHaystack.contains(term.lowercased())
        }
        let range = NSRange(loweredHaystack.startIndex..., in: loweredHaystack)
        return re.firstMatch(in: loweredHaystack, options: [], range: range) != nil
    }
}
