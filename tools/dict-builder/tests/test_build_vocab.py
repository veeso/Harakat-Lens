import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from build_vocab import strip_harakat, tokenize


def test_strip_harakat_removes_diacritics():
    assert strip_harakat("كِتَابٌ") == "كتاب"


def test_strip_harakat_removes_superscript_alef():
    assert strip_harakat("الرَّحْمَٰنِ") == "الرحمن"


def test_strip_harakat_drops_tatweel():
    assert strip_harakat("اـلسـلام") == "السلام"


def test_strip_harakat_preserves_alef_variants():
    # The dictionary keys must distinguish alef variants so lookup matches
    # exactly what the iOS side hands in (which does not unify them).
    assert strip_harakat("أ") == "أ"


def test_tokenize_splits_on_whitespace_and_punctuation():
    assert tokenize("كتاب، كتب  الله.") == ["كتاب", "كتب", "الله"]


def test_tokenize_drops_empty():
    assert tokenize("   ") == []
