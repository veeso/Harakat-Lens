//
//  Harakat_LensApp.swift
//  Harakat Lens
//
//  Created by christian visintin on 31/10/25.
//
//  Config-only entry point: the BiangBiangUI library renders every screen
//  and owns History, the rate prompt, TTS and the OCR pipeline. The app
//  supplies only `ArabicConfig`, the `ArabicTransliterator` and the
//  `QuranPlugin`.
//

import BiangBiangUI
import SwiftUI

@main
struct Harakat_LensApp: App {
    var body: some Scene {
        WindowGroup {
            BiangBiangRootView(config: ArabicConfig.arabicConfig)
        }
    }
}
