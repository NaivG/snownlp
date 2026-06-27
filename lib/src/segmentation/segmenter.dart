import '../normal/sentences.dart';
import 'character_model.dart';

/// Public Seg wrapper. Mirrors `snownlp.seg.__init__.seg` — Chinese
/// character runs are decoded by :class:`CharacterBasedGenerativeModel`;
/// non-Chinese runs are split on whitespace.
class Seg {
  Seg(this.model);

  final CharacterBasedGenerativeModel model;

  static Seg? _shared;
  static Future<Seg>? _loading;

  /// Lazy singleton matching snownlp's module-level `segger`. Repeated
  /// concurrent calls share the same in-flight load.
  static Future<Seg> get instance async {
    final cached = _shared;
    if (cached != null) return cached;
    return _loading ??= () async {
      final model = await CharacterBasedGenerativeModel.load();
      return _shared = Seg(model);
    }();
  }

  /// Top-level convenience that uses the singleton model.
  List<String> segSentence(String sentence) {
    final out = <String>[];
    for (final s in splitKeeping(reZh, sentence)) {
      final t = s.trim();
      if (t.isEmpty) continue;
      if (isChinese(t)) {
        out.addAll(model.seg(t));
      } else {
        for (final w in t.split(RegExp(r'\s+'))) {
          final wt = w.trim();
          if (wt.isNotEmpty) out.add(wt);
        }
      }
    }
    return out;
  }
}

/// Top-level convenience used by the rest of the package. Async because
/// the underlying CBGM model is loaded from an asset.
Future<List<String>> seg(String sentence) async =>
    (await Seg.instance).segSentence(sentence);
