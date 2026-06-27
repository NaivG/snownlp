import 'package:snownlp/snownlp.dart';
import 'package:test/test.dart';

void main() {
  group('BM25', () {
    test('init computes df/idf and f', () {
      final b = BM25([
        ['a', 'b', 'c'],
        ['a', 'd', 'e'],
      ]);
      expect(b.D, 2);
      expect(b.f[0], {'a': 1, 'b': 1, 'c': 1});
      expect(b.f[1], {'a': 1, 'd': 1, 'e': 1});
      // 'a' appears in 2 of 2 docs, so idf = log(0.5/2.5) < 0
      expect(b.idf['a']! < 0, isTrue);
      // 'b' appears in 1 of 2 docs, so idf = log(1.5/1.5) = 0
      expect(b.idf['b']!, 0);
      // 'c' appears in 1 of 2 docs too
      expect(b.idf['c']!, 0);
    });

    test('sim returns 0 for an empty query', () {
      final b = BM25([['a', 'b']]);
      expect(b.simall(const []).first, 0);
    });

    test('simall matches sim for every index', () {
      final b = BM25([
        ['a', 'b', 'c'],
        ['a', 'd', 'e'],
        ['b', 'd', 'f'],
      ]);
      final all = b.simall(['a']);
      expect(all.length, 3);
      for (var i = 0; i < 3; i++) {
        expect(all[i], b.sim(['a'], i));
      }
    });
  });
}