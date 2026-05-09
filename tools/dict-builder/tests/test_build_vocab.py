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


from build_vocab import is_acceptable_token, aggregate_vocab


def test_is_acceptable_token_drops_short():
    assert is_acceptable_token("ا") is False
    assert is_acceptable_token("كت") is True


def test_is_acceptable_token_drops_short_after_strip():
    # Token that is only harakat decoration around a single letter.
    assert is_acceptable_token("ًا") is False


def test_is_acceptable_token_drops_pure_digits():
    assert is_acceptable_token("١٢٣") is False


def test_is_acceptable_token_drops_non_arabic():
    assert is_acceptable_token("hello") is False
    assert is_acceptable_token("كتاب1") is False


def test_aggregate_vocab_picks_highest_frequency_vocalization():
    tokens = ["كَتَب", "كَتَب", "كُتُب", "كتب"]
    # bare 'كتب' appears 4 times: 2 as كَتَب, 1 as كُتُب, 1 as كتب (bare).
    # Highest-frequency *vocalized* (excluding bare) wins.
    result = aggregate_vocab(tokens)
    assert result["كتب"] == "كَتَب"


def test_aggregate_vocab_falls_back_to_bare_when_no_vocalization():
    tokens = ["كتب", "كتب"]
    # All occurrences are bare — no vocalized variant means no useful entry.
    result = aggregate_vocab(tokens)
    assert "كتب" not in result


import plistlib
import tempfile

from build_vocab import build_from_corpus, write_plist


def test_build_from_corpus_respects_top_n(tmp_path: Path):
    corpus = tmp_path / "c.txt"
    corpus.write_text(
        "كِتَاب " * 10
        + "كِتَاب " * 10
        + "مَدْرَسَة " * 5
        + "بَيْت " * 1
    )
    result = build_from_corpus([corpus], top_n=2)
    # كتاب (20) and مدرسة (5) win; بيت (1) is cut.
    assert set(result.keys()) == {"كتاب", "مدرسة"}


def test_write_plist_round_trip(tmp_path: Path):
    out = tmp_path / "vocab.plist"
    write_plist({"كتاب": "كِتَاب", "الله": "اللَّه"}, out)
    with out.open("rb") as f:
        loaded = plistlib.load(f)
    assert loaded == {"كتاب": "كِتَاب", "الله": "اللَّه"}
    # Verify binary format (FMT_BINARY starts with bplist00).
    assert out.read_bytes()[:8] == b"bplist00"


def test_build_end_to_end_on_fixture(tmp_path: Path):
    fixture = Path(__file__).parent / "fixtures" / "sample_corpus.txt"
    out = tmp_path / "vocab.plist"
    result = build_from_corpus([fixture], top_n=10)
    write_plist(result, out)
    with out.open("rb") as f:
        loaded = plistlib.load(f)
    assert "كتاب" in loaded
    assert loaded["كتاب"] == "كِتَاب"
