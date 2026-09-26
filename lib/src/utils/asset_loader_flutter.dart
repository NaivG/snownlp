import 'package:flutter/services.dart';

import 'asset_loader.dart';

/// [AssetLoader] backed by a Flutter app's asset bundle.
///
/// This is the loader Flutter apps register via
/// `package:snownlp/snownlp_flutter.dart`. It reads from the bundled
/// `packages/snownlp/lib/src/data/$name` asset (the asset key Flutter
/// assigns to a file declared in the package's own `flutter.assets`
/// list).
///
/// Note: this file imports `package:flutter/services.dart`. That is the
/// whole point of the opt-in entry point: pure-Dart consumers
/// (`dart test`, the CLI) never reach this file and so never pull the
/// Flutter SDK in. Flutter apps opt in explicitly with
/// `useFlutterAssetLoader()`.
class FlutterAssetLoader implements AssetLoader {
  /// Creates a [FlutterAssetLoader] anchored at the given asset prefix.
  /// The default ([defaultAssetPrefix]) targets the standard key
  /// Flutter assigns to this package's `lib/src/data/` assets.
  FlutterAssetLoader({this.assetPrefix = defaultAssetPrefix});

  /// `packages/snownlp/lib/src/data/` — the asset key Flutter derives for
  /// files declared under the package's `lib/src/data/` directory.
  static const String defaultAssetPrefix = 'packages/snownlp/lib/src/data/';

  /// Override of [defaultAssetPrefix]; useful for forks or vendored
  /// copies of the package that ship under a different name.
  final String assetPrefix;

  @override
  Future<Uint8List> loadBytes(String name) async {
    final data = await rootBundle.load('$assetPrefix$name');
    return data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
  }
}
