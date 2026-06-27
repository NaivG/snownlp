import '../config.dart';
import '../utils/binary_format.dart';
import '../utils/trie.dart';

/// Traditional-to-Simplified Chinese conversion. Loads the `zh2hans.bin`
/// mapping into a :class:`Trie` and performs longest-match substitution.
class Zh2Hans {
  Zh2Hans._(this._trie);

  static Future<Zh2Hans> load() async {
    final raw = await SnowConfig.instance.loadModelBytes('zh2hans.bin');
    final gz = BinaryFormat.readPayloadFromBytes(
      raw,
      BinaryFormat.typeZh2Hans,
      source: 'zh2hans.bin',
    );
    final mapping = BinaryFormat.readZh2Hans(gz);
    final trie = Trie();
    for (final entry in mapping.entries) {
      trie.insert(entry.key.split(''), entry.value);
    }
    return Zh2Hans._(trie);
  }

  final Trie _trie;

  String transfer(String sentence) {
    final out = <String>[];
    for (final piece in _trie.translate(sentence)) {
      if (piece is String) {
        out.add(piece);
      }
    }
    return out.join();
  }
}

Zh2Hans? _shared;
Future<Zh2Hans>? _loading;

Future<Zh2Hans> get _converter async {
  final cached = _shared;
  if (cached != null) return cached;
  return _loading ??= Zh2Hans.load().then((v) => _shared = v);
}

/// Top-level convenience matching `snownlp.normal.zh2hans`. Async
/// because the mapping trie is loaded from an asset.
Future<String> zh2hans(String sentence) async =>
    (await _converter).transfer(sentence);
