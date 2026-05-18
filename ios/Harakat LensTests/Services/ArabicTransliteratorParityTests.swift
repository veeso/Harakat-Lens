//
//  ArabicTransliteratorParityTests.swift
//  Harakat Lens
//
//  Span-level parity for the app transliterator. The library's
//  `TextProcessingEngine` owns span detection / passthrough / spacing, so
//  these assert romanisation of an already-isolated script span only —
//  the values match the former `TextProcessor.arabicToLatin` outputs.
//

@testable import Harakat_Lens
import Testing

struct ArabicTransliteratorParityTests {
    let t = ArabicTransliterator()

    @Test func stripsArabicBlock() {
        let out = t.transliterate("السلام")
        #expect(!out.isEmpty)
        for scalar in out.unicodeScalars {
            #expect(!(0x0600 ... 0x06FF).contains(scalar.value))
        }
    }

    @Test func vocalizedInputProducesVocalizedLatin() {
        // كِتَابٌ — already vocalized; expect vowels in the Latin output.
        let out = t.transliterate("كِتَابٌ")
        #expect(out.contains("i"))
        #expect(out.contains("ā") || out.contains("a"))
    }

    @Test func unvocalizedKnownWordGetsVowels() {
        // Bare كتاب — dictionary vocalizes to كِتَاب → ICU produces "kitāb"-ish.
        #expect(t.transliterate("كتاب").lowercased().contains("kit"))
    }

    @Test func knownWordWithShaddaKeepsDoubledConsonant() {
        // Vocalized الله produces a word with double-l (lām+lām via shadda).
        #expect(t.transliterate("الله").contains("ll"))
    }

    @Test func unknownWordFallsBackToBareTransliteration() {
        // A nonsense Arabic-letter sequence not in the dictionary — should
        // return a non-empty consonant-only ICU output without crashing.
        let out = t.transliterate("ززززز")
        #expect(!out.isEmpty)
        #expect(out.lowercased().contains("z"))
    }
}
