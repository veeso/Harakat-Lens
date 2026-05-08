#!/usr/bin/env python3
"""Build quran.json + surah-names.json for the iOS bundle.

Run once. Re-run only when sources change.

Sources:
  Arabic text: Tanzil Project — Uthmani script (public dataset)
    License: Creative Commons BY-ND 3.0 Unported
    https://tanzil.net/docs/tanzil_project
  Translation: Sahih International (en.sahih)
    Distributed via Tanzil; copyright Sahih International / Dar Abul-Qasim Publishing House
  Surah metadata: AlQuran.cloud v1 API (public, no auth required)
"""

import argparse
import json
import os
import re
import sys

# ---------------------------------------------------------------------------
# Optional PyICU import — graceful fallback if ICU dev libs are unavailable
# ---------------------------------------------------------------------------
try:
    import icu  # PyICU

    _ICU_TRANSLITERATOR = icu.Transliterator.createInstance("Arabic-Latin")
    _ICU_AVAILABLE = True
except ImportError:
    _ICU_AVAILABLE = False
    _ICU_TRANSLITERATOR = None
    print(
        "WARNING: PyICU not available — transliteration field will be empty string.\n"
        "Install with: pip install PyICU (may require ICU dev libs).",
        file=sys.stderr,
    )

# ---------------------------------------------------------------------------
# Source URLs (primary + fallback)
# ---------------------------------------------------------------------------
ARABIC_URLS = [
    # Tanzil direct download (plain text, pipe-delimited)
    "https://tanzil.net/pub/download/index.php?quranType=uthmani&outType=txt-2&fileName=quran-uthmani",
    # GitHub mirror (JSON format — handled separately in parse_lines)
    "https://raw.githubusercontent.com/risan/quran-json/main/data/quran/quran-uthmani.json",
]

TRANSLATION_URLS = [
    # Tanzil Sahih International translation
    "https://tanzil.net/trans/en.sahih",
    # Alternative GitHub mirror (plain text)
    "https://raw.githubusercontent.com/risan/quran-json/main/data/editions/en-sahih-international.txt",
]

SURAH_API_URLS = [
    "https://api.alquran.cloud/v1/surah",
    "https://api.quran.com/api/v4/chapters?language=en",
]

EXPECTED_AYAT = 6236
EXPECTED_SURAHS = 114


# ---------------------------------------------------------------------------
# Fetch helpers
# ---------------------------------------------------------------------------

def fetch(urls: list[str], label: str) -> tuple[str, str]:
    """Try each URL in order; return (content, url_used) on the first success.

    Raises RuntimeError if all URLs fail.
    """
    import requests  # local import so failures are explicit

    last_exc = None
    for url in urls:
        try:
            print(f"  fetching {label} from {url} ...", file=sys.stderr)
            resp = requests.get(url, timeout=60)
            resp.raise_for_status()
            content_type = resp.headers.get("Content-Type", "")
            text = resp.text
            # Reject obvious HTML error pages
            if "text/html" in content_type and "<html" in text.lower():
                print(
                    f"  WARNING: {url} returned HTML — skipping.", file=sys.stderr
                )
                continue
            print(f"  OK ({len(text)} chars)", file=sys.stderr)
            return text, url
        except Exception as exc:  # noqa: BLE001
            print(f"  WARN: {url} failed — {exc}", file=sys.stderr)
            last_exc = exc

    raise RuntimeError(
        f"All sources for {label!r} failed. Last error: {last_exc}"
    )


def fetch_json(urls: list[str], label: str):
    """Fetch and JSON-parse the first successful URL."""
    import requests

    last_exc = None
    for url in urls:
        try:
            print(f"  fetching {label} from {url} ...", file=sys.stderr)
            resp = requests.get(url, timeout=60)
            resp.raise_for_status()
            data = resp.json()
            print(f"  OK", file=sys.stderr)
            return data, url
        except Exception as exc:  # noqa: BLE001
            print(f"  WARN: {url} failed — {exc}", file=sys.stderr)
            last_exc = exc

    raise RuntimeError(
        f"All sources for {label!r} failed. Last error: {last_exc}"
    )


# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

def parse_tanzil_pipe(text: str) -> list[tuple[int, int, str]]:
    """Parse Tanzil pipe-delimited format: `surah|ayah|text`.

    Skips comment lines (starting with #) and blank lines.
    Returns list of (surah, ayah, text) triples, surah/ayah ascending.
    """
    results = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) < 3:
            continue
        try:
            surah = int(parts[0])
            ayah = int(parts[1])
            verse_text = "|".join(parts[2:]).strip()
        except ValueError:
            continue
        results.append((surah, ayah, verse_text))
    return results


def parse_risan_arabic_json(raw_json: str) -> list[tuple[int, int, str]]:
    """Parse risan/quran-json format.

    Supports two layouts:
      - Array of objects: [{surah, ayah, text}, ...]
      - Nested dict: {surah: [text, ...], ...}  (1-indexed)
    """
    data = json.loads(raw_json)
    results = []

    if isinstance(data, list):
        # Flat array form
        for entry in data:
            if isinstance(entry, dict):
                surah = int(entry.get("surah", entry.get("chapter", 0)))
                ayah = int(entry.get("ayah", entry.get("verse", 0)))
                text = str(entry.get("text", entry.get("content", "")))
                results.append((surah, ayah, text))
    elif isinstance(data, dict):
        # Nested form: keys are surah numbers (as strings)
        for surah_key in sorted(data.keys(), key=lambda k: int(k)):
            surah = int(surah_key)
            verses = data[surah_key]
            if isinstance(verses, list):
                for ayah_idx, text in enumerate(verses, start=1):
                    results.append((surah, ayah_idx, str(text)))
            elif isinstance(verses, dict):
                for ayah_key in sorted(verses.keys(), key=lambda k: int(k)):
                    ayah = int(ayah_key)
                    results.append((surah, ayah, str(verses[ayah_key])))

    return sorted(results, key=lambda t: (t[0], t[1]))


def parse_lines(text: str, source_url: str) -> list[tuple[int, int, str]]:
    """Dispatch to the right parser based on the URL / content."""
    stripped = text.strip()
    # Try JSON if the content looks like it
    if stripped.startswith("{") or stripped.startswith("["):
        try:
            return parse_risan_arabic_json(text)
        except Exception as exc:  # noqa: BLE001
            print(
                f"  WARNING: JSON parse failed ({exc}), trying pipe format.",
                file=sys.stderr,
            )
    return parse_tanzil_pipe(text)


def parse_translation(text: str) -> list[tuple[int, int, str]]:
    """Parse Tanzil translation (pipe-delimited, same format as Arabic)."""
    return parse_tanzil_pipe(text)


# ---------------------------------------------------------------------------
# Arabic normalizer (mirrors ArabicNormalizer.swift — unifyTaMarbuta = false)
# ---------------------------------------------------------------------------

# Characters to remove
_TATWEEL = "ـ"
_HARAKAT = set(chr(c) for c in range(0x064B, 0x0652 + 1))
_SUPERSCRIPT_ALEF = "ٰ"
_REMOVE = set(_HARAKAT) | {_TATWEEL, _SUPERSCRIPT_ALEF}

# Alef variants → bare alef (U+0627)
_ALEF_VARIANTS = {"أ", "إ", "آ", "ٱ"}
_BARE_ALEF = "ا"

# Alef maqsura → ya
_ALEF_MAQSURA = "ى"
_YA = "ي"

_WHITESPACE_RE = re.compile(r"\s+")


def normalize_arabic(text: str) -> str:
    """Normalize Arabic text to match ArabicNormalizer.swift (unifyTaMarbuta=false).

    Steps (applied in order to match the Swift implementation):
      1. Remove tatweel U+0640.
      2. Remove harakat U+064B–U+0652 and superscript alef U+0670.
      3. Replace alef variants (U+0623, U+0625, U+0622, U+0671) with U+0627.
      4. Replace alef maqsura (U+0649) with ya (U+064A).
      5. Collapse whitespace and trim.
    Ta marbuta (U+0629 / ة) is left unchanged.
    """
    chars = []
    for ch in text:
        cp = ord(ch)
        if ch in _REMOVE:
            continue
        if ch in _ALEF_VARIANTS:
            chars.append(_BARE_ALEF)
            continue
        if ch == _ALEF_MAQSURA:
            chars.append(_YA)
            continue
        chars.append(ch)

    joined = "".join(chars)
    joined = _WHITESPACE_RE.sub(" ", joined).strip()
    return joined


# ---------------------------------------------------------------------------
# Transliteration
# ---------------------------------------------------------------------------

def transliterate(text: str) -> str:
    """Return Latin transliteration of normalized Arabic text via PyICU.

    Returns empty string if PyICU is unavailable.
    """
    if not _ICU_AVAILABLE or _ICU_TRANSLITERATOR is None:
        return ""
    return _ICU_TRANSLITERATOR.transliterate(text)


# ---------------------------------------------------------------------------
# Surah names
# ---------------------------------------------------------------------------

# U+0633 U+0648 U+0631 U+0629 = سورة (the word "Surah")
# The AlQuran.cloud API returns names prefixed with "سُورَةُ " (with diacritics)
_SURAH_PREFIX_RE = re.compile(r"^سُورَةُ\s+")


def _strip_surah_prefix(arabic: str) -> str:
    """Remove leading 'سُورَةُ ' prefix and diacritics from a surah name.

    The AlQuran.cloud API returns e.g. 'سُورَةُ ٱلْفَاتِحَةِ'; we want 'الفاتحة'.
    Strips the prefix, then removes harakat and alef wasla (U+0671) → bare alef.
    """
    arabic = _SURAH_PREFIX_RE.sub("", arabic)
    return normalize_arabic(arabic)


def build_surah_names(raw_data, source_url: str) -> list[dict]:
    """Build surah names list from API response.

    Supports:
      - AlQuran.cloud v1: { data: [ { number, name, englishName, englishNameTranslation } ] }
      - Quran.com v4: { chapters: [ { id, name_arabic, name_simple, translated_name: { name } } ] }
    """
    surahs = []

    # AlQuran.cloud v1 format
    if isinstance(raw_data, dict) and "data" in raw_data:
        entries = raw_data["data"]
        for entry in entries:
            number = int(entry.get("number", 0))
            arabic_raw = str(entry.get("name", ""))
            # The API returns "سُورَةُ X" — strip the "سُورَةُ " prefix and diacritics
            arabic = _strip_surah_prefix(arabic_raw)
            transliteration = str(entry.get("englishName", ""))
            english = str(entry.get("englishNameTranslation", ""))
            surahs.append(
                {
                    "number": number,
                    "english": english,
                    "transliteration": transliteration,
                    "arabic": arabic,
                }
            )

    # Quran.com v4 format
    elif isinstance(raw_data, dict) and "chapters" in raw_data:
        entries = raw_data["chapters"]
        for entry in entries:
            number = int(entry.get("id", 0))
            arabic = str(entry.get("name_arabic", ""))
            transliteration = str(entry.get("name_simple", ""))
            translated = entry.get("translated_name", {})
            english = str(translated.get("name", "")) if isinstance(translated, dict) else ""
            surahs.append(
                {
                    "number": number,
                    "english": english,
                    "transliteration": transliteration,
                    "arabic": arabic,
                }
            )

    else:
        raise ValueError(
            f"Unrecognised surah API response shape from {source_url}. "
            f"Keys: {list(raw_data.keys()) if isinstance(raw_data, dict) else type(raw_data)}"
        )

    surahs.sort(key=lambda s: s["number"])

    if len(surahs) != EXPECTED_SURAHS:
        raise ValueError(
            f"Expected {EXPECTED_SURAHS} surahs, got {len(surahs)} from {source_url}"
        )

    return surahs


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build quran.json + surah-names.json for the iOS bundle."
    )
    # Resolve default relative to the repo root (parent of the tools/ directory)
    _repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    _default_out = os.path.join(_repo_root, "ios", "Harakat Lens", "Resources")
    parser.add_argument(
        "--out-dir",
        default=_default_out,
        help=f"Output directory (default: {_default_out})",
    )
    args = parser.parse_args()

    out_dir: str = args.out_dir
    os.makedirs(out_dir, exist_ok=True)

    # ------------------------------------------------------------------
    # 1. Fetch Arabic (Uthmani)
    # ------------------------------------------------------------------
    print("\n[1/4] Fetching Arabic text (Tanzil Uthmani)...", file=sys.stderr)
    arabic_text, arabic_url = fetch(ARABIC_URLS, "Arabic Uthmani")
    arabic_triples = parse_lines(arabic_text, arabic_url)
    print(
        f"  parsed {len(arabic_triples)} ayat from {arabic_url}", file=sys.stderr
    )

    # ------------------------------------------------------------------
    # 2. Fetch English translation (Sahih International)
    # ------------------------------------------------------------------
    print("\n[2/4] Fetching Sahih International translation...", file=sys.stderr)
    trans_text, trans_url = fetch(TRANSLATION_URLS, "Sahih International")
    trans_triples = parse_translation(trans_text)
    print(
        f"  parsed {len(trans_triples)} translations from {trans_url}",
        file=sys.stderr,
    )

    # ------------------------------------------------------------------
    # 3. Cross-check alignment
    # ------------------------------------------------------------------
    print("\n[3/4] Cross-checking alignment...", file=sys.stderr)
    arabic_keys = [(s, a) for s, a, _ in arabic_triples]
    trans_keys = [(s, a) for s, a, _ in trans_triples]

    if arabic_keys != trans_keys:
        # Detailed diff for debugging
        arabic_set = set(arabic_keys)
        trans_set = set(trans_keys)
        only_arabic = sorted(arabic_set - trans_set)[:10]
        only_trans = sorted(trans_set - arabic_set)[:10]
        print(
            f"ERROR: Arabic and translation keys do not align.\n"
            f"  Arabic has {len(arabic_keys)} entries, translation has {len(trans_keys)}.\n"
            f"  Keys only in Arabic (first 10): {only_arabic}\n"
            f"  Keys only in translation (first 10): {only_trans}",
            file=sys.stderr,
        )
        return 1

    if len(arabic_triples) != EXPECTED_AYAT:
        print(
            f"ERROR: Expected {EXPECTED_AYAT} ayat but got {len(arabic_triples)}.",
            file=sys.stderr,
        )
        return 1

    print(f"  alignment OK — {len(arabic_triples)} ayat", file=sys.stderr)

    # ------------------------------------------------------------------
    # 4. Fetch surah names
    # ------------------------------------------------------------------
    print("\n[4/4] Fetching surah names...", file=sys.stderr)
    surah_raw, surah_url = fetch_json(SURAH_API_URLS, "surah names")
    surah_names = build_surah_names(surah_raw, surah_url)
    print(f"  got {len(surah_names)} surah names from {surah_url}", file=sys.stderr)

    # ------------------------------------------------------------------
    # 5. Build quran.json
    # ------------------------------------------------------------------
    print("\n[5/5] Building quran.json...", file=sys.stderr)
    trans_map = {(s, a): t for s, a, t in trans_triples}
    quran_entries = []
    for surah, ayah, text in arabic_triples:
        norm = normalize_arabic(text)
        translit = transliterate(norm)
        quran_entries.append(
            {
                "surah": surah,
                "ayah": ayah,
                "text": text,
                "normalized": norm,
                "transliteration": translit,
                "translation_en": trans_map[(surah, ayah)],
            }
        )

    # ------------------------------------------------------------------
    # Write outputs
    # ------------------------------------------------------------------
    quran_path = os.path.join(out_dir, "quran.json")
    surah_path = os.path.join(out_dir, "surah-names.json")

    with open(quran_path, "w", encoding="utf-8") as fh:
        json.dump(quran_entries, fh, ensure_ascii=False, separators=(",", ":"))

    with open(surah_path, "w", encoding="utf-8") as fh:
        json.dump(surah_names, fh, ensure_ascii=False, separators=(",", ":"))

    print(f"\nwrote {quran_path} ({len(quran_entries)} entries)", file=sys.stderr)
    print(f"wrote {surah_path} ({len(surah_names)} entries)", file=sys.stderr)

    if not _ICU_AVAILABLE:
        print(
            "\nNOTE: transliteration fields are empty (PyICU unavailable). "
            "The iOS layer will transliterate on the fly.",
            file=sys.stderr,
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
