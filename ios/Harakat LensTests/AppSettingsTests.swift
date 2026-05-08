//
//  AppSettingsTests.swift
//  Harakat Lens
//

import Foundation
@testable import Harakat_Lens
import Testing

@MainActor
struct AppSettingsTests {
    private func makeDefaults(_ suite: String) -> UserDefaults {
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test func quranModeDefaultsFalse() {
        let d = makeDefaults("test.quran.default")
        let s = AppSettings(userDefaults: d, defaultLanguage: "en")
        #expect(s.quranMode == false)
    }

    @Test func quranModePersists() {
        let d = makeDefaults("test.quran.persist")
        let s = AppSettings(userDefaults: d, defaultLanguage: "en")
        s.quranMode = true
        let s2 = AppSettings(userDefaults: d, defaultLanguage: "en")
        #expect(s2.quranMode == true)
    }

    @Test func legacyChineseKeyDoesNotBreakLoad() {
        let d = makeDefaults("test.quran.legacy")
        d.set("zh-Hant", forKey: "chinese") // legacy key
        let s = AppSettings(userDefaults: d, defaultLanguage: "en")
        #expect(s.quranMode == false)
        #expect(s.userLanguage == "en")
    }

    @Test func userLanguagePersists() {
        let d = makeDefaults("test.quran.lang")
        let s = AppSettings(userDefaults: d, defaultLanguage: "en")
        s.userLanguage = "fr"
        let s2 = AppSettings(userDefaults: d, defaultLanguage: "en")
        #expect(s2.userLanguage == "fr")
    }
}
