import 'dart:math' as math;

import '../config.dart';
import '../utils/binary_format.dart';
import '../utils/frequency.dart';

/// Xue & Shen (2003) character-based generative model for Chinese word
/// segmentation. Uses BMES tags (begin / middle / end / single) and a
/// 3-gram interpolated probability table.
///
/// Inherits the same schema as the snownlp `seg.marshal.3` payload.
class CharacterBasedGenerativeModel {
  CharacterBasedGenerativeModel();

  double l1 = 0.0;
  double l2 = 0.0;
  double l3 = 0.0;
  List<String> status = const ['b', 'm', 'e', 's'];
  NormalProb uni = NormalProb();
  NormalProb bi = NormalProb();
  NormalProb tri = NormalProb();

  static double _div(num v1, num v2) => v2 == 0 ? 0 : v1.toDouble() / v2.toDouble();

  /// Run the viterbi-style decoder on a sentence (a list of characters).
  /// Returns the BMES tag for each character.
  List<String> tag(List<String> data) {
    var now = <((String, String), double, List<String>)>[
      (('', 'BOS'), 0.0, const []),
    ];
    for (final w in data) {
      final stage = <(String, String), (double, List<String>)>{};
      var notFound = true;
      for (final s in status) {
        if (uni.freq('$w\x01$s') != 0) {
          notFound = false;
          break;
        }
      }
      if (notFound) {
        // The character was never seen at training time; assume any tag
        // is equally plausible and accumulate log-prob zero. This is the
        // same fast-path snownlp uses.
        for (final s in status) {
          for (final pre in now) {
            final key = (pre.$1.$2, '$w\x01$s');
            stage[key] = (pre.$2, [...pre.$3, s]);
          }
        }
        now = stage.entries
            .map((e) => ((e.key.$1, e.key.$2), e.value.$1, e.value.$2))
            .toList();
        continue;
      }
      for (final s in status) {
        for (final pre in now) {
          final p = pre.$2 + _logProb(pre.$1.$1, pre.$1.$2, '$w\x01$s');
          final key = (pre.$1.$2, '$w\x01$s');
          final existing = stage[key];
          if (existing == null || p > existing.$1) {
            stage[key] = (p, [...pre.$3, s]);
          }
        }
      }
      now = stage.entries
          .map((e) => ((e.key.$1, e.key.$2), e.value.$1, e.value.$2))
          .toList();
    }
    final best = now.reduce((a, b) => a.$2 > b.$2 ? a : b);
    return best.$3;
  }

  double _logProb(String s1, String s2, String s3) {
    final uniPart = l1 * uni.freq(s3);
    final biPart = _div(l2 * bi.get('$s2\x01$s3').value, uni.get(s2).value);
    final triPart = _div(l3 * tri.get('$s1\x01$s2\x01$s3').value, bi.get('$s1\x01$s2').value);
    final sum = uniPart + biPart + triPart;
    if (sum == 0) return double.negativeInfinity;
    return math.log(sum);
  }

  /// Decode a sentence string into BMES tags.
  List<String> seg(String sentence) {
    final chars = sentence.split('');
    final tags = tag(chars);
    final out = <String>[];
    var buf = '';
    for (var i = 0; i < chars.length; i++) {
      final t = tags[i];
      if (t == 'e') {
        buf += chars[i];
        out.add(buf);
        buf = '';
      } else if (t == 'b' || t == 's') {
        if (buf.isNotEmpty) out.add(buf);
        buf = chars[i];
      } else {
        buf += chars[i];
      }
    }
    if (buf.isNotEmpty) out.add(buf);
    return out;
  }

  static NormalProb _loadProb(BaseProbData data) {
    final p = NormalProb();
    p.total = data.total;
    p.none = data.none;
    p.d = data.d.map((k, v) => MapEntry(k, v));
    return p;
  }

  /// Load the model from the `seg.bin` asset.
  static Future<CharacterBasedGenerativeModel> load() async {
    final raw = await SnowConfig.instance.loadModelBytes('seg.bin');
    final gz = BinaryFormat.readPayloadFromBytes(
      raw,
      BinaryFormat.typeSeg,
      source: 'seg.bin',
    );
    final d = BinaryFormat.readSeg(gz);
    final m = CharacterBasedGenerativeModel()
      ..l1 = d.l1
      ..l2 = d.l2
      ..l3 = d.l3
      ..status = d.status
      ..uni = _loadProb(d.uni)
      ..bi = _loadProb(d.bi)
      ..tri = _loadProb(d.tri);
    return m;
  }
}
