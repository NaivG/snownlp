import 'package:snownlp/snownlp.dart';
import 'package:test/test.dart';

void main() {
  group('SnowNLP facade', () {
    test('basic sentence round-trip', () async {
      final s = SnowNLP('今天天气真好,我们去公园散步。');
      expect(await s.words, ['今天', '天气', '真', '好', ',', '我们', '去', '公园', '散步', '。']);
      expect(s.sentences, ['今天天气真好,我们去公园散步']);
      expect(await s.han, '今天天气真好,我们去公园散步。');
      expect(await s.pinyin, containsAll(<String>['jin', 'tian']));
    });

    test('sentiments is a probability in [0, 1]', () async {
      final s = SnowNLP('这是一段文字');
      expect(await s.sentiments, inInclusiveRange(0.0, 1.0));
    });

    test('tags returns one entry per token', () async {
      final s = SnowNLP('我喜欢这本书');
      final pairs = await s.tags;
      final words = await s.words;
      expect(pairs.length, words.length);
      expect(pairs.first.$1, '我');
    });

    test('sim returns one score (BM25 vs. the original doc)', () {
      final s = SnowNLP('今天天气真好');
      final scores = s.sim(['明天天气也很好']);
      expect(scores.length, 1);
    });

    test('summary returns up to limit sentences from the doc', () async {
      final doc = '今天天气真好,我们去公园。路上遇到了老朋友,他送了我们一束鲜花。'
          '然后我们一起去吃了午餐,味道非常好。';
      final s = SnowNLP(doc);
      final summary = await s.summary(limit: 2);
      expect(summary.length, 2);
      for (final sentence in summary) {
        expect(doc.contains(sentence), isTrue);
      }
    });

    test('keywords returns up to limit words from the doc', () async {
      final doc = '今天天气真好,我们去公园。路上遇到了老朋友,他送了我们一束鲜花。'
          '然后我们一起去吃了午餐,味道非常好。';
      final s = SnowNLP(doc);
      final kw = await s.keywords(limit: 3);
      expect(kw.length, 3);
    });
  });
}
