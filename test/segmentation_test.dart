import 'dart:convert';
import 'dart:io';

import 'package:snownlp/snownlp.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('seg', () {
    final golden = json.decode(
      File(p.join('test', 'golden', 'seg.json')).readAsStringSync(),
    ) as Map<String, dynamic>;

    for (final entry in golden.entries) {
      test('segments: ${entry.key}', () async {
        expect(await seg(entry.key), entry.value);
      });
    }

    test('passes non-Chinese runs through unchanged (whitespace split)',
        () async {
      expect(await seg('hello world'), ['hello', 'world']);
    });

    test('preserves punctuation around Chinese', () async {
      expect(
        await seg('今天天气真好。我们去公园。'),
        ['今天', '天气', '真', '好', '。', '我们', '去', '公园', '。'],
      );
    });
  });
}
