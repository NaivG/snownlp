import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves the project root (where `pubspec.yaml` lives) from the
/// current working directory. Tests always run from the package root,
/// but walk up a couple of levels to be robust to `dart test` variants.
String projectRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 4; i++) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('Could not find project root from ${Directory.current.path}');
}

/// Read a golden JSON file by name (e.g. `'sentiment'` -> `test/golden/sentiment.json`).
Map<String, dynamic> loadGolden(String name) {
  final file = File(p.join(projectRoot(), 'test', 'golden', '$name.json'));
  if (!file.existsSync()) {
    throw StateError('Missing golden file: ${file.path}');
  }
  return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Load a text fixture under `test/fixtures/`.
String loadFixture(String name) {
  final file = File(p.join(projectRoot(), 'test', 'fixtures', name));
  return file.readAsStringSync();
}