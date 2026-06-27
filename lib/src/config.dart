import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'utils/asset_loader.dart';
import 'utils/asset_loader_io.dart';

/// Configuration for asset lookup.
///
/// Two parallel resolution paths are exposed:
///
/// * The classic [assetRoot] / [modelPath] helpers resolve a filename
///   to an absolute on-disk path. Used internally for legacy sync
///   callers and by tests that build their own temporary fixtures.
/// * The [assetLoader] / [loadModelBytes] pair is the preferred path
///   for production code. It uses an [AssetLoader] strategy object,
///   which lets the same call site work in both a Dart VM (via the
///   default [IoAssetLoader]) and a Flutter app (via
///   `FlutterAssetLoader` registered by `package:snownlp/snownlp_flutter.dart`).
class SnowConfig {
  SnowConfig({
    String? assetRoot,
    AssetLoader? assetLoader,
  })  : _assetRootOverride = assetRoot,
        _assetLoader = assetLoader ?? IoAssetLoader();

  static final SnowConfig _default = SnowConfig();
  static SnowConfig get instance => _default;

  String? _assetRootOverride;
  AssetLoader _assetLoader;

  /// Resolved path to the directory containing `sentiment.bin`, `seg.bin`,
  /// etc. Walks up from `Platform.script` until it finds a `pubspec.yaml`,
  /// falling back to a CWD-relative lookup.
  String get assetRoot {
    final override = _assetRootOverride;
    if (override != null) return override;
    return _resolveAssetRoot();
  }

  /// Set a custom root (e.g. when hosting models in a different location).
  set assetRoot(String path) {
    _default._assetRootOverride = path;
  }

  /// Resolve a model filename (e.g. `'sentiment.bin'`) to an absolute
  /// path relative to the configured [assetRoot]. Prefer [loadModelBytes]
  /// for production code; this helper remains for the sync
  /// [BinaryFormat.readPayloadFromFile] test path and for any caller
  /// that genuinely needs an absolute path on disk.
  String modelPath(String filename) => p.join(assetRoot, filename);

  /// Strategy used by [loadModelBytes]. Defaults to [IoAssetLoader] so
  /// pure Dart callers (CLI, tests) work out of the box. Flutter apps
  /// override this with `FlutterAssetLoader` via
  /// `package:snownlp/snownlp_flutter.dart`.
  AssetLoader get assetLoader => _assetLoader;
  set assetLoader(AssetLoader loader) {
    _default._assetLoader = loader;
  }

  /// Read a model's raw bytes via the configured [assetLoader]. This is
  /// the entry point every model consumer should reach for.
  Future<Uint8List> loadModelBytes(String name) => _assetLoader.loadBytes(name);

  static String _resolveAssetRoot() {
    // Prefer the current working directory; `dart run` and `dart test`
    // both run from the package root by convention.
    final cwdPubspec = File(p.join(Directory.current.path, 'pubspec.yaml'));
    if (cwdPubspec.existsSync()) {
      final root = _readName(cwdPubspec);
      if (root == 'snownlp') {
        return p.join(Directory.current.path, 'lib', 'src', 'data');
      }
    }
    // Fallback: walk up from Platform.script. This typically resolves to
    // the Dart SDK, so the package-name guard below skips it.
    for (final start in <String>[
      Platform.script.toFilePath(),
      Platform.resolvedExecutable,
    ]) {
      final found = _walkUp(start, 'snownlp');
      if (found != null) return p.join(found, 'lib', 'src', 'data');
    }
    return p.join(Directory.current.path, 'lib', 'src', 'data');
  }

  static String? _readName(File pubspec) {
    try {
      final content = pubspec.readAsStringSync();
      for (final line in content.split('\n')) {
        final m = RegExp(r'^name:\s*(\S+)').firstMatch(line);
        if (m != null) return m.group(1);
      }
    } catch (_) {}
    return null;
  }

  static String? _walkUp(String startPath, String packageName) {
    Directory dir;
    if (File(startPath).existsSync()) {
      dir = File(startPath).parent;
    } else if (Directory(startPath).existsSync()) {
      dir = Directory(startPath);
    } else {
      return null;
    }
    while (true) {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync() && _readName(pubspec) == packageName) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
  }
}
