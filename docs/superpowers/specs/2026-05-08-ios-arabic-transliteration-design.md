# iOS Arabic Transliteration + Quran Mode — Design

Date: 2026-05-08
Platform: iOS only
Spec source: `~/Documents/Specs/harakat-lens.md`

## Goal

Replace the existing Hanzi → Pinyin pipeline in the iOS app with an
Arabic → Latin pipeline, using ICU `Arabic-Latin` transliteration. Add a
Quran-aware mode that, when enabled, matches recognized Arabic against
the Quran and displays surah / ayah / English translation.

This milestone covers iOS only. Android is migrated separately.

## Scope

In:

- Arabic detection + ICU `Arabic-Latin` transliteration in
  `TextProcessor`, including an Arabic-specific normalization step.
- Replace `chineseVariant` setting with `quranMode` toggle.
- Translate from Arabic via Apple Translation API (source = `ar`).
- Bundled Quran dataset (Tanzil Uthmani + Sahih International English).
- Fuzzy verse matcher (normalized exact substring + Levenshtein
  fallback).
- `QuranMatchView` shown in text and camera modes when a verse matches.
- Tests covering every new/changed unit.

Out (future milestones):

- Audio recitation, bookmarks, word-by-word, multi-language Quran
  translations, handwriting OCR, dialect support.

## Architecture overview

App keeps current MVVM + SwiftUI shape (`Harakat_LensApp` →
`ContentView` → tabs). Three swap zones:

1. **Text pipeline** — `TextProcessor` rewritten for Arabic detection
   (`U+0600`–`U+06FF`), ICU `Arabic-Latin` transform, Arabic
   normalization step (tatweel strip, alef/ya unification) prior to the
   transform.
2. **Settings** — `chineseVariant` removed; `quranMode: Bool` added.
   Storage key `"chinese"` → `"quran_mode"`. Translation API source
   becomes constant `"ar"`.
3. **Quran subsystem (new)** — bundled `quran.json` + `QuranDataset`
   loader + `QuranMatcher`. Surfaces `QuranMatch { surah, ayah, arabic,
   transliteration, translationEn }`. Match runs only when
   `settings.quranMode == true`.

### New files (iOS)

- `Services/ArabicNormalizer.swift`
- `Services/Quran/QuranAyah.swift`
- `Services/Quran/QuranDataset.swift`
- `Services/Quran/QuranMatcher.swift`
- `Resources/quran.json` (bundle resource)
- `Resources/surah-names.json` (bundle resource)
- `Views/QuranMatchView.swift`
- `tools/build-quran-json.py` (build-time data prep, not in app bundle)

### Renamed

- `pinyinMap` → `transliterationMap` (`CameraModel`)
- `showPinyin` → `showTransliteration` (`CameraModel`)

### Removed

- `AppSettings.chineseVariant`
- Chinese-variant segmented picker in `SettingsView`

## Text mode flow

```text
input (debounced 0.8s)
  → ArabicNormalizer.normalize
  → TextProcessor.process → transliteration
  → if settings.quranMode: QuranMatcher.match → QuranMatch?
  → if match: QuranMatchView (surah, ayah, arabic, translit, translation_en)
  → else: existing translation section (Translation API source="ar")
```

UI changes in `TextModeView`:

- Subtitle "Convert Hanzi to Pinyin" → "Transliterate Arabic".
- Section labels: "Hanzi" → "Arabic", "Pinyin" → "Transliteration".
- Arabic input `TextField` uses `.environment(\.layoutDirection,
  .rightToLeft)` and `.multilineTextAlignment(.trailing)`.
- New `QuranMatchView` slot above translation, hidden when no match or
  `quranMode` off.
- Translation source `"zh-Hans"` / `"zh-Hant"` → constant `"ar"`.

## Camera mode flow

```text
VNRecognizeTextRequest
  recognitionLanguages = preferredArabicLanguages()
  → boxes
  → for each box:
      transliterationMap[id] = TextProcessor.process(box.text)
      if settings.quranMode and box.text.count >= 6:
        quranMatches[id] = QuranMatcher.match(box.text)
```

UI changes in `CameraLiveView` / `RecognizedTextOverlay`:

- `RecognizedTextOverlay` parameter `pinyin: String` →
  `transliteration: String`.
- Toggle button accessibility label "Toggle Pinyin" → "Toggle
  transliteration".
- New bottom-sheet `QuranMatchView` shown when any frame produced a
  match (`.presentationDetents([.medium, .large])`).

### `preferredArabicLanguages()`

Query `VNRecognizeTextRequest.supportedRecognitionLanguages(for:
revision:)`, filter prefix `"ar"`, return ordered list. Fallback to
`["ar-SA", "ar"]` if empty.

## Components

### `ArabicNormalizer`

Pure value type. Input `String`, output normalized `String`.

Operations (in order):

1. Strip tatweel `U+0640`.
2. Strip diacritics `U+064B`–`U+0652` and superscript alef `U+0670`.
3. Replace alef variants `أ إ آ ٱ` with bare alef `ا`.
4. Replace alef maqsura `ى` with `ي`.
5. (Optional, behind a flag for matcher use only) Replace ta marbuta
   `ة` with `ه`.
6. Collapse runs of whitespace.

Idempotent. No external dependencies.

### `TextProcessor` (rewritten)

```swift
class TextProcessor {
    private let regex: NSRegularExpression
    private let normalizer = ArabicNormalizer()

    init() {
        // Arabic block: U+0600–U+06FF
        let pattern = "[\\u0600-\\u06FF]+"
        regex = try! NSRegularExpression(pattern: pattern, options: [])
    }

    func process(text: String) -> String?
    func containsArabic(text: String) -> Bool
    func arabicToLatin(_ arabic: String) -> String   // ICU Arabic-Latin
}
```

Behavior mirrors current Hanzi version:

- Detect Arabic substrings via regex.
- For each match: normalize, then `CFStringTransform(...,
  kCFStringTransformToLatin, false)`.
- Apply current leading/trailing space rules so transliterated tokens
  do not run into adjacent Latin text.
- Collapse whitespace, trim.

### `QuranAyah`

```swift
struct QuranAyah: Decodable, Identifiable {
    var id: String { "\(surah):\(ayah)" }
    let surah: Int
    let ayah: Int
    let text: String
    let normalized: String
    let transliteration: String
    let translation_en: String
}
```

### `QuranDataset`

- Singleton-ish: `static let shared = QuranDataset()` with lazy
  background load triggered from `Harakat_LensApp.init`.
- Loads `quran.json` via `Bundle.main.url(forResource:withExtension:)`
  + `JSONDecoder`.
- Builds `tokenIndex: [String: [Int]]` mapping each normalized token
  to ayah indices, plus `byId: [String: QuranAyah]`.
- Exposes `all`, `tokenIndex`, and `surahName(_:)` (loaded from
  `surah-names.json`).
- On load failure: logs, leaves dataset empty; matcher returns `nil`
  for every input (graceful disable).

### `QuranMatcher`

Stateless value type backed by `QuranDataset`.

```swift
struct QuranMatch {
    let ayah: QuranAyah
    let score: Double
    enum Kind { case exact, fuzzy }
    let kind: Kind
}

func match(_ rawArabic: String) -> QuranMatch?
```

Pipeline:

```text
1. norm = ArabicNormalizer.normalize(rawArabic)
2. tokens = norm.split(whitespace).filter(count >= 2)
3. if tokens.count < 2 → nil
4. exact-substring pass (iterate dataset in ascending surah/ayah order):
     for each ayah a where a.normalized.contains(norm):
       return QuranMatch(a, score=1.0, kind=.exact)   // first hit wins
5. candidate set:
     pick rarest 2 tokens (by tokenIndex count)
     union of their ayah-index lists, capped at 200
6. levenshtein pass on candidates:
     score = 1 - (lev(norm, ayah.normalized) / max(len))
     keep best; require score >= 0.85
7. return QuranMatch or nil
```

Performance budget: < 50 ms p99 on iPhone-class hardware.

Concurrency: pure value type, safe from any thread. Camera path runs
match inside the `VNRecognizeTextRequest` completion (off the main
actor) and hops to `@MainActor` for UI update. Text mode runs match
inside the existing debounce `Task`.

## `QuranMatchView`

Card layout, brand green accent, rounded corners per `AppDesign`.

```text
┌──────────────────────────────────────────┐
│  Surah 1 · Al-Fātiḥa · Ayah 2            │
│                                          │
│  الرَّحْمَٰنِ الرَّحِيمِ                  │   (Arabic, RTL, large)
│                                          │
│  ar-raḥmāni r-raḥīmi                     │   (translit, italic)
│                                          │
│  The Most Compassionate, The Most…       │   (translation_en)
│                                          │
│  [Copy]  [Share]                         │
└──────────────────────────────────────────┘
```

- Camera mode: bottom sheet, detents `[.medium, .large]`.
- Text mode: inline section above translation panel.

## Settings

```swift
@MainActor @Observable
final class AppSettings {
    var userLanguage: String { didSet { ud.set(userLanguage, forKey: "user_language") } }
    var quranMode: Bool      { didSet { ud.set(quranMode,    forKey: "quran_mode") } }

    init(userDefaults: UserDefaults = .standard,
         defaultLanguage: String = Locale.current.language.languageCode?.identifier ?? "en") {
        self.ud = userDefaults
        self.userLanguage = userDefaults.string(forKey: "user_language") ?? defaultLanguage
        self.quranMode    = userDefaults.bool(forKey: "quran_mode")
    }
    private let ud: UserDefaults
}
```

`SettingsView` change:

```swift
Section {
    Toggle("Quran mode", isOn: $settings.quranMode)
} header: {
    Label("Quran mode", systemImage: "book.closed")
} footer: {
    Text("When on, recognized Arabic is matched against the Quran and shown with surah/ayah info.")
}
```

Add an attribution `Section` footer crediting Tanzil + Sahih
International.

Migration: old `"chinese"` key never read, harmless. Project is
pre-rebrand with no live users; no explicit migration code needed.

## Dataset build script (`tools/build-quran-json.py`)

Run-once tool. Outputs `ios/Harakat Lens/Resources/quran.json` and
`surah-names.json`. Committed alongside generated JSON.

Inputs (downloaded with checksum verification):

- `quran-uthmani.txt` from Tanzil — Uthmani script with diacritics.
- `en.sahih.txt` from Tanzil — Sahih International English translation.

Both files are line-aligned: 6,236 lines, format `surah|ayah|text`.

Steps:

1. Fetch + verify checksums.
2. Parse + join on `(surah, ayah)`.
3. Compute `normalized` field via Python equivalent of
   `ArabicNormalizer`.
4. Compute `transliteration` via PyICU `Transliterator.createInstance(
   "Arabic-Latin")` to match iOS ICU output.
5. Emit JSON array, UTF-8.

Output schema:

```json
[
  {
    "surah": 1,
    "ayah": 2,
    "text": "الرَّحْمَٰنِ الرَّحِيمِ",
    "normalized": "الرحمن الرحيم",
    "transliteration": "ar-raḥmāni r-raḥīmi",
    "translation_en": "[All] praise is [due] to Allah..."
  }
]
```

Surah names file: 114 entries `{ number, arabic, english,
transliteration }`.

Estimated size: ~4–6 MB raw JSON (within iOS bundle norms).

## Test coverage

All tests in `ios/Harakat LensTests/` using Swift Testing (`@Test`).

- `ArabicNormalizerTests` — tatweel strip, alef variants, ya/alef
  maqsura, optional ta marbuta, diacritic strip, idempotency,
  whitespace collapse.
- `TextProcessorTests` — `containsArabic`, ICU transform output,
  leading/trailing space rules, mixed Arabic+Latin, punctuation,
  pinned snapshot for `السلام عليكم`.
- `QuranDatasetTests` — JSON load, ayah count == 6236, surah/ayah
  indexing, normalized field present, `tokenIndex` populated.
- `QuranMatcherTests` — exact normalized hit, partial substring,
  Levenshtein near-miss (1–2 char OCR errors), reject below 0.85,
  empty / non-Arabic input returns `nil`, basmala determinism,
  performance check (< 50 ms per match).
- `AppSettingsTests` — defaults, persistence, `quranMode` default
  false, removal of `chineseVariant` does not break load.
- `CameraModelTests` (logic only, no AVFoundation) —
  `recognizedTexts` → `transliterationMap` mapping; verse match only
  invoked when `quranMode == true`.

CI: existing `xcodebuild test` invocation continues to run all of
these.

## Error handling

- Dataset load failure → log, leave dataset empty, matcher returns
  `nil` (transliteration still works).
- Translation API failure unchanged.
- Vision OCR failure unchanged.
- ICU transform failure (should not occur) → return original Arabic
  unchanged, log.

## Risks / known unknowns

- ICU `Arabic-Latin` output may not match the spec example
  `as-salāmu ʿalaykum` exactly. Tests pin actual ICU output; if drift
  is unacceptable, follow-up milestone adds post-process rules.
- `quran.json` size + decode time on launch must be measured. If cold
  decode > 200 ms, defer load until first Quran-mode access.
- Tanzil + Sahih license terms for App Store distribution: verify
  before shipping. Fallback: switch to a permissive translation
  source.

## Acceptance criteria

1. Hanzi/Pinyin code paths fully removed from iOS target.
2. `xcodebuild test` green; all new tests pass.
3. `swiftformat ./ios` clean.
4. Manual verification deferred to end-of-implementation pass (not run
   per-task during implementation).
