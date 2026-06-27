// Round-trip + invariant tests for the on-disk binary model format.
// Exercises every code path in lib/src/utils/binary_format.dart.

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:snownlp/src/utils/binary_format.dart';
import 'package:test/test.dart';

void main() {
  group('BinaryFormat header', () {
    test('writeFile round-trip', () {
      final payload = Uint8List.fromList([0x10, 0x20, 0x30, 0x40]);
      final file = BinaryFormat.writeFile(BinaryFormat.typeSentiment, payload);
      expect(file.length, 16 + payload.length);
      // Check magic + version + type tag.
      expect(file[0], 0x53); // 'S'
      expect(file[6], 0x70); // 'p'
      expect(file[7], 0x00);
      expect(file[8], 1); // version
      expect(file[9], BinaryFormat.typeSentiment);
      // Payload is at offset 16.
      expect(file.sublist(16), payload);
    });

    test('readPayloadFromFile rejects wrong type tag', () {
      final tmp = Directory.systemTemp.createTempSync('snownlp_bin');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final path = p.join(tmp.path, 'wrong.bin');
      File(path).writeAsBytesSync(
        BinaryFormat.writeFile(0xFF, Uint8List(0)),
      );
      expect(
        () => BinaryFormat.readPayloadFromFile(
          path, BinaryFormat.typeSentiment),
        throwsA(isA<StateError>()),
      );
    });

    test('readPayloadFromFile rejects truncated file', () {
      final tmp = Directory.systemTemp.createTempSync('snownlp_bin');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final path = p.join(tmp.path, 'short.bin');
      File(path).writeAsBytesSync([0x53, 0x4E, 0x4F]); // SN, no header
      expect(
        () => BinaryFormat.readPayloadFromFile(
          path, BinaryFormat.typeSentiment),
        throwsA(isA<StateError>()),
      );
    });

    test('readPayloadFromFile reports missing file clearly', () {
      expect(
        () => BinaryFormat.readPayloadFromFile(
          'lib/src/data/__does_not_exist__.bin',
          BinaryFormat.typeSentiment),
        throwsA(isA<StateError>()),
      );
    });

    test('readPayloadFromBytes validates the header from a buffer', () {
      final payload = Uint8List.fromList([0x10, 0x20, 0x30, 0x40]);
      final file = BinaryFormat.writeFile(BinaryFormat.typeSeg, payload);
      final gz = BinaryFormat.readPayloadFromBytes(
        file,
        BinaryFormat.typeSeg,
        source: '<buffer>',
      );
      expect(gz, payload);
    });

    test('readPayloadFromBytes rejects wrong type tag from a buffer', () {
      final payload = Uint8List.fromList([0x10, 0x20, 0x30, 0x40]);
      final file = BinaryFormat.writeFile(0xFF, payload);
      expect(
        () => BinaryFormat.readPayloadFromBytes(
          file,
          BinaryFormat.typeSeg,
          source: '<buffer>',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Sentiment', () {
    test('round-trips through writeSentiment / readSentiment', () {
      final src = SentimentData(
        total: 981520.0,
        classes: {
          'neg': ClassProb(
            total: 465012.0,
            none: 1,
            d: const {'a': 1, 'bad': 12, '𠮷': 5},
          ),
          'pos': ClassProb(
            total: 516508.0,
            none: 1,
            d: const {'good': 7, '好': 3, '𠮷': 9},
          ),
        },
      );
      final bytes = BinaryFormat.writeSentiment(src);
      final out = BinaryFormat.readSentiment(bytes);
      expect(out.total, src.total);
      expect(out.classes.keys.toList(), ['neg', 'pos']);
      expect(out.classes['neg']!.total, 465012.0);
      expect(out.classes['neg']!.d, const {'a': 1, 'bad': 12, '𠮷': 5});
      expect(out.classes['pos']!.none, 1);
      expect(out.classes['pos']!.d['好'], 3);
    });
  });

  group('Seg', () {
    test('round-trips through writeSeg / readSeg', () {
      final src = SegData(
        l1: 0.13,
        l2: 0.33,
        l3: 0.54,
        status: const ['b', 'm', 'e', 's'],
        uni: BaseProbData(
          total: 100.0,
          none: 0,
          d: const {'一\x01b': 5, '文\x01m': 1},
        ),
        bi: BaseProbData(
          total: 90.0,
          none: 0,
          d: const {'一\x01b\x01文': 2},
        ),
        tri: BaseProbData(
          total: 80.0,
          none: 0,
          d: const {},
        ),
      );
      final bytes = BinaryFormat.writeSeg(src);
      final out = BinaryFormat.readSeg(bytes);
      expect(out.l1, closeTo(0.13, 1e-9));
      expect(out.l2, closeTo(0.33, 1e-9));
      expect(out.l3, closeTo(0.54, 1e-9));
      expect(out.status, ['b', 'e', 'm', 's']); // sorted
      expect(out.uni.d['一\x01b'], 5);
      expect(out.bi.d['一\x01b\x01文'], 2);
      expect(out.tri.d, isEmpty);
    });
  });

  group('Tag', () {
    test('round-trips through writeTag / readTag', () {
      final src = TagData(
        n: 1000,
        l1: 0.1,
        l2: 0.2,
        l3: 0.7,
        status: const ['n', 'v', 'a'],
        wd: BaseProbData(
          total: 100.0,
          none: 1,
          d: const {'n\x01我': 5, 'v\x01你': 2},
        ),
        eos: BaseProbData(
          total: 90.0,
          none: 1,
          d: const {'n\x01EOS': 1},
        ),
        eosd: BaseProbData(
          total: 80.0,
          none: 1,
          d: const {'n': 10, 'v': 5},
        ),
        uni: BaseProbData(
          total: 80.0,
          none: 0,
          d: const {'n': 50},
        ),
        bi: BaseProbData(
          total: 70.0,
          none: 0,
          d: const {'n\x01v': 3},
        ),
        tri: BaseProbData(
          total: 60.0,
          none: 0,
          d: const {'n\x01v\x01n': 1},
        ),
        word: const {'我': ['n'], '喜欢': ['v']},
        trans: const {'n\x01v\x01n': -2.5},
      );
      final bytes = BinaryFormat.writeTag(src);
      final out = BinaryFormat.readTag(bytes);
      expect(out.n, 1000);
      expect(out.status, ['a', 'n', 'v']); // sorted
      expect(out.wd.d['n\x01我'], 5);
      expect(out.eosd.d['n'], 10);
      expect(out.trans['n\x01v\x01n'], closeTo(-2.5, 1e-9));
      expect(out.word['我'], ['n']);
    });
  });

  group('Stopwords / Zh2Hans / Pinyin', () {
    test('stopwords round-trip', () {
      final src = ['的', '了', '是'];
      final bytes = BinaryFormat.writeStopwords(src);
      final out = BinaryFormat.readStopwords(bytes);
      // Sorted by the same comparison as `String.compareTo`.
      expect(out, ['了', '是', '的']);
    });

    test('zh2hans round-trip', () {
      final src = {'繁': '繁', '體': '体', '龜': '龟'};
      final bytes = BinaryFormat.writeZh2Hans(src);
      final out = BinaryFormat.readZh2Hans(bytes);
      expect(out, src);
    });

    test('pinyin round-trip', () {
      final src = [
        PinyinEntry(hanzi: '中', pinyin: const ['zhong', 'zhong4']),
        PinyinEntry(hanzi: '文', pinyin: const ['wen']),
      ];
      final bytes = BinaryFormat.writePinyin(src);
      final out = BinaryFormat.readPinyin(bytes);
      expect(out.length, 2);
      expect(out[0].hanzi, '中');
      expect(out[0].pinyin, ['zhong', 'zhong4']);
      expect(out[1].hanzi, '文');
    });
  });

  group('Determinism', () {
    test('payload bytes are deterministic across re-encodes', () {
      final src = SentimentData(
        total: 1.0,
        classes: {
          'a': ClassProb(total: 0.5, none: 1, d: const {'k': 1}),
        },
      );
      final a = BinaryFormat.writeSentiment(src);
      final b = BinaryFormat.writeSentiment(src);
      // writeSentiment is called twice with the same input — the gzipped
      // bytes (including the mtime field) will differ. The decompressed
      // payload must be identical.
      final da = GZipCodec().decode(a);
      final db = GZipCodec().decode(b);
      expect(da, db);
    });
  });
}
