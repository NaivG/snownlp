# Changelog

## 1.2.0

- **First-class Flutter assets support.** Added
  `pubspec.yaml`'s `flutter.assets: lib/src/data/` block so a
  consuming Flutter app bundles the seven model `.bin` files
  automatically under `packages/snownlp/lib/src/data/`. New
  `lib/src/utils/asset_loader.dart` introduces an `AssetLoader`
  strategy:
  - `IoAssetLoader` (default, in `asset_loader_io.dart`) resolves
    `package:snownlp/src/data/$name` via `Isolate.resolvePackageUri`
    for any Dart VM context (`dart test`, `dart run`, the CLI).
  - `FlutterAssetLoader` (in `asset_loader_flutter.dart`) loads the
    same files through `rootBundle.load` for Flutter apps. It is
    exposed via the new opt-in `lib/snownlp_flutter.dart`, which is
    the only file in the package that imports
    `package:flutter/services.dart`.
- **Full async refactor of the model layer.** Because `rootBundle.load`
  is inherently async, the public API had to go async end-to-end.
  `seg()`, `tag()`, `getPinyin()`, `zh2hans()`, `stopwords`, plus
  every `SnowNLP` accessor (`words`, `tags`, `sentiments`, `han`,
  `pinyin`, `summary`, `keywords`) now return `Future<T>`. The six
  per-model `load()` methods became `Future<Model>` and the
  module-level singletons (`tagger`, `Sentiment`, `Stopwords`, …)
  share a single in-flight `load()` between concurrent callers.
- `SnowConfig` gains an `assetLoader` getter/setter (defaulting to
  `IoAssetLoader`) and a `loadModelBytes(name)` helper that
  every model consumer reaches for.
- `BinaryFormat.readPayloadFromBytes(bytes, expectedType, source:)`
  is the new canonical entry point; `readPayloadFromFile` now
  delegates to it. Tests that build temp fixtures still use the
  file-based variant.
- New `test/asset_loader_test.dart` covers the IO loader, error
  reporting, and the pluggability of `SnowConfig.assetLoader`.

## 1.1.0

- **Model storage switched to a compact gzipped binary format.**
  `lib/src/data/*.json` is now an intermediate artifact; the runtime
  reads `lib/src/data/*.bin` (a 16-byte header followed by a gzip
  payload) produced by `tool/build_models.dart`. Total on-disk size
  drops from ~63 MB to ~7.7 MB (≈ 8×).
- The Python export tool (`tool/export_models.py`) is unchanged in
  role: it still emits JSON. The JSON→`.bin` step is now a Dart
  command (`dart run tool/build_models.dart`).
- New `lib/src/utils/binary_format.dart` codec with a `binary_format_test.dart`
  covering header validation, every per-model schema, and determinism.
- `SnowConfig` keeps its `assetRoot` override and gains a
  `modelPath(filename)` helper used by the six model consumers.

## 1.0.0

- Initial version.
