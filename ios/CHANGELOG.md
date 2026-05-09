# Changelog

All notable changes to this project will be documented in this file.

- [Changelog](#changelog)
  - [0.1.1](#011)
  - [0.1.0](#010)

## 0.1.1

Released on 09/05/2026

- Vocalized Arabic transliteration: bare Arabic words are looked up in a Tashkeela-derived dictionary and vocalized before ICU transliteration, so Latin output now carries short vowels (e.g. `kitāb` instead of `ktāb`).
- Tightened the camera-overlay font scaling so longer transliterations fit above their bounding boxes.
- Quran mode: a dismissed verse match is suppressed for 5 seconds to stop the same sheet from immediately re-spawning.

## 0.1.0

Released on 08/05/2026

- First stable release of the iOS application.
