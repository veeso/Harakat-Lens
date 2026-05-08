//
//  QuranMatcher.swift
//  Harakat Lens
//

import Foundation

struct QuranMatch {
    enum Kind { case exact, fuzzy }
    let ayah: QuranAyah
    let score: Double
    let kind: Kind
}

actor QuranMatcher {
    private let dataset: QuranDataset
    private let normalizer = ArabicNormalizer()
    private let minTokenCount = 2
    private let minTokenLength = 2
    private let candidateCap = 200
    private let scoreThreshold = 0.85

    init(dataset: QuranDataset) {
        self.dataset = dataset
    }

    func match(_ rawArabic: String) async -> QuranMatch? {
        let norm = normalizer.normalize(rawArabic)
        let tokens = norm.split(separator: " ").filter { $0.count >= minTokenLength }
        guard tokens.count >= minTokenCount else { return nil }

        let all = await dataset.all
        let tokenIndex = await dataset.tokenIndex
        guard !all.isEmpty else { return nil }

        // 1. Exact substring pass — dataset is already in surah/ayah order.
        for ayah in all where ayah.normalized.contains(norm) {
            return QuranMatch(ayah: ayah, score: 1.0, kind: .exact)
        }

        // 2. Candidate set from rarest tokens.
        let ranked = tokens
            .map { token -> (String, Int) in
                let key = String(token)
                return (key, tokenIndex[key]?.count ?? .max)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(2)

        var candidateSet = Set<Int>()
        for (key, _) in ranked {
            for index in tokenIndex[key] ?? [] {
                candidateSet.insert(index)
                if candidateSet.count >= candidateCap { break }
            }
            if candidateSet.count >= candidateCap { break }
        }
        if candidateSet.isEmpty { return nil }

        // 3. Levenshtein scoring on candidates.
        var best: QuranMatch?
        for index in candidateSet {
            let ayah = all[index]
            let distance = Self.levenshtein(norm, ayah.normalized)
            let maxLen = max(norm.count, ayah.normalized.count)
            guard maxLen > 0 else { continue }
            let score = 1.0 - Double(distance) / Double(maxLen)
            if score >= scoreThreshold,
               score > (best?.score ?? scoreThreshold - 0.001)
            {
                best = QuranMatch(ayah: ayah, score: score, kind: .fuzzy)
            }
        }
        return best
    }

    /// Iterative two-row Levenshtein.
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        if aChars.isEmpty { return bChars.count }
        if bChars.isEmpty { return aChars.count }

        var prev = Array(0 ... bChars.count)
        var curr = Array(repeating: 0, count: bChars.count + 1)

        for i in 1 ... aChars.count {
            curr[0] = i
            for j in 1 ... bChars.count {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                curr[j] = min(
                    curr[j - 1] + 1,
                    prev[j] + 1,
                    prev[j - 1] + cost
                )
            }
            swap(&prev, &curr)
        }
        return prev[bChars.count]
    }
}
