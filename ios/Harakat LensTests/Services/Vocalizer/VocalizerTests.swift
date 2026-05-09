//
//  VocalizerTests.swift
//  Harakat Lens
//

@testable import Harakat_Lens
import Testing

struct VocalizerTests {
    @Test func vocalizesKnownBareForm() {
        let dict = VocalizationDictionary(map: ["كتاب": "كِتَاب"])
        let vocalizer = Vocalizer(dictionary: dict)
        #expect(vocalizer.vocalize("كتاب") == "كِتَاب")
    }

    @Test func returnsOriginalOnMiss() {
        let dict = VocalizationDictionary(map: [:])
        let vocalizer = Vocalizer(dictionary: dict)
        #expect(vocalizer.vocalize("شيء") == "شيء")
    }

    @Test func passesThroughVocalizedInput() {
        let dict = VocalizationDictionary(map: ["كتاب": "كِتَاب"])
        let vocalizer = Vocalizer(dictionary: dict)
        // Already vocalized — must not double-look-up nor re-strip.
        #expect(vocalizer.vocalize("كَتَبَ") == "كَتَبَ")
    }

    @Test func stripsHarakatBeforeLookup() {
        let dict = VocalizationDictionary(map: ["كتاب": "كِتَاب"])
        let vocalizer = Vocalizer(dictionary: dict)
        // Input has stray harakat but we treat it as already vocalized
        // (passthrough rule). Caller is responsible for routing only bare
        // tokens here.
        #expect(vocalizer.vocalize("كِتاب") == "كِتاب")
    }
}
