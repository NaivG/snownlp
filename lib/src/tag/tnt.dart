import 'dart:math' as math;

import '../config.dart';
import '../utils/binary_format.dart';
import '../utils/frequency.dart';

const _sep = '\x01';

typedef _BeamItem = ((String, String), double, List<String>);

/// Brants (2000) TnT statistical POS tagger. Mirrors
/// `snownlp.utils.tnt.TnT`. Uses beam search with `N` candidates and a
/// precomputed `trans` table for the interpolated λ₁·P₁ + λ₂·P₂ + λ₃·P₃
/// log-probability lookup.
class TnT {
  TnT({this.N = 1000});

  int N;
  double l1 = 0.0;
  double l2 = 0.0;
  double l3 = 0.0;
  List<String> status = const [];
  AddOneProb wd = AddOneProb();
  AddOneProb eos = AddOneProb();
  AddOneProb eosd = AddOneProb();
  NormalProb uni = NormalProb();
  NormalProb bi = NormalProb();
  NormalProb tri = NormalProb();
  Map<String, Set<String>> word = <String, Set<String>>{};
  Map<String, double> trans = <String, double>{};

  /// log P(EOS | tag). Returns log(1.0 / |status|) for unknown tags.
  double getEos(String tag) {
    final ed = eosd.get(tag);
    if (!ed.found) {
      return -math.log(status.length.toDouble());
    }
    final e = eos.get('$tag${_sep}EOS');
    return math.log(e.value.toDouble()) - math.log(ed.value.toDouble());
  }

  /// Returns one POS tag per input word.
  List<String> tag(List<String> data) {
    // Beam state: list of ((prevPrev, prev), score, [tags...]).
    List<_BeamItem> now = [(('BOS', 'BOS'), 0.0, const [])];
    for (final w in data) {
      final stage = <(String, String), (double, List<String>)>{};
      final candidates = word[w] ?? status.toSet();
      for (final s in candidates) {
        final wdScore =
            math.log(wd.get('$s$_sep$w').value.toDouble()) -
                math.log(uni.get(s).value.toDouble());
        for (final pre in now) {
          final transKey = '${pre.$1.$1}$_sep${pre.$1.$2}$_sep$s';
          final t = trans[transKey];
          if (t == null) continue; // unseen transition
          final p = pre.$2 + wdScore + t;
          final key = (pre.$1.$2, s);
          final existing = stage[key];
          if (existing == null || p > existing.$1) {
            stage[key] = (p, [...pre.$3, s]);
          }
        }
      }
      // Pick top N by score (beam search).
      now = stage.entries
          .map<_BeamItem>(
              (e) => ((e.key.$1, e.key.$2), e.value.$1, e.value.$2))
          .toList()
        ..sort((a, b) => b.$2.compareTo(a.$2));
      if (now.length > N) now = now.sublist(0, N);
    }
    if (now.isEmpty) {
      return List.filled(data.length, status.isEmpty ? 'n' : status.first);
    }
    now.sort((a, b) =>
        (b.$2 + getEos(b.$1.$2)).compareTo(a.$2 + getEos(a.$1.$2)));
    return now.first.$3;
  }

  static AddOneProb _loadAdd(BaseProbData data) {
    final p = AddOneProb();
    p.total = data.total;
    p.none = data.none;
    p.d = data.d.map((k, v) => MapEntry(k, v));
    return p;
  }

  static NormalProb _loadNorm(BaseProbData data) {
    final p = NormalProb();
    p.total = data.total;
    p.none = data.none;
    p.d = data.d.map((k, v) => MapEntry(k, v));
    return p;
  }

  /// Load the model from `tag.bin`.
  static Future<TnT> load() async {
    final raw = await SnowConfig.instance.loadModelBytes('tag.bin');
    final gz = BinaryFormat.readPayloadFromBytes(
      raw,
      BinaryFormat.typeTag,
      source: 'tag.bin',
    );
    final d = BinaryFormat.readTag(gz);
    final t = TnT(N: d.n)
      ..l1 = d.l1
      ..l2 = d.l2
      ..l3 = d.l3
      ..status = d.status
      ..wd = _loadAdd(d.wd)
      ..eos = _loadAdd(d.eos)
      ..eosd = _loadAdd(d.eosd)
      ..uni = _loadNorm(d.uni)
      ..bi = _loadNorm(d.bi)
      ..tri = _loadNorm(d.tri)
      ..word = d.word.map((k, v) => MapEntry(k, v.toSet()))
      ..trans = d.trans;
    return t;
  }
}

TnT? _shared;
Future<TnT>? _taggerLoading;

/// Lazily-loaded singleton matching snownlp's module-level `tagger`.
/// Repeated concurrent calls share the same in-flight load.
Future<TnT> get tagger async {
  final cached = _shared;
  if (cached != null) return cached;
  return _taggerLoading ??= TnT.load().then((v) => _shared = v);
}

/// Top-level convenience matching `snownlp.tag.tag`.
Future<List<String>> tag(List<String> words) async =>
    (await tagger).tag(words);
