import 'dart:convert';
import 'dart:io';

import 'package:snownlp/snownlp.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('getSentences', () {
    test('splits on Chinese sentence punctuation', () {
      expect(
        getSentences('今天天气真好。我们去公园。'),
        ['今天天气真好', '我们去公园'],
      );
    });

    test('splits on line breaks as well', () {
      expect(
        getSentences('第一句。\n第二句！\r\n第三句？'),
        ['第一句', '第二句', '第三句'],
      );
    });

    test('returns empty for empty input', () {
      expect(getSentences(''), isEmpty);
      expect(getSentences('   '), isEmpty);
    });

    test('preserves interior punctuation within a sentence', () {
      expect(getSentences('你好,世界！再见。'), ['你好,世界', '再见']);
    });
  });

  group('stopwords', () {
    test('filters known stopwords', () async {
      final words = ['我', '的', '猫', '在', '吃', '鱼'];
      final sw = await stopwords;
      expect(sw.filterStop(words), ['猫', '吃', '鱼']);
    });

    test('a reasonable size', () async {
      final sw = await stopwords;
      expect(sw.length, greaterThan(500));
    });
  });

  group('reZh', () {
    test('matches CJK runs and splitKeeping preserves non-CJK', () {
      final parts = splitKeeping(reZh, 'hello 中文 world');
      expect(parts, ['hello ', '中文', ' world']);
    });
  });

  group('zh2hans', () {
    final golden = json.decode(
      File(p.join('test', 'golden', 'zh2hans.json')).readAsStringSync(),
    ) as Map<String, dynamic>;

    for (final entry in golden.entries) {
      test('zh2hans: ${entry.key}', () async {
        expect(await zh2hans(entry.key), entry.value);
      });
    }

    test('leaves already-simplified text unchanged', () async {
      expect(await zh2hans('简体中文'), '简体中文');
    });
  });

  group('getPinyin', () {
    final golden = json.decode(
      File(p.join('test', 'golden', 'pinyin.json')).readAsStringSync(),
    ) as Map<String, dynamic>;

    for (final entry in golden.entries) {
      test('pinyin: ${entry.key}', () async {
        expect(await getPinyin(entry.key), entry.value);
      });
    }

    test('passes non-Chinese runs through', () async {
      expect(await getPinyin('hello world'), ['hello', 'world']);
    });
  });
}
