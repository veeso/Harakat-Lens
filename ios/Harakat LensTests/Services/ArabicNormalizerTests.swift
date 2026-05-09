//
//  ArabicNormalizerTests.swift
//  Harakat Lens
//

@testable import Harakat_Lens
import Testing

struct ArabicNormalizerTests {
    @Test func stripsTatweel() {
        #expect(ArabicNormalizer().normalize("اـلسـلام") == "السلام")
    }

    @Test func unifiesAlefVariants() {
        #expect(ArabicNormalizer().normalize("أإآٱ") == "اااا")
    }

    @Test func unifiesAlefMaqsuraToYa() {
        #expect(ArabicNormalizer().normalize("على") == "علي")
    }

    @Test func stripsHarakatAndSuperscriptAlef() {
        // الرَّحْمَٰنِ الرَّحِيمِ → الرحمن الرحيم
        let input = "الرَّحْمَٰنِ الرَّحِيمِ"
        #expect(ArabicNormalizer().normalize(input) == "الرحمن الرحيم")
    }

    @Test func collapsesWhitespace() {
        #expect(ArabicNormalizer().normalize("بسم   الله") == "بسم الله")
    }

    @Test func isIdempotent() {
        let n = ArabicNormalizer()
        let once = n.normalize("الرَّحْمَٰنِ")
        #expect(n.normalize(once) == once)
    }

    @Test func taMarbutaFlagOff() {
        #expect(ArabicNormalizer().normalize("صلاة") == "صلاة")
    }

    @Test func taMarbutaFlagOn() {
        #expect(ArabicNormalizer(unifyTaMarbuta: true).normalize("صلاة") == "صلاه")
    }

    @Test func passesThroughLatin() {
        #expect(ArabicNormalizer().normalize("hello") == "hello")
    }

    @Test func emptyStringReturnsEmpty() {
        #expect(ArabicNormalizer().normalize("") == "")
    }

    // MARK: - Transliteration mode

    @Test func transliterationPreservesHarakat() {
        let n = ArabicNormalizer(mode: .transliteration)
        #expect(n.normalize("كِتَابٌ") == "كِتَابٌ")
    }

    @Test func transliterationPreservesAlefVariants() {
        let n = ArabicNormalizer(mode: .transliteration)
        #expect(n.normalize("أإآٱ") == "أإآٱ")
    }

    @Test func transliterationStripsTatweelOnly() {
        let n = ArabicNormalizer(mode: .transliteration)
        #expect(n.normalize("اـلسـلام") == "السلام")
    }

    @Test func transliterationPreservesAlefMaqsura() {
        let n = ArabicNormalizer(mode: .transliteration)
        #expect(n.normalize("على") == "على")
    }

    @Test func matchingModeIsDefault() {
        // Existing default-init behavior must not change.
        #expect(ArabicNormalizer().normalize("الرَّحْمَٰنِ") == "الرحمن")
    }
}
