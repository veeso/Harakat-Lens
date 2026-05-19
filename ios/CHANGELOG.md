# Changelog

All notable changes to this project will be documented in this file.

- [Changelog](#changelog)
  - [0.2.0](#020)
  - [0.1.1](#011)
  - [0.1.0](#010)

## 0.2.0

Released on 19/05/2026

- Added a History feature:
  - New History tab listing explicitly-saved Hanzi entries, backed by a pure `HistoryStore` (prepend, consecutive dedup by original + variant, silent 500-entry cap, delete, clear) persisted via `UserDefaults`.
  - Ephemeral Original/Transliterated toggle, expand/collapse rows, per-entry play/stop TTS, swipe-delete, Clear All and an empty state.
  - Save button in the Text tab and long-press on an OCR box (tap still copies), each with a confirmation toast.
- Added a rate-the-app prompt: a custom dialog shown on cold launch after 3+ launches that gates the App Store write-review flow, with cap and dismiss-forever logic.
- Migrated the entire UI layer to the shared **BiangBiangUI** Swift package, replacing the local SwiftUI views, camera, `TextProcessor`, history, settings and review-prompt code with `Config` and transliterator wrappers.
- Added CI: SwiftFormat lint plus `xcodebuild` build and test on macOS.

## 0.1.1

Released on 09/05/2026

- Vocalized Arabic transliteration: bare Arabic words are looked up in a Tashkeela-derived dictionary and vocalized before ICU transliteration, so Latin output now carries short vowels (e.g. `kitāb` instead of `ktāb`).
- Tightened the camera-overlay font scaling so longer transliterations fit above their bounding boxes.
- Quran mode: a dismissed verse match is suppressed for 5 seconds to stop the same sheet from immediately re-spawning.

## 0.1.0

Released on 08/05/2026

- First stable release of the iOS application.
