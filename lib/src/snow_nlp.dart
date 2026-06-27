import 'bayes/sentiment.dart' as sentiment_mod;
import 'normal/pinyin.dart' as normal_py;
import 'normal/sentences.dart';
import 'normal/stopwords.dart' as stopwords_mod;
import 'normal/zh.dart' as normal_zh;
import 'segmentation/segmenter.dart' as seg_mod;
import 'sim/bm25.dart';
import 'summary/textrank.dart';
import 'summary/words_merge.dart';
import 'tag/tnt.dart' as tnt_mod;

/// Facade mirroring `snownlp.SnowNLP`. Construct with a document, then
/// access properties / call methods to extract structure.
///
/// Every property / method that needs a `.bin` model is async because
/// the underlying assets are loaded through [SnowConfig.loadModelBytes],
/// which is async in both the default [IoAssetLoader] and the Flutter
/// [FlutterAssetLoader] path.
class SnowNLP {
  SnowNLP(this.doc) : bm25 = BM25([doc]);

  final String doc;
  final BM25 bm25;
  List<String>? _words;
  List<String>? _sentences;

  /// Document split into sentences on `，。？！；` and newlines.
  List<String> get sentences => _sentences ??= getSentences(doc);

  /// Term-frequency maps (one per document). For a single-document
  /// `SnowNLP` this is a list with one element.
  List<Map<String, int>> get tf => bm25.f;

  /// Inverse-document-frequency map (single doc → can be ≤ 0).
  Map<String, double> get idf => bm25.idf;

  /// Tokenised document via the CBGM character-based generative model.
  Future<List<String>> get words async =>
      _words ??= await seg_mod.seg(doc);

  /// Probability that the document expresses a positive sentiment.
  /// Always returns P(positive): for negative predictions we return
  /// `1 - raw_prob`, mirroring snownlp.
  Future<double> get sentiments async => sentiment_mod.sentiment.then(
        (s) => s.classify(doc),
      );

  /// Per-token POS tag pairs `[(word, tag), ...]`.
  Future<List<(String, String)>> get tags async {
    final ws = await words;
    final tagSeq = await tnt_mod.tag(ws);
    return [for (var i = 0; i < ws.length; i++) (ws[i], tagSeq[i])];
  }

  /// BM25 similarity between `doc` and every string in `other`.
  /// `other` is a list of pre-tokenised documents.
  List<double> sim(List<String> other) => bm25.simall(other);

  /// Top `limit` sentences chosen by TextRank over the segmented document.
  Future<List<String>> summary({int limit = 5}) async {
    final sents = sentences;
    final sw = await stopwords_mod.stopwords;
    final corpus = <List<String>>[];
    for (final s in sents) {
      corpus.add(sw.filterStop(await seg_mod.seg(s)));
    }
    final rank = TextRank(corpus);
    rank.solve();
    return [for (final i in rank.topIndex(limit)) sents[i]];
  }

  /// Top `limit` keywords by `KeywordTextRank`. When `merge` is true,
  /// :class:`SimpleMerge` combines adjacent keywords into bigram terms.
  Future<List<String>> keywords({int limit = 5, bool merge = false}) async {
    final sents = sentences;
    final sw = await stopwords_mod.stopwords;
    final corpus = <List<String>>[];
    for (final s in sents) {
      corpus.add(sw.filterStop(await seg_mod.seg(s)));
    }
    final rank = KeywordTextRank(corpus);
    rank.solve();
    final ret = rank.topIndex(limit);
    if (merge) {
      return SimpleMerge(doc, ret).merge();
    }
    return ret;
  }

  /// Traditional-to-Simplified Chinese conversion.
  Future<String> get han async => normal_zh.zh2hans(doc);

  /// Pinyin readings for each Han character; non-Han characters pass through.
  Future<List<String>> get pinyin async => normal_py.getPinyin(doc);
}
