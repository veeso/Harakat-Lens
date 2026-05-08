# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Harakat Lens is a native iOS app for scanning, transliterating, and translating Arabic text via OCR.

The repository was migrated from a Chinese-Hanzi-to-Pinyin app (BiangBiang Hanzi). Arabic transliteration and Quran-aware features follow the spec at `~/Documents/Specs/harakat-lens.md`.

## Build & Development Commands

### iOS (Swift + SwiftUI)

- **Open project:** `open "ios/Harakat Lens.xcodeproj"`
- **Build:** Xcode ⌘B or `xcodebuild -project "ios/Harakat Lens.xcodeproj" -scheme "Harakat Lens" build`
- **Run tests:** `xcodebuild test -project "ios/Harakat Lens.xcodeproj" -scheme "Harakat Lens" -destination 'platform=iOS Simulator,name=iPhone 17'`
- **Format code:** `swiftformat ./ios` (requires `brew install swiftformat`). **Run this whenever iOS code is modified.**

### Website (Tailwind CSS v3)

- **Build CSS:** `npx tailwindcss -i ./site/input.css -o ./site/output.css --minify`. **Run this whenever website content under `site/` is modified.**

## Architecture

### iOS (`ios/Harakat Lens/`)

MVVM with SwiftUI + Combine. Entry point is `Harakat_LensApp.swift` → `ContentView.swift` (TabView with Text, Camera, Settings tabs).

- **Services/TextProcessor.swift** — text conversion using `CFStringTransform` with ICU `Arabic-Latin`, including `ArabicNormalizer` pre-processing
- **Services/Camera/CameraModel.swift** — AVFoundation camera + Vision OCR (ObservableObject)
- **Services/Quran/** — `QuranDataset`, `QuranMatcher`, `QuranAyah`, `SurahName` for Quran-aware matching
- **Services/Audio/AudioPlayerService.swift** — AVSpeechSynthesizer for Arabic TTS + AVPlayer for ayah recitation streaming
- **Views/** — SwiftUI views for each tab (TextModeView, CameraModeView, SettingsView, QuranMatchView)
- **AppSettings.swift** — User preferences via `UserDefaults` (ObservableObject, injected as `@EnvironmentObject`); includes `quranMode` toggle
- **AppDesign.swift** — Shared design constants including brand color (`brandGreen` = `#006C35`)

Uses native iOS Translation API for translation. Tests use Swift Testing (`@Test` syntax) in `ios/Harakat LensTests/`.

### Core Algorithm

The TextProcessor detects Arabic spans (Unicode U+0600–U+06FF), normalizes them via `ArabicNormalizer` (strips harakat, unifies alef/ya), and transliterates to Latin via ICU `kCFStringTransformToLatin`. Quran-aware verse matching runs alongside when Quran mode is enabled (exact substring + Levenshtein fallback). OCR uses 1-second throttling; text input is debounced at 0.8s.

## Platform Configuration

- **iOS:** Min deployment target uses iOS 15+ Translation API. Info.plist at `ios/Harakat-Lens-Info.plist`. Bundle ID: `dev.veeso.harakatlens`

## Branding

- **Primary color:** `#006C35` (Harakat green). Variants: `#00994C` (light, HSL L=30%), `#004C26` (dark, HSL L=15%).
- **Glyph:** white Arabic letter on green background; in-app icon at `assets/logo.png`.
- **Tagline:** "Instantly read and transliterate Arabic text with built-in OCR".
- **Site:** `harakatlens.app` (footer + sitemap), repo `github.com/veeso/Harakat-Lens`.
