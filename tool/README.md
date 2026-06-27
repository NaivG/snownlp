# Regenerating the model files

The Dart package ships two flavours of model data under
`lib/src/data/`:

| Extension | Role                                                              |
|-----------|-------------------------------------------------------------------|
| `*.json`  | **Intermediate** output from `tool/export_models.py`. Kept in the repo for transparency and as the input to the binary encoder. |
| `*.bin`   | **Runtime** format that the Dart package loads. Compact + gzipped, ~8× smaller than the JSON. |

You only need to regenerate these if you retrain one of the models.

## End-to-end pipeline

```
snownlp/.marshal.3   ─── export_models.py ───▶   lib/src/data/*.json
                                                       │
                                                       ▼
                                              build_models.dart
                                                       │
                                                       ▼
                                              lib/src/data/*.bin
```

## Step 1 — `tool/export_models.py` (Python)

Reads the local snownlp checkout, normalises Python-specific types
(`tuple`, `set`, `NormalProb`, `AddOneProb`) and writes one JSON file
per model. Pure stdlib — no third-party Python packages required.

```
snownlp/             # isnowfy/snownlp clone (vendored at the repo root)
lib/src/data/        # outputs (intermediate)
tool/export_models.py
```

From the project root:

```
python tool/export_models.py            # pretty-printed JSON
python tool/export_models.py --compact  # one-line per file
```

## Step 2 — `tool/build_models.dart` (Dart)

Reads each `*.json` from `lib/src/data/`, encodes it into the typed
`SentimentData` / `SegData` / `TagData` / ... payload, gzips the
payload, and writes the wrapped `*.bin` file. The on-disk format is
documented in `lib/src/utils/binary_format.dart` and verified by
`test/binary_format_test.dart`.

From the project root:

```
dart run tool/build_models.dart
```

Expected output (sizes after a clean rebuild):

```
Building lib\src/data/*.bin from .json sources...
  sentiment              json=    576384  bin=    242933  ratio=42.1%
  seg                    json=  54594396  bin=   5771851  ratio=10.6%
  tag                    json=   5971491  bin=   1209519  ratio=20.3%
  zh2hans                json=     43782  bin=     18926  ratio=43.2%
  pinyin                 json=   2012731  bin=    479293  ratio=23.8%
  stopwords              json=     12099  bin=      5777  ratio=47.7%
Done.
```

The `*.json` files are kept in the repo so the conversion is reproducible
and so humans can diff/inspect the model contents. The runtime never
reads them.

## Source map

| Output file           | Source                                                 |
|-----------------------|--------------------------------------------------------|
| `sentiment.json` / `.bin` | `snownlp/sentiment/sentiment.marshal.3`            |
| `seg.json` / `.bin`       | `snownlp/seg/seg.marshal.3`                        |
| `tag.json` / `.bin`       | `snownlp/tag/tag.marshal.3`                        |
| `zh2hans.json` / `.bin`   | `snownlp/normal/zh.py` (parsed with `ast.literal_eval`) |
| `pinyin.json` / `.bin`    | `snownlp/normal/pinyin.txt`                        |
| `stopwords.json` / `.bin` | `snownlp/normal/stopwords.txt`                     |

## After regenerating

1. `dart test` — every test must pass, including the round-trip
   checks in `test/binary_format_test.dart`.
2. Inspect the new `*.bin` sizes — `seg.bin` should dominate at
   ~5–6 MB; the rest should be sub-megabyte.
3. Commit both the `*.json` and `*.bin` changes.

## Schema

Every JSON file has a top-level `_format_version` field (currently
`1`). Adding a new field is fine; changing the meaning of an existing
one requires bumping the version and adding a migration path on the
Dart side.

Tuple-keys in dictionaries (used everywhere in TnT trans tables) are
joined with `\x01` (SOH) into a single string. SOH never appears in
Chinese characters or tags, so this round-trip is unambiguous.
