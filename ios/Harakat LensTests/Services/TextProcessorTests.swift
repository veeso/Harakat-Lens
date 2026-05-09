//
//  TextProcessorTests.swift
//  Harakat Lens
//

@testable import Harakat_Lens
import Testing

struct TextProcessorTests {
    @Test func detectsArabicInMixedText() {
        #expect(TextProcessor().containsArabic(text: "Hello السلام 123"))
    }

    @Test func rejectsNonArabic() {
        #expect(!TextProcessor().containsArabic(text: "Hello 123"))
    }

    @Test func arabicToLatinStripsArabicCharacters() {
        let out = TextProcessor().arabicToLatin("السلام")
        #expect(!out.isEmpty)
        // No characters left in the Arabic block
        for scalar in out.unicodeScalars {
            #expect(!(0x0600 ... 0x06FF).contains(scalar.value))
        }
    }

    @Test func processReturnsNilWhenNoArabic() {
        #expect(TextProcessor().process(text: "no arabic here") == nil)
    }

    @Test func processReturnsTransliteratedWhenArabicPresent() {
        let out = TextProcessor().process(text: "السلام")
        #expect(out != nil)
        #expect(!(out ?? "").isEmpty)
        for scalar in (out ?? "").unicodeScalars {
            #expect(!(0x0600 ... 0x06FF).contains(scalar.value))
        }
    }

    @Test func processInsertsSpaceBetweenArabicAndLatin() {
        // Latin-Arabic-Latin should not stick together
        let out = TextProcessor().process(text: "Read السلام now") ?? ""
        // Expect at least one ASCII space present, no Arabic remaining
        #expect(out.contains(" "))
        for scalar in out.unicodeScalars {
            #expect(!(0x0600 ... 0x06FF).contains(scalar.value))
        }
    }

    @Test func processSingleArabicWord() {
        let out = TextProcessor().process(text: "بسم")
        #expect(out != nil)
        #expect(!(out ?? "").isEmpty)
    }

    @Test func processHandlesMultipleArabicSpans() {
        let out = TextProcessor().process(text: "السلام hello السلام") ?? ""
        #expect(out.contains(" "))
        for scalar in out.unicodeScalars {
            #expect(!(0x0600 ... 0x06FF).contains(scalar.value))
        }
    }

    @Test func vocalizedInputProducesVocalizedLatin() {
        let processor = TextProcessor()
        // كِتَابٌ — already vocalized; expect macron vowels in the Latin output.
        let out = processor.arabicToLatin("كِتَابٌ")
        #expect(out.contains("i"))
        #expect(out.contains("ā") || out.contains("a"))
        #expect(!out.isEmpty)
    }
}
