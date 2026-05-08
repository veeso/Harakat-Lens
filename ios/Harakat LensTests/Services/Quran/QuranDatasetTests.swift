//
//  QuranDatasetTests.swift
//  Harakat Lens

@testable import Harakat_Lens
import Testing

struct QuranDatasetTests {
    @Test func loadsAllAyat() async {
        let ds = QuranDataset()
        await ds.loadIfNeeded()
        let count = await ds.all.count
        #expect(count == 6236)
    }

    @Test func surahOneHasSevenAyat() async {
        let ds = QuranDataset()
        await ds.loadIfNeeded()
        let alFatiha = await ds.all.filter { $0.surah == 1 }
        #expect(alFatiha.count == 7)
    }

    @Test func normalizedFieldStripsDiacritics() async {
        let ds = QuranDataset()
        await ds.loadIfNeeded()
        let first = await ds.all.first
        guard let first else {
            Issue.record("dataset empty")
            return
        }
        for scalar in first.normalized.unicodeScalars {
            let v = scalar.value
            #expect(!(0x064B ... 0x0652).contains(v))
            #expect(v != 0x0670)
            #expect(v != 0x0640)
        }
    }

    @Test func tokenIndexBuilt() async {
        let ds = QuranDataset()
        await ds.loadIfNeeded()
        let isEmpty = await ds.tokenIndex.isEmpty
        #expect(!isEmpty)
    }

    @Test func surahNamesLoaded() async {
        let ds = QuranDataset()
        await ds.loadIfNeeded()
        let count = await ds.surahNames.count
        #expect(count == 114)
    }
}
