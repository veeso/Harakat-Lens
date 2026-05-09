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
