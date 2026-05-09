# dict-builder

Builds `ios/Harakat Lens/Resources/vocab.plist` — the bare→vocalized Arabic
word map used by `Vocalizer`.

## Reproduce

```bash
# 1. Download Tashkeela. Adjust the URL if it changes.
mkdir -p .cache
curl -L -o .cache/tashkeela.zip \
  "https://sourceforge.net/projects/tashkeela/files/latest/download"
unzip -d .cache/tashkeela .cache/tashkeela.zip

# 2. Build the plist (defaults: top 40k forms, output to bundle resources).
python build_vocab.py .cache/tashkeela --top-n 40000

# 3. Verify size and entry count.
python -c "import plistlib, pathlib; \
  p = pathlib.Path('../../ios/Harakat Lens/Resources/vocab.plist'); \
  print(p.stat().st_size, 'bytes;', len(plistlib.loads(p.read_bytes())), 'entries')"
```

The corpus and `.cache/` directory are gitignored. The resulting plist is
committed.

## Tests

```bash
python -m pytest tests/ -v
```
