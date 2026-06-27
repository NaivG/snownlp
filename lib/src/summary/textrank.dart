import 'dart:math' as math;

import '../sim/bm25.dart';

/// Sentence-level TextRank (Mihalcea & Tarau, 2004) with BM25 edge weights.
/// Matches snownlp's `summary.textrank.TextRank`.
class TextRank {
  TextRank(this.docs, {this.d = 0.85, this.maxIter = 200, this.minDiff = 0.001}) {
    bm25 = BM25(docs);
    D = docs.length;
    weight = <List<double>>[];
    weightSum = <double>[];
    vertex = List<double>.filled(D, 1.0);
  }

  final List<List<String>> docs;
  late final BM25 bm25;
  late int D;
  late List<List<double>> weight;
  late List<double> weightSum;
  late List<double> vertex;
  double d;
  int maxIter;
  double minDiff;
  List<(int, double)> top = const [];

  void solve() {
    for (var cnt = 0; cnt < D; cnt++) {
      final scores = bm25.simall(docs[cnt]);
      weight.add(scores);
      weightSum.add(_sum(scores) - scores[cnt]);
    }
    for (var iter = 0; iter < maxIter; iter++) {
      final m = <double>[];
      var maxDiff = 0.0;
      for (var i = 0; i < D; i++) {
        var s = 1 - d;
        for (var j = 0; j < D; j++) {
          if (j == i || weightSum[j] == 0) continue;
          s += d * weight[j][i] / weightSum[j] * vertex[j];
        }
        m.add(s);
        if ((s - vertex[i]).abs() > maxDiff) {
          maxDiff = (s - vertex[i]).abs();
        }
      }
      vertex = m;
      if (maxDiff <= minDiff) break;
    }
    top = [for (var i = 0; i < D; i++) (i, vertex[i])]
      ..sort((a, b) => b.$2.compareTo(a.$2));
  }

  /// Top `limit` document indices, sorted by TextRank score (desc).
  List<int> topIndex(int limit) => top.take(limit).map((e) => e.$1).toList();

  /// Top `limit` documents (whole lists), sorted by TextRank score (desc).
  List<List<String>> topDocs(int limit) =>
      top.take(limit).map((e) => docs[e.$1]).toList();

  static double _sum(List<double> xs) =>
      xs.fold<double>(0, (a, b) => a + b);
}

/// Keyword TextRank: window-5 co-occurrence graph over words.
/// Matches snownlp's `summary.textrank.KeywordTextRank`.
class KeywordTextRank {
  KeywordTextRank(this.docs,
      {this.d = 0.85, this.maxIter = 200, this.minDiff = 0.001}) {
    words = <String, Set<String>>{};
    vertex = <String, double>{};
  }

  final List<List<String>> docs;
  late Map<String, Set<String>> words;
  late Map<String, double> vertex;
  double d;
  int maxIter;
  double minDiff;
  List<(String, double)> top = const [];

  void solve() {
    for (final doc in docs) {
      final que = <String>[];
      for (final word in doc) {
        words.putIfAbsent(word, () => <String>{});
        vertex.putIfAbsent(word, () => 1.0);
        que.add(word);
        if (que.length > 5) que.removeAt(0);
        for (final w1 in que) {
          for (final w2 in que) {
            if (w1 == w2) continue;
            words[w1]!.add(w2);
            words[w2]!.add(w1);
          }
        }
      }
    }
    for (var iter = 0; iter < maxIter; iter++) {
      final m = <String, double>{};
      var maxDiff = 0.0;
      // Order: words with neighbours first, then by score / neighbour count.
      final ordered = vertex.entries
          .where((e) => words[e.key]!.isNotEmpty)
          .toList()
        ..sort((a, b) {
          final ra = a.value / math.max(1, words[a.key]!.length);
          final rb = b.value / math.max(1, words[b.key]!.length);
          return ra.compareTo(rb);
        });
      for (final entry in ordered) {
        final k = entry.key;
        for (final j in words[k]!) {
          if (k == j) continue;
          m.putIfAbsent(j, () => 1 - d);
          m[j] = m[j]! + d / words[k]!.length * vertex[k]!;
        }
      }
      for (final k in vertex.keys) {
        if (m.containsKey(k) && vertex.containsKey(k)) {
          if ((m[k]! - vertex[k]!).abs() > maxDiff) {
            maxDiff = (m[k]! - vertex[k]!).abs();
          }
        }
      }
      vertex = m;
      if (maxDiff <= minDiff) break;
    }
    top = [for (final e in vertex.entries) (e.key, e.value)]
      ..sort((a, b) => b.$2.compareTo(a.$2));
  }

  /// Top `limit` keywords (just the strings), sorted by score (desc).
  List<String> topIndex(int limit) => top.take(limit).map((e) => e.$1).toList();
}