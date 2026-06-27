import 'dart:convert';
import 'dart:io';

import 'package:snownlp/snownlp.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final golden = json.decode(
    File(p.join('test', 'golden', 'tag.json')).readAsStringSync(),
  ) as Map<String, dynamic>;

  for (final entry in golden.entries) {
    final words = entry.key.split('|');
    final tags = (entry.value as List).cast<String>();
    test('tag: ${entry.key}', () async {
      expect(await tag(words), tags);
    });
  }

  test('tag and seg agree on a known sentence', () async {
    final words = await seg('这家店很好吃');
    final tags = await tag(words);
    expect(words, ['这家', '店', '很', '好吃']);
    expect(tags, ['r', 'n', 'd', 'a']);
  });
}
