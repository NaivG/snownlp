/// Port of `snownlp/utils/trie.py`. A simple character-keyed trie used by
/// `zh2hans` and `pinyin` to perform longest-match substitution / lookup.
class Trie {
  final Map<String, dynamic> _root = <String, dynamic>{};

  void insert(List<String> key, dynamic value) {
    var now = _root;
    for (final k in key) {
      now.putIfAbsent(k, () => <String, dynamic>{});
      now = now[k] as Map<String, dynamic>;
    }
    now['value'] = value;
  }

  /// Walks the trie from `text[start]` collecting the longest match found.
  /// Returns `null` if no entry starts at `start`.
  ({String matched, dynamic value})? find(String text, [int start = 0]) {
    var now = _root;
    var n = text.length;
    ({String matched, dynamic value})? ret;
    var pos = start;
    while (pos < n) {
      final ch = text[pos];
      if (!now.containsKey(ch)) {
        return ret;
      }
      now = now[ch] as Map<String, dynamic>;
      final v = now['value'];
      if (v != null) {
        ret = (matched: text.substring(start, pos + 1), value: v);
      }
      pos++;
    }
    return ret;
  }

  /// Translate `text` greedily from left to right. If `withNotFound` is true
  /// (the default), unmatched characters are passed through unchanged.
  List<dynamic> translate(String text, {bool withNotFound = true}) {
    final out = <dynamic>[];
    var pos = 0;
    final n = text.length;
    while (pos < n) {
      var now = _root;
      if (now.containsKey(text[pos])) {
        final tmp = find(text, pos);
        if (tmp != null) {
          out.add(tmp.value);
          pos += tmp.matched.length;
          continue;
        }
      }
      if (withNotFound) {
        out.add(text[pos]);
      }
      pos++;
    }
    return out;
  }
}