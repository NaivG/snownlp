import 'dart:math' as math;

/// Base class for probability tables used by snownlp. Mirrors
/// `utils/frequency.py::BaseProb` from the Python reference: a map from
/// string-key to count plus a `total` and a `none` count returned for
/// keys that are not in the map.
abstract class BaseProb {
  Map<String, num> d = <String, num>{};
  num total = 0;
  num none = 0;

  bool exists(String key) => d.containsKey(key);

  num getsum() => total;

  /// Returns `(found, count)` where `count` is `none` if the key was missing.
  ({bool found, num value}) get(String key) {
    if (!exists(key)) return (found: false, value: none);
    return (found: true, value: d[key]!);
  }

  /// `freq(key) = count(key) / total`. Returns 0 for unknown keys.
  double freq(String key) {
    if (total == 0) return 0;
    final g = get(key);
    return g.value.toDouble() / total.toDouble();
  }

  Iterable<String> samples() => d.keys;

  void add(String key, num value);
}

/// MLE-style frequency table; the count of an unseen key is `none` (0).
class NormalProb extends BaseProb {
  @override
  void add(String key, num value) {
    d[key] = (d[key] ?? 0) + value;
    total += value;
  }
}

/// Laplace-smoothed frequency table. New keys are initialized to 1 and
/// `total` is bumped by 1 too, so unseen keys fall back to `none == 1`.
class AddOneProb extends BaseProb {
  AddOneProb() {
    none = 1;
  }

  @override
  void add(String key, num value) {
    total += value;
    if (!exists(key)) {
      d[key] = 1;
      total += 1;
    }
    d[key] = d[key]! + value;
  }
}

/// Good–Turing smoothed frequency table. The Python reference doesn't
/// actually serialize any models that use this, but we keep it for parity
/// with the source so that re-trained models can round-trip.
class GoodTuringProb extends BaseProb {
  bool _handled = false;

  @override
  void add(String key, num value) {
    d[key] = (d[key] ?? 0) + value;
  }

  @override
  ({bool found, num value}) get(String key) {
    if (!_handled) {
      _handled = true;
      final result = goodTuring(d);
      none = result.none;
      d = result.d;
      total = d.values.fold<num>(0, (a, b) => a + b);
    }
    if (!exists(key)) return (found: false, value: none);
    return (found: true, value: d[key]!);
  }

  /// Simple re-implementation of the smoothing used by snownlp. The
  /// Python reference has its own helper; this is good enough for the
  /// load path which never re-trains a GoodTuring model at runtime.
  static ({Map<String, num> d, num none}) goodTuring(Map<String, num> input) {
    final counts = <int, int>{};
    for (final v in input.values) {
      final i = v.toInt();
      counts[i] = (counts[i] ?? 0) + 1;
    }
    final out = <String, num>{};
    for (final entry in input.entries) {
      final c = entry.value.toInt();
      final c1 = counts[c] ?? 0;
      final c2 = counts[c + 1] ?? 0;
      if (c1 == 0) {
        out[entry.key] = 0;
      } else {
        out[entry.key] = (c + 1) * (c2 / c1) / c;
      }
    }
    return (d: out, none: 1 / math.max(1, input.length));
  }
}