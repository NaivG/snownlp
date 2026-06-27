import 'package:snownlp/snownlp.dart';
import 'package:test/test.dart';

const _doc = '今天天气真好,我们去公园散步。路上遇到了老朋友,他送了我们一束鲜花。'
    '然后我们一起去吃了午餐,味道非常好。下午我们去了博物馆,看到了很多珍贵的文物。'
    '傍晚时分,我们坐在湖边看夕阳,心情非常愉快。晚上我们回到家,准备休息。';

void main() {
  group('TextRank (sentence)', () {
    test('summary returns up to limit sentences from the original doc',
        () async {
      final s = SnowNLP(_doc);
      final out = await s.summary(limit: 3);
      expect(out.length, 3);
      for (final sentence in out) {
        expect(_doc.contains(sentence), isTrue);
      }
    });

    test('limit=1 returns the top-ranked sentence only', () async {
      final s = SnowNLP(_doc);
      final out = await s.summary(limit: 1);
      expect(out.length, 1);
    });
  });

  group('KeywordTextRank', () {
    test('keywords returns up to limit words from the doc', () async {
      final s = SnowNLP(_doc);
      final kw = await s.keywords(limit: 5);
      expect(kw.length, 5);
      // Some of the top keywords from snownlp's training data appear here.
      expect(kw, contains('去'));
    });

    test('merge=true concatenates bigram keywords', () async {
      final s = SnowNLP(_doc);
      final merged = await s.keywords(limit: 5, merge: true);
      expect(merged.length, lessThanOrEqualTo(5));
    });

    test('SimpleMerge merges repeated bigrams', () {
      // '首都北京' is found in the doc as the substring after '首' (which
      // itself follows '的'); snownlp's merge links '首都' -> '北京'.
      final m = SimpleMerge('北京是中国的首都北京有悠久历史', ['北京', '首都']);
      expect(m.merge(), ['首都北京']);
    });
  });
}
