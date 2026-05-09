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
