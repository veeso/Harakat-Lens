//
//  ArabicConfig.swift
//  Harakat Lens
//
//  The complete `BiangBiangConfig` for Harakat Lens: one Arabic
//  `LanguageProfile` (single ICU-transliterator variant) plus the
//  `QuranPlugin` and a "Quran mode" extra setting. The library renders
//  every screen from this data.
//

import BiangBiangUI

enum ArabicConfig {
    @MainActor
    static let arabicConfig: BiangBiangConfig = .init(
        branding: Branding(
            appName: "Harakat Lens",
            accentColorHex: "#006C35",
            logoAssetName: "Logo",
            buttonLogoAssetName: "Logo",
            githubRepo: "veeso/Harakat-Lens",
            supportEmail: "info@veeso.dev",
            appStoreId: "6767614189",
            playStoreId: "dev.veeso.harakatlens"
        ),
        languages: [
            LanguageProfile(
                id: "arabic",
                displayName: "Arabic",
                scriptRanges: [0x0600 ... 0x06FF],
                ocrRecognizer: .arabic,
                variants: [
                    LanguageVariant(
                        id: "arabic",
                        displayName: "Arabic",
                        transliterator: ArabicTransliterator(),
                        ttsLanguageCode: "ar",
                        translatable: true
                    ),
                ]
            ),
        ],
        extraSettings: [
            SettingDescriptor(
                key: "quranMode",
                kind: .toggle,
                label: "Quran mode",
                defaultValue: "false"
            ),
        ],
        plugins: [QuranPlugin()],
        features: FeatureFlags(),
        strings: [
            "inputTitle": "Arabic",
            "outputTitle": "Transliteration",
            "appSubtitle": "Transliterate Arabic",
        ]
    )
}
