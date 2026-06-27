import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'asset_loader.dart';

/// [AssetLoader] backed by the Dart VM's file system.
///
/// Resolution order:
///
/// 1. `package:snownlp/src/data/$name` is resolved via
///    [Isolate.resolvePackageUri]. This works in any Dart VM context
///    (the package's CLI, `dart test`, `dart run`, ...) where the
///    `package:` URI machinery is wired up to `.pub-cache` or the local
///    source checkout.
/// 2. If the host VM does not support `Isolate.resolvePackageUri` (the
///    Flutter VM, including `flutter test`), the loader falls back to a
///    path-based search rooted at [Platform.script]: it walks up the
///    directory tree until it finds a `pubspec.yaml` named `snownlp`,
///    then reads `<that>/lib/src/data/$name`. The same source tree is
///    used by the Flutter test harness — the assets are simply not
///    bundled into a `rootBundle` until an app does so via
///    `package:snownlp/snownlp_flutter.dart`.
class IoAssetLoader implements AssetLoader {
  /// Creates an [IoAssetLoader] anchored at the given `package:` prefix.
  /// The default ([defaultPrefix]) targets this package's data dir.
  IoAssetLoader({
    this.packagePrefix = defaultPrefix,
    this.packageName = defaultPackageName,
  });

  /// `package:snownlp/src/data/` — the canonical asset root in source.
  static const String defaultPrefix = 'package:snownlp/src/data/';

  /// The package name to look for when falling back to a path-based
  /// resolution. Defaults to [defaultPackageName].
  static const String defaultPackageName = 'snownlp';

  /// Override of [defaultPrefix]; useful for forks or vendored copies
  /// of the package that ship under a different name.
  final String packagePrefix;

  /// Override of [defaultPackageName]; same use case as
  /// [packagePrefix].
  final String packageName;

  @override
  Future<Uint8List> loadBytes(String name) async {
    // 1) Preferred: resolve via the package: URI.
    try {
      final pkgUri = Uri.parse('$packagePrefix$name');
      final resolved = await Isolate.resolvePackageUri(pkgUri);
      if (resolved != null) {
        final file = File.fromUri(resolved);
        if (await file.exists()) {
          return file.readAsBytes();
        }
      }
    } on UnsupportedError {
      // Flutter VM doesn't implement Isolate.resolvePackageUri; fall
      // through to the path-based search below.
    }

    // 2) Fallback: walk up from Platform.script to find the package root.
    final byPath = _findByPath(name);
    if (byPath != null) return byPath;

    throw StateError(
      'snownlp: cannot resolve "$name" via "$packagePrefix". '
      'Make sure "$name" is shipped under '
      '"${packagePrefix.replaceFirst('package:', '')}" in the package '
      'source.',
    );
  }

  Future<Uint8List>? _findByPath(String name) {
    final candidates = <String>[
      Platform.script.toFilePath(),
      Platform.resolvedExecutable,
      Platform.executable,
    ];
    // Also seed with the current working directory: in `flutter test`
    // `Platform.script` may resolve to a non-existent `main.dart` inside
    // CWD, so we want CWD itself to count as a valid starting point.
    if (!candidates.contains(Directory.current.path)) {
      candidates.add(Directory.current.path);
    }
    for (final start in candidates) {
      final root = _walkUp(start, packageName);
      if (root == null) continue;
      final file = File(p.join(root, 'lib', 'src', 'data', name));
      if (file.existsSync()) {
        return file.readAsBytes();
      }
    }
    return null;
  }

  static String? _walkUp(String startPath, String packageName) {
    // If the seed path doesn't exist as a file or directory, treat its
    // parent directory as the starting point. This is needed because
    // `Platform.script` may point at a synthetic `main.dart` that the
    // test runner never wrote to disk.
    Directory dir;
    if (File(startPath).existsSync()) {
      dir = File(startPath).parent;
    } else if (Directory(startPath).existsSync()) {
      dir = Directory(startPath);
    } else {
      final parent = p.dirname(startPath);
      if (parent == startPath) return null;
      dir = Directory(parent);
      if (!dir.existsSync()) return null;
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
}
