import '../config.dart';
import '../utils/binary_format.dart';
import '../utils/trie.dart';
import 'sentences.dart';

/// Pinyin lookup. Loads `pinyin.bin` (56k entries) into a :class:`Trie`
/// and emits all readings for each Han character run.
class PinYin {
  PinYin._(this._trie);

  static Future<PinYin> load() async {
    final raw = await SnowConfig.instance.loadModelBytes('pinyin.bin');
    final gz = BinaryFormat.readPayloadFromBytes(
      raw,
      BinaryFormat.typePinyin,
      source: 'pinyin.bin',
    );
    final entries = BinaryFormat.readPinyin(gz);
    final trie = Trie();
    for (final e in entries) {
      trie.insert(e.hanzi.split(''), e.pinyin);
    }
    return PinYin._(trie);
  }

  final Trie _trie;

  /// Get a flat list of pinyin readings. Multi-reading characters
  /// produce multiple entries in the output (snownlp's behaviour).
  List<String> get(String text) {
    final ret = <String>[];
    for (final part in _trie.translate(text)) {
      if (part is List<String>) {
        ret.addAll(part);
      } else if (part is String) {
        ret.add(part);
      }
    }
    return ret;
  }
}

PinYin? _shared;
Future<PinYin>? _pinyinLoading;

Future<PinYin> get _pinyin async {
  final cached = _shared;
  if (cached != null) return cached;
  return _pinyinLoading ??= PinYin.load().then((v) => _shared = v);
}

/// Top-level convenience matching `snownlp.normal.get_pinyin`. Splits
/// the input on CJK runs: Han runs are converted to pinyin; non-Han
/// runs are whitespace-split and passed through unchanged. Async
/// because the underlying pinyin table is loaded from an asset.
Future<List<String>> getPinyin(String sentence) async {
  final ret = <String>[];
  final pinyin = await _pinyin;
  for (final s in splitKeeping(reZh, sentence)) {
    final t = s.trim();
    if (t.isEmpty) continue;
    if (isChinese(t)) {
      ret.addAll(pinyin.get(t));
    } else {
      for (final w in t.split(RegExp(r'\s+'))) {
        final wt = w.trim();
        if (wt.isNotEmpty) ret.add(wt);
      }
    }
  }
  return ret;
}
