import '../config.dart';
import '../utils/binary_format.dart';

/// Loads the `stopwords.bin` asset (built once from snownlp's
/// `normal/stopwords.txt`). Exposes :meth:`filterStop` which drops any
/// stopword from a token list.
class Stopwords {
  Stopwords._(this._set);

  static Future<Stopwords> load() async {
    final raw = await SnowConfig.instance.loadModelBytes('stopwords.bin');
    final gz = BinaryFormat.readPayloadFromBytes(
      raw,
      BinaryFormat.typeStopwords,
      source: 'stopwords.bin',
    );
    final words = BinaryFormat.readStopwords(gz);
    return Stopwords._(Set<String>.from(words));
  }

  final Set<String> _set;

  /// Return a new list with every entry that appears in the stopword set
  /// removed. Mirrors `snownlp.normal.filter_stop`. This is intentionally
  /// sync — the stopword set is loaded once via [get stopwords] and the
  /// pure filtering step doesn't touch the file system.
  List<String> filterStop(List<String> words) =>
      words.where((w) => !_set.contains(w)).toList(growable: false);

  bool contains(String w) => _set.contains(w);

  int get length => _set.length;
}

Stopwords? _shared;
Future<Stopwords>? _stopwordsLoading;

/// Lazily-loaded singleton. Repeated concurrent calls share the same
/// in-flight load. After the first resolution the stopword set is
/// cached and [Stopwords.filterStop] can be called synchronously.
Future<Stopwords> get stopwords async {
  final cached = _shared;
  if (cached != null) return cached;
  return _stopwordsLoading ??= Stopwords.load().then((v) => _shared = v);
}
