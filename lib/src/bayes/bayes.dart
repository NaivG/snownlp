import 'dart:math' as math;

import '../config.dart';
import '../utils/binary_format.dart';
import '../utils/frequency.dart';

/// Multinomial Naive Bayes with Laplace smoothing. Mirrors
/// `snownlp.classification.bayes.Bayes`.
///
/// Each class has its own :class:`AddOneProb` table mapping each observed
/// word to its count. `classify(x)` returns the class whose log-posterior
/// is highest, plus the softmax probability of that class (overflow-safe
/// via the max-subtraction trick — Python's `try/except OverflowError`).
class Bayes {
  Bayes();

  /// Map from class label -> AddOneProb table.
  final Map<String, AddOneProb> d = <String, AddOneProb>{};

  /// Sum of all class totals (used as the class-prior denominator).
  num total = 0;

  /// Train from `data` where each entry is `(tokens, classLabel)`.
  void train(List<(List<String>, String)> data) {
    for (final entry in data) {
      final tokens = entry.$1;
      final c = entry.$2;
      d.putIfAbsent(c, () => AddOneProb());
      final prob = d[c]!;
      for (final word in tokens) {
        prob.add(word, 1);
      }
    }
    total = d.values.fold<num>(0, (a, p) => a + p.getsum());
  }

  /// Returns `(classLabel, probability)`. Probability is the normalised
  /// softmax of the log-posteriors. The max-subtraction trick keeps the
  /// exp() safe from overflow (Python's `try/except OverflowError`).
  ({String label, double probability}) classify(List<String> x) {
    final tmp = <String, double>{};
    for (final k in d.keys) {
      final p = d[k]!;
      var v = math.log(p.getsum().toDouble()) - math.log(total.toDouble());
      for (final word in x) {
        v += math.log(p.freq(word));
      }
      tmp[k] = v;
    }

    var bestLabel = d.keys.first;
    var bestProb = 0.0;
    for (final k in d.keys) {
      var sum = 0.0;
      for (final otherK in d.keys) {
        // exp() returns +inf on overflow; 1/inf -> 0.0 keeps semantics.
        sum += math.exp(tmp[otherK]! - tmp[k]!);
      }
      final prob = sum == double.infinity ? 0.0 : 1.0 / sum;
      if (prob > bestProb) {
        bestProb = prob;
        bestLabel = k;
      }
    }
    return (label: bestLabel, probability: bestProb);
  }

  /// Build from a decoded [SentimentData] payload.
  static Bayes fromBinary(SentimentData payload) {
    final out = Bayes();
    out.total = payload.total;
    for (final entry in payload.classes.entries) {
      final p = AddOneProb();
      p.total = entry.value.total;
      p.none = entry.value.none;
      p.d = entry.value.d.map((k, v) => MapEntry(k, v));
      out.d[entry.key] = p;
    }
    return out;
  }

  /// Convenience: load from the `sentiment.bin` asset.
  static Future<Bayes> loadSentiment() async {
    final raw = await SnowConfig.instance.loadModelBytes('sentiment.bin');
    final gz = BinaryFormat.readPayloadFromBytes(
      raw,
      BinaryFormat.typeSentiment,
      source: 'sentiment.bin',
    );
    return fromBinary(BinaryFormat.readSentiment(gz));
  }
}
