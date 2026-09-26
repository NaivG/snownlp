# SnowNLP

A Simplified Chinese NLP library — Dart implementation of
[snownlp](https://github.com/isnowfy/snownlp).

Features:

- **Word segmentation** — character-based generative model (Xue & Shen, 2003)
- **POS tagging** — TnT 3-gram HMM with beam search (Brants, 2000)
- **Sentiment analysis** — multinomial Naive Bayes with Laplace smoothing
- **BM25 similarity**
- **TextRank summary / keywords**
- **Traditional → Simplified Chinese conversion**
- **Pinyin conversion**
- **First-class Flutter support** — the same `await SnowNLP(...).words`
  call site works in both the Dart VM and a Flutter app, with model
  files transparently resolved from the asset bundle.

## Install

Add to your `pubspec.yaml`:

```yaml
dependencies:
  snownlp:
    git: https://github.com/NaivG/snownlp.git
```

## Quickstart

```dart
import 'package:snownlp/snownlp.dart';

Future<void> main() async {
  final s = SnowNLP('这家店很好吃');
  print(await s.sentiments);   // 0.364763
  print(await s.words);        // [这家, 店, 很, 好吃]
  print(await s.tags);         // [(这家, r), (店, n), (很, d), (好吃, a)]
  print(await s.han);          // simplified form
  print(await s.pinyin);       // [zhe, jia, dian, hen, hao, chi]
}
```

Lower-level modules are also exported:

```dart
import 'package:snownlp/snownlp.dart';

Future<void> main() async {
  // segmentation
  print(await seg('自然语言处理'));           // [自然, 语言, 处理]

  // POS tagging
  print(await tag(['我', '喜欢', '书']));   // [r, v, n]

  // traditional -> simplified
  print(await zh2hans('繁體中文字'));       // 繁体中文字

  // pinyin
  print(await getPinyin('中国'));            // [zhong, guo]

  // sentence split + stopword filter
  print(getSentences('今天天气真好。我们去公园。'));
  final sw = await stopwords;
  print(sw.filterStop(['我', '的', '猫', '在']));

  // bayes + BM25 + TextRank
  final b = Bayes()..train([
    (['好', '吃'], 'pos'),
    (['难', '吃'], 'neg'),
  ]);
  print(b.classify(['好']));
}
```

> **Heads up:** every accessor that needs a model (`words`, `tags`,
> `sentiments`, `han`, `pinyin`, `summary`, `keywords`, …) is now
> `async` because the underlying assets are loaded through a strategy
> that, in Flutter, has to go through `rootBundle`. The CLI path and
> `dart test` use the same `Future<T>` signatures — just `await` them.

## Flutter usage

The package declares its own `lib/src/data/*.bin` files in
`pubspec.yaml`'s `flutter.assets` block, so a consuming Flutter app
**does not need to redeclare the assets** — they are bundled
automatically under the key
`packages/snownlp/lib/src/data/<filename>`.

To switch from the default file-system loader to the asset-bundle
loader, add one import and one call in `main()`:

```dart
import 'package:snownlp/snownlp_flutter.dart';

void main() {
  useFlutterAssetLoader();           // ← one-time setup
  runApp(const MyApp());
}
```

`snownlp_flutter.dart` is the only file in the package that imports
`package:flutter/services.dart`, and it is opt-in: pure-Dart
consumers (`dart test`, the CLI) never see that dependency.

```dart
// Anywhere in your Flutter app:
final s = SnowNLP('今天天气真好,我们去公园。');
final words = await s.words;        // [今天, 天气, 真, 好, ',', 我们, 去, 公园, 。]
final tags  = await s.tags;         // [(今天, t), (天气, n), ...]
```

## CLI

A `bin/snownlp.dart` binary provides quick experimentation:

```
dart run bin/snownlp.dart sentiment "这家店很好吃"
dart run bin/snownlp.dart seg "自然语言处理"
dart run bin/snownlp.dart tag "我喜欢这本书"
dart run bin/snownlp.dart han "繁體中文字"
dart run bin/snownlp.dart pinyin "中国"
```

Run `dart run bin/snownlp.dart help` for the full command list.

## How it works

Snownlp ships its models as Python `marshal` byte streams
(`.marshal.3`). Dart can't read those, so the package ships
**pre-converted JSON models** under `lib/src/data/`, then encodes them
into a compact gzipped-binary format that the runtime loads:

| Stage           | Tool                      | Output                         |
|-----------------|---------------------------|--------------------------------|
| 1. clone snownlp | `git clone` (Git)         | `snownlp/`                    |
| 2. marshal → JSON | `tool/export_models.py` (Python) | `lib/src/data/*.json`     |
| 3. JSON → `.bin`  | `tool/build_models.dart` (Dart)   | `lib/src/data/*.bin`      |

Step 2 needs the local snownlp checkout; step 3 only needs the
intermediate JSON.

```bash
# clone the snownlp repo
git clone https://github.com/isnowfy/snownlp.git

# Regenerate JSON (only when retraining a model)
python tool/export_models.py --compact

# Encode the JSON into the runtime binary format
dart run tool/build_models.dart
```

Step 3 reduces the
~63 MB JSON set to ~7.7 MB of `.bin` files (≈ 8×).

See `tool/README.md` for full details.

### Asset resolution

There are two [`AssetLoader`](lib/src/utils/asset_loader.dart)
implementations:

* **`IoAssetLoader`** (default, in
  [`asset_loader_io.dart`](lib/src/utils/asset_loader_io.dart)) —
  resolves `package:snownlp/src/data/$name` to the on-disk path via
  [`Isolate.resolvePackageUri`](https://api.dart.dev/dart-isolate/Isolate/resolvePackageUri.html)
  and reads from `.pub-cache` (or your local path). Works in any
  Dart VM context — `dart test`, `dart run`, the package CLI.
* **`FlutterAssetLoader`** (in
  [`asset_loader_flutter.dart`](lib/src/utils/asset_loader_flutter.dart))
  — loads the same file from the bundled asset image with
  [`rootBundle.load('packages/snownlp/lib/src/data/$name')`](https://api.flutter.dev/flutter/services/rootBundle.html).
  Opt-in via `package:snownlp/snownlp_flutter.dart`.

`package:flutter/services.dart` is therefore only ever imported from
the opt-in file, and pure-Dart consumers never pull the Flutter SDK
into the import graph.

## Layout

```
lib/
  snownlp.dart                   public exports (pure Dart)
  snownlp_flutter.dart           opt-in Flutter bootstrap
  src/
    config.dart                  asset path + loader resolver
    snow_nlp.dart                SnowNLP facade
    bayes/                       multinomial NB + Sentiment wrapper
    segmentation/                CBGM segmenter (character_model + Seg)
    tag/                         TnT POS tagger
    sim/                         BM25
    summary/                     TextRank + KeywordTextRank + SimpleMerge
    normal/                      zh2hans, pinyin, sentences, stopwords
    utils/                       Trie, BaseProb / NormalProb / AddOneProb,
                                 binary_format (model codec),
                                 asset_loader (interface + io + flutter impls)
    data/                        pre-converted binary models (*.bin) plus
                                 their JSON sources
test/
  ...                            unit + golden comparison tests
tool/
  export_models.py               snownlp marshal -> JSON
  build_models.dart              JSON -> .bin encoder
  dump_binary.dart               CLI to inspect a .bin file
  README.md                      pipeline docs
```

## Running tests

```bash
dart test
```

Tests cover every module plus golden comparisons against the original
snownlp Python implementation for segmentation, POS tags, sentiment,
zh2hans, and pinyin.

## License

MIT License, see [`LICENSE`](LICENSE).

```LICENSE
Copyright © 2026 NaivG

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, 
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR 
ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF 
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

The original snownlp is licensed under the MIT License, see
[`snownlp_LICENSE`](snownlp_LICENSE).
