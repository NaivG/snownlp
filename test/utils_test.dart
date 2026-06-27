import 'package:snownlp/snownlp.dart';
import 'package:test/test.dart';

void main() {
  group('Trie', () {
    test('insert + find returns longest match', () {
      final t = Trie();
      t.insert(['繁', '體'], '繁_体');
      t.insert(['繁', '體', '字'], '繁体字');
      expect(t.find('繁體'), isNotNull);
      expect(t.find('繁體')!.matched, '繁體');
      expect(t.find('繁體')!.value, '繁_体');
      expect(t.find('繁體字')!.matched, '繁體字');
      expect(t.find('繁體字')!.value, '繁体字');
    });

    test('find returns null when no match', () {
      final t = Trie();
      t.insert(['繁', '體'], '繁_体');
      expect(t.find('簡'), isNull);
    });

    test('translate substitutes longest matches and passes the rest through',
        () {
      final t = Trie();
      t.insert(['繁', '體'], '繁体');
      t.insert(['字'], '字');
      expect(t.translate('繁體中文字').join(), '繁体中文字');
    });

    test('translate drops unmatched when withNotFound is false', () {
      final t = Trie();
      t.insert(['繁', '體'], '繁体');
      expect(t.translate('繁體x', withNotFound: false).join(), '繁体');
    });
  });

  group('NormalProb', () {
    test('freq on missing key returns 0', () {
      final p = NormalProb();
      p.add('a', 5);
      expect(p.freq('a'), closeTo(1.0, 1e-9));
      expect(p.freq('b'), 0);
    });
  });

  group('AddOneProb', () {
    test('none defaults to 1 (Laplace smoothing)', () {
      final p = AddOneProb();
      expect(p.none, 1);
      p.add('a', 1);
      // freq(a) = 2 / 2 = 1.0 (the key was seen once, then pre-seeded with 1)
      expect(p.freq('a'), closeTo(1.0, 1e-9));
      // freq(zzz) = none / total = 1 / 2 = 0.5
      expect(p.freq('zzz'), closeTo(0.5, 1e-9));
    });
  });
}