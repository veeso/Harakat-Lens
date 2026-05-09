//
//  VocalizationDictionaryTests.swift
//  Harakat Lens
//

@testable import Harakat_Lens
import Testing

struct VocalizationDictionaryTests {
    @Test func loadsKnownEntry() {
        // The bundled vocab.plist must contain a high-frequency word.
        let dict = VocalizationDictionary.shared
        #expect(dict.lookup("كتاب") != nil)
    }

    @Test func returnsNilOnMiss() {
        let dict = VocalizationDictionary.shared
        // Made-up sequence unlikely to appear in any Arabic corpus.
        #expect(dict.lookup("ززززز") == nil)
    }

    @Test func vocalizedFormDiffersFromKey() {
        let dict = VocalizationDictionary.shared
        if let vocalized = dict.lookup("كتاب") {
            #expect(vocalized != "كتاب")
        }
    }

    @Test func customMapInitInitForTesting() {
        let dict = VocalizationDictionary(map: ["x": "y"])
        #expect(dict.lookup("x") == "y")
        #expect(dict.lookup("y") == nil)
    }
}
