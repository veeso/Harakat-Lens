"""Build vocab.plist from the Tashkeela corpus.

Outputs a binary plist mapping bare Arabic word -> highest-frequency
vocalized form. The plist is consumed at runtime by the iOS app.
"""

from __future__ import annotations

import argparse
import plistlib
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

# Harakat (U+064B-U+0652), superscript alef (U+0670), tatweel (U+0640).
_HARAKAT_RE = re.compile("[ً-ْٰـ]")
# Common Arabic punctuation that must split tokens.
_ARABIC_PUNCT = "،؛؟۔"
# Token = contiguous run of Arabic-block characters (U+0600-U+06FF).
# Punctuation lives in this range too, so a second split pass below removes it.
_TOKEN_RE = re.compile("[؀-ۿ]+")


def strip_harakat(text: str) -> str:
    """Remove all harakat, superscript alef, and tatweel from `text`."""
    return _HARAKAT_RE.sub("", text)


def tokenize(text: str) -> list[str]:
    """Return Arabic-block tokens. Punctuation and non-Arabic chars split."""
    out: list[str] = []
    for match in _TOKEN_RE.finditer(text):
        token = match.group(0)
        # Re-split on Arabic punctuation that the bracket class included.
        for piece in re.split(f"[{_ARABIC_PUNCT}]+", token):
            if piece:
                out.append(piece)
    return out


_ARABIC_LETTER_RE = re.compile("[ء-غف-يٮ-ۓە-ۿ]")
_ARABIC_DIGIT_RE = re.compile("[٠-٩۰-۹]")


def is_acceptable_token(token: str) -> bool:
    """True if `token` is a usable Arabic word for the dictionary."""
    if not token:
        return False
    bare = strip_harakat(token)
    if len(bare) < 2:
        return False
    # Reject tokens that contain anything outside the Arabic letter set
    # (ASCII letters, Latin digits, punctuation).
    for ch in bare:
        if not _ARABIC_LETTER_RE.match(ch):
            return False
    # Reject pure Arabic-Indic digit strings (already excluded by the letter
    # check, but keep this explicit for clarity if the letter set widens).
    if all(_ARABIC_DIGIT_RE.match(ch) for ch in bare):
        return False
    return True


def aggregate_vocab(tokens: list[str]) -> dict[str, str]:
    """Group tokens by bare form, pick highest-frequency vocalized variant.

    Skips bare forms that have no vocalized variant in the corpus — bare-only
    entries provide no information that ICU could not derive on its own.
    """
    by_bare: dict[str, Counter[str]] = defaultdict(Counter)
    for token in tokens:
        if not is_acceptable_token(token):
            continue
        bare = strip_harakat(token)
        by_bare[bare][token] += 1

    result: dict[str, str] = {}
    for bare, variants in by_bare.items():
        # Variants that differ from the bare form are the vocalized ones.
        vocalized = {tok: count for tok, count in variants.items() if tok != bare}
        if not vocalized:
            continue
        winner = max(vocalized.items(), key=lambda kv: (kv[1], kv[0]))[0]
        result[bare] = winner
    return result


def build_from_corpus(paths: list[Path], top_n: int) -> dict[str, str]:
    """Read every file in `paths`, tokenize, aggregate, return top-N entries.

    Top-N is by total bare-form frequency (sum across all vocalizations).
    """
    raw_tokens: list[str] = []
    bare_freq: Counter[str] = Counter()
    for path in paths:
        text = Path(path).read_text(encoding="utf-8")
        for token in tokenize(text):
            if not is_acceptable_token(token):
                continue
            raw_tokens.append(token)
            bare_freq[strip_harakat(token)] += 1

    full = aggregate_vocab(raw_tokens)
    if top_n <= 0 or top_n >= len(full):
        return full
    keep = {bare for bare, _ in bare_freq.most_common(top_n)}
    return {bare: voc for bare, voc in full.items() if bare in keep}


def write_plist(mapping: dict[str, str], path: Path) -> None:
    """Write `mapping` as a binary plist at `path`."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as f:
        plistlib.dump(mapping, f, fmt=plistlib.FMT_BINARY)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "corpus",
        nargs="+",
        type=Path,
        help="One or more Tashkeela corpus files (or directories of .txt).",
    )
    parser.add_argument(
        "--top-n",
        type=int,
        default=40000,
        help="Keep only the top-N bare forms by frequency. 0 = keep all.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("ios/Harakat Lens/Resources/vocab.plist"),
        help="Output plist path (relative to repo root).",
    )
    args = parser.parse_args(argv)

    paths: list[Path] = []
    for entry in args.corpus:
        if entry.is_dir():
            paths.extend(sorted(p for p in entry.rglob("*.txt") if p.is_file()))
        else:
            paths.append(entry)
    if not paths:
        print("error: no corpus files found", file=sys.stderr)
        return 1

    mapping = build_from_corpus(paths, top_n=args.top_n)
    write_plist(mapping, args.output)
    print(f"wrote {len(mapping)} entries to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
