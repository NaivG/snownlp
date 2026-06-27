import 'dart:typed_data';

/// Strategy for reading the gzipped-binary model files that ship under
/// `lib/src/data/`. Two implementations live in sibling files:
///
/// * [IoAssetLoader] in `asset_loader_io.dart` — the default; resolves
///   `package:snownlp/src/data/$name` via [Isolate.resolvePackageUri] and
///   reads from the local file system. Works in any Dart VM context
///   (`dart test`, `dart run`, the package's own CLI, ...).
/// * [FlutterAssetLoader] in `asset_loader_flutter.dart` — pulled in via
///   the opt-in `package:snownlp/snownlp_flutter.dart`; loads the same
///   files from the bundled asset image with `rootBundle.load`. This
///   file imports `package:flutter/services.dart`, which is why it is
///   intentionally NOT referenced by the default public API: pure Dart
///   consumers (`dart test`, the CLI) never see that dependency.
///
/// Consumers don't reach for a concrete loader directly. Instead, they
/// ask [SnowConfig.loadModelBytes] to do the right thing for the
/// currently configured [AssetLoader].
abstract class AssetLoader {
  /// Load the raw bytes of a model file (e.g. `'seg.bin'`).
  Future<Uint8List> loadBytes(String name);
}
