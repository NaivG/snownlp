/// Bigram-frequency merger. When two keywords frequently co-occur
/// adjacent in `doc`, they are concatenated into a single keyword.
/// Mirrors `snownlp.summary.words_merge.SimpleMerge`.
class SimpleMerge {
  SimpleMerge(this.doc, this.words);

  /// Original document string used to count bigram frequencies.
  final String doc;

  /// Candidate keywords from `KeywordTextRank`.
  final List<String> words;

  List<String> merge() {
    final trans = <String, String>{};
    for (final w in words) {
      trans[w] = '';
    }
    for (final w1 in words) {
      var cw = 0;
      final lw = w1.length;
      for (var i = 0; i + lw <= doc.length; i++) {
        if (w1 == doc.substring(i, i + lw)) cw++;
      }
      for (final w2 in words) {
        var cnt = 0;
        final l2 = w1.length + w2.length;
        for (var i = 0; i + l2 <= doc.length; i++) {
          if (w1 + w2 == doc.substring(i, i + l2)) cnt++;
        }
        if (cw < cnt * 2) {
          trans[w1] = w2;
          break;
        }
      }
    }
    final ret = <String>[];
    for (final w in words) {
      if (!trans.containsKey(w)) continue;
      var s = '';
      var now = trans[w]!;
      // Walk the chain until it terminates.
      // (snownlp deletes from trans as it walks to avoid cycles.)
      while (now.isNotEmpty) {
        s += now;
        if (!trans.containsKey(now)) break;
        final tmp = trans[now]!;
        trans.remove(now);
        now = tmp;
      }
      trans[w] = s;
    }
    for (final w in words) {
      if (trans.containsKey(w)) ret.add(w + trans[w]!);
    }
    return ret;
  }
}