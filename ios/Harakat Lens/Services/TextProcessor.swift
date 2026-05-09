//
//  TextProcessor.swift
//  Harakat Lens
//

import Foundation

class TextProcessor {
    private let regex: NSRegularExpression
    private let normalizer = ArabicNormalizer(mode: .transliteration)
    private let vocalizer: Vocalizer

    init(vocalizer: Vocalizer = Vocalizer()) {
        self.vocalizer = vocalizer
        // Arabic block: U+0600–U+06FF
        let pattern = "[\\u0600-\\u06FF]+"
        regex = try! NSRegularExpression(pattern: pattern, options: [])
    }

    /// Process given text:
    /// 1. If no Arabic characters present → return nil.
    /// 2. Replace each Arabic span with its Latin transliteration.
    /// 3. Pad with spaces around adjacent Latin letters/digits.
    /// 4. Collapse whitespace and trim.
    func process(text: String) -> String? {
        guard containsArabic(text: text) else { return nil }
        let range = NSRange(text.startIndex..., in: text)

        var result = text
        // Iterate in reverse so earlier match offsets stay valid in `result`
        // even when a replacement changes the string length.
        let matches = regex.matches(in: text, range: range).reversed()
        for match in matches {
            guard let r = Range(match.range, in: result) else { continue }
            let arabic = String(result[r])
            let latin = arabicToLatin(arabic)

            let needsLeading: Bool = {
                if r.lowerBound == result.startIndex { return false }
                let prev = result[result.index(before: r.lowerBound)]
                return prev != " " && !".,!?;:".contains(prev)
            }()

            let needsTrailing: Bool = {
                guard r.upperBound < result.endIndex else { return false }
                let next = result[r.upperBound]
                return next.isASCII && (next.isLetter || next.isNumber)
            }()

            let replacement =
                (needsLeading ? " " : "") + latin + (needsTrailing ? " " : "")

            result.replaceSubrange(r, with: replacement)
        }

        result = result.replacingOccurrences(
            of: "\\s+([.,!?;:])",
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\s{2,}",
            with: " ",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespaces)
    }

    func containsArabic(text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    /// Arabic → Latin via ICU (`kCFStringTransformToLatin`).
    /// Vocalizes bare words via the dictionary first; preserves any
    /// caller-supplied harakat. Drops tatweel before handing to ICU.
    func arabicToLatin(_ arabic: String) -> String {
        // The matching regex captures contiguous Arabic-block runs only, so
        // `arabic` is already a single word in the typical call path.
        let vocalized = vocalizer.vocalize(arabic)
        let normalized = normalizer.normalize(vocalized)
        let mut = NSMutableString(string: normalized) as CFMutableString
        CFStringTransform(mut, nil, kCFStringTransformToLatin, false)
        return mut as String
    }
}
