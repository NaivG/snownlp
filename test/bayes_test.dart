import 'package:snownlp/snownlp.dart';
import 'package:test/test.dart';

void main() {
  group('Bayes (hand-built)', () {
    test('train + classify basic 2-class problem', () {
      final b = Bayes();
      b.train([
        (['cat', 'dog', 'cat'], 'A'),
        (['dog', 'dog', 'fish'], 'A'),
        (['fish', 'whale', 'shark'], 'B'),
        (['shark', 'whale', 'fish'], 'B'),
      ]);
      final r = b.classify(['fish']);
      expect(r.label, anyOf('A', 'B'));
      expect(r.probability, greaterThan(0.0));
      expect(r.probability, lessThanOrEqualTo(1.0));
    });

    test('probabilities sum to 1 across classes (each class)', () {
      final b = Bayes();
      b.train([
        (['a', 'b'], 'X'),
        (['c', 'd'], 'Y'),
      ]);
      // For each class label, the probability is the normalised softmax
      // of its log-posterior. We just sanity-check ranges here.
      final r = b.classify(['a']);
      expect(r.probability, greaterThan(0.0));
      expect(r.probability, lessThan(1.0));
    });

    test('classify is overflow-safe on extreme log scores', () {
      final b = Bayes();
      // One class has many tokens, the other has none -> huge log diff.
      b.train([
        (List.generate(10000, (_) => 'hot'), 'hot'),
        (['cold'], 'cold'),
      ]);
      final r = b.classify(List.generate(10000, (_) => 'hot'));
      expect(r.label, 'hot');
      expect(r.probability.isFinite, isTrue);
      expect(r.probability, greaterThan(0.5));
    });

    test('laplace smoothing: unseen word does not crash', () {
      final b = Bayes();
      b.train([
        (['a'], 'X'),
        (['b'], 'Y'),
      ]);
      // 'zzz' was never seen; AddOneProb returns 1/total for it.
      expect(() => b.classify(['zzz']), returnsNormally);
    });

    test('matches Python reference formula on a tiny case', () {
      // Manual computation: build a tiny model and verify the math.
      // P(A|hot) proportional to P(hot|A) * P(A)
      //  with Laplace smoothing.
      final b = Bayes();
      b.train([
        (['hot', 'hot'], 'A'),
        (['cold'], 'B'),
      ]);
      // hot seen twice in A, cold once in B. With AddOneProb:
      //  - d['A'].d = {'hot': 3}, d['A'].total = 4
      //  - d['B'].d = {'cold': 2}, d['B'].total = 3
      //  - Bayes.total = 7
      // classify(['hot']):
      //   log P(hot|A) = log(3/4), log P(A) = log(4/7)
      //   log P(hot|B) = log(1/3) (none=1, total=3)
      //   log P(B) = log(3/7)
      //   logA = log(3/4) + log(4/7)
      //   logB = log(1/3) + log(3/7) = log(1/7)
      //   logA - logB = log(3/4 * 4/7) - log(1/7) = log(3/7) - log(1/7) = log(3)
      //   prob(A) = 1 / (1 + exp(logB - logA)) = 1 / (1 + 1/3) = 3/4
      final r = b.classify(['hot']);
      expect(r.label, 'A');
      expect(r.probability, closeTo(3 / 4, 1e-9));
    });
  });
}