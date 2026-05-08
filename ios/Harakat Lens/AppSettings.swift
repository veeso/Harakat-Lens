//
//  AppSettings.swift
//  Harakat Lens
//

import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    var userLanguage: String {
        didSet { userDefaults.set(userLanguage, forKey: "user_language") }
    }

    var quranMode: Bool {
        didSet { userDefaults.set(quranMode, forKey: "quran_mode") }
    }

    @ObservationIgnored private let userDefaults: UserDefaults

    init(
        userDefaults: UserDefaults = .standard,
        defaultLanguage: String = Locale.current.language.languageCode?
            .identifier ?? "en"
    ) {
        self.userDefaults = userDefaults
        userLanguage =
            userDefaults.string(forKey: "user_language") ?? defaultLanguage
        quranMode = userDefaults.bool(forKey: "quran_mode")
    }
}
