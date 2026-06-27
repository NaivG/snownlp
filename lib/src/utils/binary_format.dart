import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Compact binary codecs for the snownlp model files shipped under
/// `lib/src/data/`. See `tool/README.md` for the wire-format spec.
///
/// Each `.bin` file has a 16-byte header followed by a gzipped payload:
///
/// ```
/// [8B magic "SNOWnlp\0"][1B version][1B file-type tag]
/// [2B reserved (0)][4B gzipped-payload length LE]
/// ```
///
/// File-type tags:
/// * `'s'`  sentiment  — `readSentiment`
/// * `'S'`  seg        — `readSeg`
/// * `'t'`  tag        — `readTag`
/// * `'p'`  pinyin     — `readPinyin`
/// * `'w'`  stopwords  — `readStopwords`
/// * `'h'`  zh2hans    — `readZh2Hans`
///
/// Within each payload:
/// * 16-bit and 32-bit integers are little-endian unsigned.
/// * Floats are IEEE-754 binary64 little-endian.
/// * Strings are length-prefixed (`u16` length, then UTF-8 bytes).
/// * Map entries are sorted by key for deterministic encoding.
class BinaryFormat {
  static const int formatVersion = 1;

  static const List<int> magic = [0x53, 0x4E, 0x4F, 0x57, 0x6E, 0x6C, 0x70, 0x00];

  static const int typeSentiment = 0x73; // 's'
  static const int typeSeg = 0x53; // 'S'
  static const int typeTag = 0x74; // 't'
  static const int typePinyin = 0x70; // 'p'
  static const int typeStopwords = 0x77; // 'w'
  static const int typeZh2Hans = 0x68; // 'h'

  // ---------------------------------------------------------------------------
  // File-level helpers
  // ---------------------------------------------------------------------------

  /// Validates the 16-byte header of [bytes] against [expectedType] and
  /// returns the gzipped payload. [source] is a human-readable name used
  /// purely for error messages (a file path, an asset key, etc.).
  static Uint8List readPayloadFromBytes(
    Uint8List bytes,
    int expectedType, {
    String? source,
  }) {
    final label = source ?? '<bytes>';
    if (bytes.length < 16) {
      throw StateError('snownlp: $label too short to be a .bin file');
    }
    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes, 16);
    for (var i = 0; i < magic.length; i++) {
      if (view.getUint8(i) != magic[i]) {
        throw StateError('snownlp: bad magic bytes in $label');
      }
    }
    final version = view.getUint8(8);
    if (version != formatVersion) {
      throw StateError(
        'snownlp: $label format version=$version, expected $formatVersion',
      );
    }
    final tag = view.getUint8(9);
    if (tag != expectedType) {
      throw StateError(
        'snownlp: $label has type tag ${String.fromCharCode(tag)} '
        '(${tag.toRadixString(16)}), '
        'expected ${String.fromCharCode(expectedType)} '
        '(${expectedType.toRadixString(16)})',
      );
    }
    return bytes.sublist(16);
  }

  /// Reads a `.bin` file from disk, validates the 16-byte header against
  /// [expectedType], and returns the gzipped payload bytes.
  ///
  /// This is the sync path; production code reaches for
  /// `SnowConfig.instance.loadModelBytes(name)` (which is async) and
  /// then [readPayloadFromBytes]. This entry point stays for tests that
  /// build their own temp fixtures and want to skip the loader layer.
  static Uint8List readPayloadFromFile(String path, int expectedType) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError(
        'snownlp: missing model file at "$path". '
        'Run `python tool/export_models.py` from the package root.',
      );
    }
    return readPayloadFromBytes(
      file.readAsBytesSync(),
      expectedType,
      source: path,
    );
  }

  /// Reads + decodes a `.bin` file. The generic counterpart for tests that
  /// build a model in memory and re-serialise it.
  ///
  /// [payloadBytes] must already be the gzipped payload (i.e. the
  /// output of any `writeXxx` method). This function only prepends the
  /// 16-byte header.
  static Uint8List writeFile(int fileType, Uint8List payloadBytes) {
    final out = Uint8List(16 + payloadBytes.length);
    out.setRange(0, magic.length, magic);
    out[8] = formatVersion;
    out[9] = fileType;
    out[10] = 0;
    out[11] = 0;
    ByteData.view(out.buffer, out.offsetInBytes, 16)
        .setUint32(12, payloadBytes.length, Endian.little);
    out.setRange(16, 16 + payloadBytes.length, payloadBytes);
    return out;
  }

  // ---------------------------------------------------------------------------
  // Sentiment (.bin tag = 's')
  // ---------------------------------------------------------------------------

  /// Schema:
  ///   total: f64
  ///   classCount: u16
  ///   for each class (sorted by name):
  ///     className: u16 len + UTF-8
  ///     probTotal: f64
  ///     none: u8
  ///     dLen: u32
  ///     for each entry (sorted by key):
  ///       key: u16 len + UTF-8
  ///       count: u32
  static SentimentData readSentiment(Uint8List gzipped) {
    final view = _unzip(gzipped);
    var offset = 0;
    final total = view.getFloat64(offset, Endian.little);
    offset += 8;
    final classCount = view.getUint16(offset, Endian.little);
    offset += 2;
    final classes = <String, ClassProb>{};
    for (var i = 0; i < classCount; i++) {
      final nameLen = view.getUint16(offset, Endian.little);
      offset += 2;
      final name = _readUtf8(view, offset, nameLen);
      offset += nameLen;
      final probTotal = view.getFloat64(offset, Endian.little);
      offset += 8;
      final none = view.getUint8(offset);
      offset += 1;
      final pair = _readStringIntMap(view, offset);
      offset = pair.$2;
      classes[name] = ClassProb(total: probTotal, none: none, d: pair.$1);
    }
    return SentimentData(total: total, classes: classes);
  }

  static Uint8List writeSentiment(SentimentData data) {
    final entries = data.classes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final buf = BytesBuilder()
      ..add(_f64(data.total))
      ..add(_u16(entries.length));
    for (final e in entries) {
      buf
        ..add(_str(e.key))
        ..add(_f64(e.value.total))
        ..add(_u8(e.value.none));
      _writeStringIntMap(buf, e.value.d);
    }
    return _gzip(buf.toBytes());
  }

  // ---------------------------------------------------------------------------
  // Seg (.bin tag = 'S')
  // ---------------------------------------------------------------------------

  /// Schema:
  ///   l1, l2, l3: f64
  ///   status: u16 count, then (u16 len, UTF-8) per tag (sorted)
  ///   3 prob tables (uni, bi, tri in this order):
  ///     total: f64, none: u8
  ///     dLen: u32, then (u16 len, UTF-8, u32 count) entries (sorted)
  static SegData readSeg(Uint8List gzipped) {
    final view = _unzip(gzipped);
    var offset = 0;
    final l1 = view.getFloat64(offset, Endian.little);
    offset += 8;
    final l2 = view.getFloat64(offset, Endian.little);
    offset += 8;
    final l3 = view.getFloat64(offset, Endian.little);
    offset += 8;
    final statusCount = view.getUint16(offset, Endian.little);
    offset += 2;
    final status = <String>[];
    for (var i = 0; i < statusCount; i++) {
      final len = view.getUint16(offset, Endian.little);
      offset += 2;
      status.add(_readUtf8(view, offset, len));
      offset += len;
    }
    final uni = _readBaseProbInt(view, offset);
    offset = uni.$2;
    final bi = _readBaseProbInt(view, offset);
    offset = bi.$2;
    final tri = _readBaseProbInt(view, offset);
    return SegData(
      l1: l1,
      l2: l2,
      l3: l3,
      status: status,
      uni: uni.$1,
      bi: bi.$1,
      tri: tri.$1,
    );
  }

  static Uint8List writeSeg(SegData data) {
    final buf = BytesBuilder()
      ..add(_f64(data.l1))
      ..add(_f64(data.l2))
      ..add(_f64(data.l3));
    final status = [...data.status]..sort();
    buf.add(_u16(status.length));
    for (final s in status) {
      buf.add(_str(s));
    }
    _writeBaseProbInt(buf, data.uni);
    _writeBaseProbInt(buf, data.bi);
    _writeBaseProbInt(buf, data.tri);
    return _gzip(buf.toBytes());
  }

  // ---------------------------------------------------------------------------
  // Tag (.bin tag = 't')
  // ---------------------------------------------------------------------------

  /// Schema:
  ///   N: i32
  ///   l1, l2, l3: f64
  ///   status: u16 count, then (u16 len, UTF-8) per tag (sorted)
  ///   6 prob tables (wd, eos, eosd, uni, bi, tri in this order):
  ///     total: f64, none: u8, dLen: u32
  ///     for each entry (sorted by key): u16 len + UTF-8 + u32 count
  ///   word map:
  ///     wordLen: u32
  ///     for each word (sorted by key):
  ///       key: u16 len + UTF-8
  ///       valuesLen: u16
  ///       for each value: u16 len + UTF-8
  ///   trans map:
  ///     transLen: u32
  ///     for each (sorted by key): u16 len + UTF-8 + f64 value
  static TagData readTag(Uint8List gzipped) {
    final view = _unzip(gzipped);
    var offset = 0;
    final n = view.getInt32(offset, Endian.little);
    offset += 4;
    final l1 = view.getFloat64(offset, Endian.little);
    offset += 8;
    final l2 = view.getFloat64(offset, Endian.little);
    offset += 8;
    final l3 = view.getFloat64(offset, Endian.little);
    offset += 8;
    final statusCount = view.getUint16(offset, Endian.little);
    offset += 2;
    final status = <String>[];
    for (var i = 0; i < statusCount; i++) {
      final len = view.getUint16(offset, Endian.little);
      offset += 2;
      status.add(_readUtf8(view, offset, len));
      offset += len;
    }
    final wd = _readBaseProbInt(view, offset);
    offset = wd.$2;
    final eos = _readBaseProbInt(view, offset);
    offset = eos.$2;
    final eosd = _readBaseProbInt(view, offset);
    offset = eosd.$2;
    final uni = _readBaseProbInt(view, offset);
    offset = uni.$2;
    final bi = _readBaseProbInt(view, offset);
    offset = bi.$2;
    final tri = _readBaseProbInt(view, offset);
    offset = tri.$2;
    final wordLen = view.getUint32(offset, Endian.little);
    offset += 4;
    final word = <String, List<String>>{};
    for (var i = 0; i < wordLen; i++) {
      final kLen = view.getUint16(offset, Endian.little);
      offset += 2;
      final k = _readUtf8(view, offset, kLen);
      offset += kLen;
      final vCount = view.getUint16(offset, Endian.little);
      offset += 2;
      final v = <String>[];
      for (var j = 0; j < vCount; j++) {
        final sLen = view.getUint16(offset, Endian.little);
        offset += 2;
        v.add(_readUtf8(view, offset, sLen));
        offset += sLen;
      }
      word[k] = v;
    }
    final transLen = view.getUint32(offset, Endian.little);
    offset += 4;
    final trans = <String, double>{};
    for (var i = 0; i < transLen; i++) {
      final kLen = view.getUint16(offset, Endian.little);
      offset += 2;
      final k = _readUtf8(view, offset, kLen);
      offset += kLen;
      final v = view.getFloat64(offset, Endian.little);
      offset += 8;
      trans[k] = v;
    }
    return TagData(
      n: n,
      l1: l1,
      l2: l2,
      l3: l3,
      status: status,
      wd: wd.$1,
      eos: eos.$1,
      eosd: eosd.$1,
      uni: uni.$1,
      bi: bi.$1,
      tri: tri.$1,
      word: word,
      trans: trans,
    );
  }

  static Uint8List writeTag(TagData data) {
    final buf = BytesBuilder()
      ..add(_i32(data.n))
      ..add(_f64(data.l1))
      ..add(_f64(data.l2))
      ..add(_f64(data.l3));
    final status = [...data.status]..sort();
    buf.add(_u16(status.length));
    for (final s in status) {
      buf.add(_str(s));
    }
    _writeBaseProbInt(buf, data.wd);
    _writeBaseProbInt(buf, data.eos);
    _writeBaseProbInt(buf, data.eosd);
    _writeBaseProbInt(buf, data.uni);
    _writeBaseProbInt(buf, data.bi);
    _writeBaseProbInt(buf, data.tri);
    final wordKeys = data.word.keys.toList()..sort();
    buf.add(_u32(wordKeys.length));
    for (final k in wordKeys) {
      final vals = data.word[k]!;
      buf.add(_str(k));
      buf.add(_u16(vals.length));
      for (final v in vals) {
        buf.add(_str(v));
      }
    }
    final transKeys = data.trans.keys.toList()..sort();
    buf.add(_u32(transKeys.length));
    for (final k in transKeys) {
      buf.add(_str(k));
      buf.add(_f64(data.trans[k]!));
    }
    return _gzip(buf.toBytes());
  }

  // ---------------------------------------------------------------------------
  // Stopwords / Zh2Hans / Pinyin
  // ---------------------------------------------------------------------------

  /// Schema: u32 count, then (u16 len, UTF-8) per word (sorted).
  static List<String> readStopwords(Uint8List gzipped) {
    final view = _unzip(gzipped);
    var offset = 0;
    final count = view.getUint32(offset, Endian.little);
    offset += 4;
    final out = <String>[];
    for (var i = 0; i < count; i++) {
      final len = view.getUint16(offset, Endian.little);
      offset += 2;
      out.add(_readUtf8(view, offset, len));
      offset += len;
    }
    return out;
  }

  static Uint8List writeStopwords(List<String> words) {
    final sorted = [...words]..sort();
    final buf = BytesBuilder()..add(_u32(sorted.length));
    for (final w in sorted) {
      buf.add(_str(w));
    }
    return _gzip(buf.toBytes());
  }

  /// Schema: u32 mapLen, then for each (sorted by key): (u16 kLen, k, u16 vLen, v).
  static Map<String, String> readZh2Hans(Uint8List gzipped) {
    final view = _unzip(gzipped);
    var offset = 0;
    final count = view.getUint32(offset, Endian.little);
    offset += 4;
    final out = <String, String>{};
    for (var i = 0; i < count; i++) {
      final kLen = view.getUint16(offset, Endian.little);
      offset += 2;
      final k = _readUtf8(view, offset, kLen);
      offset += kLen;
      final vLen = view.getUint16(offset, Endian.little);
      offset += 2;
      final v = _readUtf8(view, offset, vLen);
      offset += vLen;
      out[k] = v;
    }
    return out;
  }

  static Uint8List writeZh2Hans(Map<String, String> mapping) {
    final keys = mapping.keys.toList()..sort();
    final buf = BytesBuilder()..add(_u32(keys.length));
    for (final k in keys) {
      buf.add(_str(k));
      buf.add(_str(mapping[k]!));
    }
    return _gzip(buf.toBytes());
  }

  /// Schema: u32 entryCount, then for each (sorted by char):
  ///   char: u16 len + UTF-8
  ///   readings: u16 count, then (u16 len, UTF-8) per pinyin.
  static List<PinyinEntry> readPinyin(Uint8List gzipped) {
    final view = _unzip(gzipped);
    var offset = 0;
    final count = view.getUint32(offset, Endian.little);
    offset += 4;
    final out = <PinyinEntry>[];
    for (var i = 0; i < count; i++) {
      final cLen = view.getUint16(offset, Endian.little);
      offset += 2;
      final c = _readUtf8(view, offset, cLen);
      offset += cLen;
      final pCount = view.getUint16(offset, Endian.little);
      offset += 2;
      final p = <String>[];
      for (var j = 0; j < pCount; j++) {
        final pLen = view.getUint16(offset, Endian.little);
        offset += 2;
        p.add(_readUtf8(view, offset, pLen));
        offset += pLen;
      }
      out.add(PinyinEntry(hanzi: c, pinyin: p));
    }
    return out;
  }

  static Uint8List writePinyin(List<PinyinEntry> entries) {
    final sorted = [...entries]..sort((a, b) => a.hanzi.compareTo(b.hanzi));
    final buf = BytesBuilder()..add(_u32(sorted.length));
    for (final e in sorted) {
      buf.add(_str(e.hanzi));
      buf.add(_u16(e.pinyin.length));
      for (final p in e.pinyin) {
        buf.add(_str(p));
      }
    }
    return _gzip(buf.toBytes());
  }

  // ---------------------------------------------------------------------------
  // BaseProb read/write (u32 counts)
  // ---------------------------------------------------------------------------

  static (BaseProbData, int) _readBaseProbInt(ByteData view, int offset) {
    final total = view.getFloat64(offset, Endian.little);
    offset += 8;
    final none = view.getUint8(offset);
    offset += 1;
    final pair = _readStringIntMap(view, offset);
    offset = pair.$2;
    return (BaseProbData(total: total, none: none, d: pair.$1), offset);
  }

  static void _writeBaseProbInt(BytesBuilder buf, BaseProbData p) {
    final entries = p.d.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    buf
      ..add(_f64(p.total))
      ..add(_u8(p.none))
      ..add(_u32(entries.length));
    for (final e in entries) {
      buf.add(_str(e.key));
      buf.add(_u32(e.value));
    }
  }

  static (Map<String, int>, int) _readStringIntMap(ByteData view, int offset) {
    final dLen = view.getUint32(offset, Endian.little);
    offset += 4;
    final out = <String, int>{};
    for (var i = 0; i < dLen; i++) {
      final kLen = view.getUint16(offset, Endian.little);
      offset += 2;
      final k = _readUtf8(view, offset, kLen);
      offset += kLen;
      final v = view.getUint32(offset, Endian.little);
      offset += 4;
      out[k] = v;
    }
    return (out, offset);
  }

  static void _writeStringIntMap(BytesBuilder buf, Map<String, num> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    buf.add(_u32(entries.length));
    for (final e in entries) {
      buf.add(_str(e.key));
      buf.add(_u32(e.value.toInt()));
    }
  }

  // ---------------------------------------------------------------------------
  // Low-level codec helpers
  // ---------------------------------------------------------------------------

  static ByteData _unzip(Uint8List gzipped) {
    final raw = Uint8List.fromList(GZipCodec().decode(gzipped));
    return ByteData.view(raw.buffer, raw.offsetInBytes, raw.length);
  }

  static Uint8List _gzip(Uint8List raw) =>
      Uint8List.fromList(GZipCodec(level: 6).encode(raw));

  static Uint8List _u8(int v) => Uint8List.fromList([v & 0xFF]);

  static Uint8List _u16(int v) {
    final out = Uint8List(2);
    ByteData.view(out.buffer).setUint16(0, v & 0xFFFF, Endian.little);
    return out;
  }

  static Uint8List _i32(int v) {
    final out = Uint8List(4);
    ByteData.view(out.buffer).setInt32(0, v, Endian.little);
    return out;
  }

  static Uint8List _u32(int v) {
    final out = Uint8List(4);
    ByteData.view(out.buffer).setUint32(0, v, Endian.little);
    return out;
  }

  static Uint8List _f64(double v) {
    final out = Uint8List(8);
    ByteData.view(out.buffer).setFloat64(0, v, Endian.little);
    return out;
  }

  static Uint8List _str(String s) {
    final n = _utf8ByteLen(s);
    final out = Uint8List(2 + n);
    ByteData.view(out.buffer).setUint16(0, n, Endian.little);
    var p = 2;
    for (final r in s.runes) {
      if (r < 0x80) {
        out[p++] = r;
      } else if (r < 0x800) {
        out[p++] = 0xC0 | (r >> 6);
        out[p++] = 0x80 | (r & 0x3F);
      } else if (r < 0x10000) {
        out[p++] = 0xE0 | (r >> 12);
        out[p++] = 0x80 | ((r >> 6) & 0x3F);
        out[p++] = 0x80 | (r & 0x3F);
      } else {
        out[p++] = 0xF0 | (r >> 18);
        out[p++] = 0x80 | ((r >> 12) & 0x3F);
        out[p++] = 0x80 | ((r >> 6) & 0x3F);
        out[p++] = 0x80 | (r & 0x3F);
      }
    }
    return out;
  }

  static int _utf8ByteLen(String s) {
    var n = 0;
    for (final r in s.runes) {
      if (r < 0x80) {
        n += 1;
      } else if (r < 0x800) {
        n += 2;
      } else if (r < 0x10000) {
        n += 3;
      } else {
        n += 4;
      }
    }
    return n;
  }

  /// Decodes `byteLen` UTF-8 bytes starting at [offset] into a [String].
  /// Invalid sequences are replaced with U+FFFD.
  static String _readUtf8(ByteData view, int offset, int byteLen) {
    final bytes = Uint8List(byteLen);
    for (var i = 0; i < byteLen; i++) {
      bytes[i] = view.getUint8(offset + i);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}

// ---------------------------------------------------------------------------
// Public typed payloads
// ---------------------------------------------------------------------------

class SentimentData {
  SentimentData({required this.total, required this.classes});
  final double total;
  final Map<String, ClassProb> classes;
}

class ClassProb {
  ClassProb({required this.total, required this.none, required this.d});
  final double total;
  final int none;
  final Map<String, int> d;
}

class SegData {
  SegData({
    required this.l1,
    required this.l2,
    required this.l3,
    required this.status,
    required this.uni,
    required this.bi,
    required this.tri,
  });
  final double l1;
  final double l2;
  final double l3;
  final List<String> status;
  final BaseProbData uni;
  final BaseProbData bi;
  final BaseProbData tri;
}

class TagData {
  TagData({
    required this.n,
    required this.l1,
    required this.l2,
    required this.l3,
    required this.status,
    required this.wd,
    required this.eos,
    required this.eosd,
    required this.uni,
    required this.bi,
    required this.tri,
    required this.word,
    required this.trans,
  });
  final int n;
  final double l1;
  final double l2;
  final double l3;
  final List<String> status;
  final BaseProbData wd;
  final BaseProbData eos;
  final BaseProbData eosd;
  final BaseProbData uni;
  final BaseProbData bi;
  final BaseProbData tri;
  final Map<String, List<String>> word;
  final Map<String, double> trans;
}

class BaseProbData {
  BaseProbData({required this.total, required this.none, required this.d});
  final double total;
  final int none;
  final Map<String, int> d;
}

class PinyinEntry {
  PinyinEntry({required this.hanzi, required this.pinyin});
  final String hanzi;
  final List<String> pinyin;
}
