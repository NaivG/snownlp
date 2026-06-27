import 'bayes.dart';
import '../normal/stopwords.dart' as stopwords_mod;
import '../segmentation/segmenter.dart' as seg_mod;

/// Sentiment classifier. Wraps :class:`Bayes` and adds the
/// `seg -> filter_stop` document preprocessing that snownlp applies.
class Sentiment {
  Sentiment(this.classifier);

  final Bayes classifier;

  /// Tokenise `doc` and drop stopwords.
  Future<List<String>> handle(String doc) async {
    final words = await seg_mod.seg(doc);
    final sw = await stopwords_mod.stopwords;
    return sw.filterStop(words);
  }

  /// Train from two corpora: `neg` lines are negative examples, `pos`
  /// lines are positive.
  Future<void> train(List<String> neg, List<String> pos) async {
    final data = <(List<String>, String)>[];
    for (final s in neg) {
      data.add((await handle(s), 'neg'));
    }
    for (final s in pos) {
      data.add((await handle(s), 'pos'));
    }
    classifier.train(data);
  }

  /// Returns the probability that `sent` expresses a positive sentiment.
  /// When the model predicts the negative class we return `1 - prob`
  /// (mirrors snownlp: `sentiments` is always P(positive)).
  Future<double> classify(String sent) async {
    final r = classifier.classify(await handle(sent));
    return r.label == 'pos' ? r.probability : 1 - r.probability;
  }

  static Future<Sentiment> load() async =>
      Sentiment(await Bayes.loadSentiment());
}

/// Module-level singleton loaded lazily on first use.
Sentiment? _shared;
Future<Sentiment>? _loading;

Future<Sentiment> get sentiment async {
  final cached = _shared;
  if (cached != null) return cached;
  return _loading ??= Sentiment.load().then((v) => _shared = v);
}

/// Force the module-level singleton to be re-loaded (useful in tests).
void reloadSentiment() {
  _shared = null;
  _loading = null;
}
