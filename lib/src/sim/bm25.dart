import 'dart:math' as math;

/// BM25 (Robertson, Walker, et al.) — used by snownlp's TextRank to build
/// sentence-similarity edges. Defaults match snownlp: `k1 = 1.5`, `b = 0.75`.
class BM25 {
  BM25(Object docsOrString, {this.k1 = 1.5, this.b = 0.75}) {
    // snownlp passes a Python string here, which iterates as characters.
    // Normalise to a `List<List<String>>` for typed access downstream.
    final List<List<String>> docs;
    if (docsOrString is String) {
      docs = [docsOrString.split('')];
    } else if (docsOrString is List<List<String>>) {
      docs = docsOrString;
    } else {
      docs = [(docsOrString as List).cast<String>()];
    }
    this.docs = docs;
    final n = docs.length;
    if (n == 0) {
      avgdl = 0;
      return;
    }
    D = n;
    avgdl = docs.fold<num>(0, (a, d) => a + d.length) / n;
    for (final doc in docs) {
      final tf = <String, int>{};
      for (final word in doc) {
        tf[word] = (tf[word] ?? 0) + 1;
      }
      f.add(tf);
      for (final entry in tf.entries) {
        df[entry.key] = (df[entry.key] ?? 0) + 1;
      }
    }
    for (final entry in df.entries) {
      // log((N - df + 0.5) / (df + 0.5))  — snownlp's exact formula.
      idf[entry.key] =
          math.log(D - entry.value + 0.5) - math.log(entry.value + 0.5);
    }
  }

  List<List<String>> docs = <List<String>>[];
  int D = 0;
  double avgdl = 0;
  List<Map<String, int>> f = <Map<String, int>>[];
  Map<String, int> df = <String, int>{};
  Map<String, double> idf = <String, double>{};
  double k1;
  double b;

  /// BM25 score of `doc` against the `index`-th document in the corpus.
  double sim(List<String> doc, int index) {
    final fI = f[index];
    final dlen = docs[index].length;
    var score = 0.0;
    for (final word in doc) {
      final c = fI[word];
      if (c == null || c == 0) continue;
      final w = idf[word] ?? 0;
      score += w * c * (k1 + 1) / (c + k1 * (1 - b + b * dlen / avgdl));
    }
    return score;
  }

  /// BM25 score of `doc` against every document in the corpus.
  List<double> simall(List<String> doc) =>
      [for (var i = 0; i < D; i++) sim(doc, i)];
}