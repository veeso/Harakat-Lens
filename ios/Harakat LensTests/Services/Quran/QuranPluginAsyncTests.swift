//
//  QuranPluginAsyncTests.swift
//  Harakat Lens
//
//  Regression: the Quran plugin must NOT run `QuranMatcher.bestMatch`
//  synchronously inside `inlineResultView` (it executes on @MainActor and
//  froze the camera/UI). Matching must be dispatched off the main thread
//  and the result delivered later via the observed model.
//

import BiangBiangUI
import Foundation
@testable import Harakat_Lens
import Testing

@MainActor
struct QuranPluginAsyncTests {
    @Test func inlineResultViewDoesNotMatchSynchronously() async {
        UserDefaults.standard.set("true", forKey: "descriptor.quranMode")
        defer { UserDefaults.standard.removeObject(forKey: "descriptor.quranMode") }

        let ds = QuranDataset()
        await ds.loadIfNeeded()
        let plugin = QuranPlugin(
            ayat: await ds.all,
            tokenIndex: await ds.tokenIndex,
            surahNames: await ds.surahNames
        )

        let pt = ProcessedText(
            original: "بسم الله الرحمن الرحيم",
            transliteration: "x",
            variantId: "",
            source: .camera
        )

        _ = plugin.inlineResultView(for: pt)

        // Synchronous: the call must return without having matched.
        #expect(plugin.currentMatch == nil)

        // The match arrives asynchronously off the main thread.
        for _ in 0 ..< 50 where plugin.currentMatch == nil {
            try? await Task.sleep(nanoseconds: 40_000_000)
        }
        #expect(plugin.currentMatch?.ayah.surah == 1)
    }

    @Test func identicalInputIsNotRematched() async {
        UserDefaults.standard.set("true", forKey: "descriptor.quranMode")
        defer { UserDefaults.standard.removeObject(forKey: "descriptor.quranMode") }

        let ds = QuranDataset()
        await ds.loadIfNeeded()
        let plugin = QuranPlugin(
            ayat: await ds.all,
            tokenIndex: await ds.tokenIndex,
            surahNames: await ds.surahNames
        )

        // Modern phrase that is not a Quran verse — match returns nil.
        let pt = ProcessedText(
            original: "القطار السريع وصل المحطة اليوم",
            transliteration: "x",
            variantId: "",
            source: .camera
        )

        _ = plugin.inlineResultView(for: pt)
        for _ in 0 ..< 50 where plugin.isMatching {
            try? await Task.sleep(nanoseconds: 40_000_000)
        }
        #expect(plugin.currentMatch == nil)
        #expect(plugin.isMatching == false)

        // Same frame text again: the camera yields near-identical text every
        // frame — re-running the O(dataset) scan is what starved OCR. The
        // second call must not start another job.
        _ = plugin.inlineResultView(for: pt)
        #expect(plugin.isMatching == false)
    }
}
