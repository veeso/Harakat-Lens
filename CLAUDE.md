# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Harakat Lens is a dual-platform native mobile app (iOS + Android) for scanning, transliterating, and translating Arabic text via OCR. The iOS and Android apps are **fully separate implementations** with no shared code — not a cross-platform framework.

The repository was migrated from a Chinese-Hanzi-to-Pinyin app (BiangBiang Hanzi). Every screen, the OCR pipeline, History, the rate prompt and settings are now rendered by the shared **BiangBiangUI** Swift package (<https://github.com/veeso/BiangBiangUI>); the app only supplies configuration. Arabic transliteration and Quran-aware features follow the spec at `~/Documents/Specs/harakat-lens.md`.

The repository is being migrated from a Chinese-Hanzi-to-Pinyin app (BiangBiang Hanzi). The current implementation still contains Hanzi/Pinyin conversion logic; Arabic transliteration and Quran-aware features are planned per the spec at `~/Documents/Specs/harakat-lens.md`.

## Build & Development Commands

### iOS (Swift + SwiftUI)

- **Open project:** `open "ios/Harakat Lens.xcodeproj"`
- **Build:** Xcode ⌘B or `xcodebuild -project "ios/Harakat Lens.xcodeproj" -scheme "Harakat Lens" build`
- **Run tests:** `xcodebuild test -project "ios/Harakat Lens.xcodeproj" -scheme "Harakat Lens" -destination 'platform=iOS Simulator,name=iPhone 17'`
- **Format code:** `swiftformat ./ios` (requires `brew install swiftformat`). **Run this whenever iOS code is modified.**

### Android (Kotlin + Jetpack Compose)

- **Build debug:** `cd android && ./gradlew assembleDebug`
- **Run unit tests:** `cd android && ./gradlew test`
- **Run a single test class:** `cd android && ./gradlew test --tests "dev.veeso.harakatlens.TextProcessorTest"`
- **Run instrumented tests:** `cd android && ./gradlew connectedAndroidTest`

### Website (Tailwind CSS v3)

- **Build CSS:** `npx tailwindcss@3 -i ./site/input.css -o ./site/output.css --minify`. **Run this whenever website content under `site/` is modified.**

## Architecture

### iOS (`ios/Harakat Lens/`)

The app is a thin configuration shell over the **BiangBiangUI** SwiftPM dependency (pinned in `ios/Harakat Lens.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`). `Harakat_LensApp.swift` only hosts `BiangBiangRootView(config: ArabicConfig.arabicConfig)`; the library owns the TabView, screens, OCR camera pipeline, History, rate prompt, settings persistence, design constants and the `TextProcessingEngine` (span detection + spacing).

- **Services/TextProcessor.swift** — text conversion using `CFStringTransform` with ICU `Arabic-Latin`, including `ArabicNormalizer` pre-processing
- **Services/Camera/CameraModel.swift** — AVFoundation camera + Vision OCR (ObservableObject)
- **Views/** — SwiftUI views for each tab (TextModeView, CameraModeView, SettingsView)
- **AppSettings.swift** — User preferences via `UserDefaults` (ObservableObject, injected as `@EnvironmentObject`)
- **AppDesign.swift** — Shared design constants including brand color (`brandGreen` = `#006C35`)
- **Config/ArabicConfig.swift** — the complete `BiangBiangConfig`: branding, one Arabic `LanguageProfile` (`.arabic` OCR recognizer, U+0600–U+06FF), a single ICU transliterator variant, a `quranMode` extra setting, and the `QuranPlugin`
- **Services/ArabicTransliterator.swift** — `Transliterator` conformance: per-word `Vocalizer` lookup → `ArabicNormalizer(.transliteration)` → `CFStringTransform(kCFStringTransformToLatin)` (the former `TextProcessor.arabicToLatin`)
- **Services/ArabicNormalizer.swift** — dual-mode normalizer (aggressive for matching, minimal for transliteration)
- **Services/Vocalizer/** — `Vocalizer` + `VocalizationDictionary` (bare-word → harakat lookup from bundled `vocab.plist`)
- **Services/Quran/** — `QuranDataset`, `QuranMatcher`, `QuranAyah`, `SurahName`, plus `QuranPlugin` (a `FeaturePlugin`: gated on the `quranMode` setting; `inlineResultView` matches **synchronously** against a snapshot preloaded at init via `QuranMatcher.bestMatch`, returning `nil` on no hit per the library contract — the camera seam pops a sheet for every non-nil result — and vends an `EveryAyahAudioProvider`)
- **Services/Audio/EveryAyahAudioProvider.swift** — `AudioProvider`: streams `everyayah.com` ayah recitation, falls back to system TTS for arbitrary text
- **Views/** — `QuranMatchView` (the match card, injected audio)

Uses native iOS Translation API for translation. Tests use Swift Testing (`@Test` syntax) in `ios/Harakat LensTests/`; `ArabicTransliteratorParityTests` asserts span-level parity with the former `TextProcessor`.

### Android (`android/app/src/main/java/dev/veeso/harakatlens/`)

The library's `TextProcessingEngine` detects Arabic spans (Unicode U+0600–U+06FF) from `scriptRanges` and applies leading/trailing spacing and cleanup; the app's `ArabicTransliterator` romanises each isolated span (vocalize via dictionary → `ArabicNormalizer` strips harakat / unifies alef-ya → ICU `kCFStringTransformToLatin`). `QuranPlugin` runs verse matching alongside (exact substring + substring-fit Levenshtein fallback) and replaces the transliteration output with a match card on a hit. A shown match is **sticky** — the library re-queries on every OCR/text change but the card is not replaced until the user dismisses it (`xmark` button), which starts a 5s cooldown suppressing the same verse from respawning. OCR throttling and input debounce are owned by the library.
MVVM with Jetpack Compose + ViewModel + DataStore. Entry point is `MainActivity.kt` → `MainScreen.kt` (bottom navigation).

- **services/TextProcessor.kt** — text conversion (currently Hanzi→Pinyin via `pinyin4j`; will move to Arabic-Latin via ICU `Transliterator`)
- **services/OcrService.kt** — ML Kit text recognition + LiveOcrAnalyzer for camera (currently Chinese; Arabic recognizer planned)
- **services/AppSettingsStore.kt** — DataStore Preferences for settings persistence
- **ui/screens/** — Compose screens (TextModeView, CameraModeView, SettingsModeView)
- **ui/screens/textmode/TextModeViewModel.kt** — ViewModel with StateFlow for text mode
- **ui/AppDesign.kt** — Shared design constants including `brandGreen` (`#006C35`)

Uses Google ML Kit Translate for translation. Dependency versions managed in `android/gradle/libs.versions.toml`. Tests use JUnit 4 in `android/app/src/test/`.

### Core Algorithm (both platforms)

The iOS TextProcessor detects Arabic spans (Unicode U+0600–U+06FF), normalizes them via `ArabicNormalizer` (strips harakat, unifies alef/ya), and transliterates to Latin via ICU `kCFStringTransformToLatin`. Quran-aware verse matching runs alongside when Quran mode is enabled. OCR uses 1-second throttling; text input is debounced at 0.8s.

## Platform Configuration

- **iOS:** Min deployment target uses iOS 15+ Translation API. Info.plist at `ios/Harakat-Lens-Info.plist`. Bundle ID: `dev.veeso.harakatlens`
- **Android:** `minSdk 26`, `targetSdk 36`, `compileSdk 36`, Java 11. Manifest requests CAMERA permission. App ID: `dev.veeso.harakatlens`

## Branding

- **Primary color:** `#006C35` (Harakat green). Variants: `#00994C` (light, HSL L=30%), `#004C26` (dark, HSL L=15%).
- **Glyph:** white Arabic letter on green background; in-app icon at `assets/logo.png`.
- **Tagline:** "Instantly read and transliterate Arabic text with built-in OCR".
- **Site:** `harakatlens.app` (footer + sitemap), repo `github.com/veeso/Harakat-Lens`.
