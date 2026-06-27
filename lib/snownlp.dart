/// Public API for `package:snownlp`. Re-exports the facade plus the
/// lower-level modules most users will want to reach for explicitly.
library;

export 'src/bayes/bayes.dart' show Bayes;
export 'src/bayes/sentiment.dart' show Sentiment, sentiment;
export 'src/config.dart';
export 'src/normal/pinyin.dart' show getPinyin;
export 'src/normal/sentences.dart' show getSentences, reZh, splitKeeping;
export 'src/normal/stopwords.dart' show stopwords;
export 'src/normal/zh.dart' show zh2hans;
export 'src/segmentation/character_model.dart' show CharacterBasedGenerativeModel;
export 'src/segmentation/segmenter.dart' show seg;
export 'src/sim/bm25.dart' show BM25;
export 'src/snow_nlp.dart' show SnowNLP;
export 'src/summary/textrank.dart' show TextRank, KeywordTextRank;
export 'src/summary/words_merge.dart' show SimpleMerge;
export 'src/tag/tnt.dart' show TnT, tag, tagger;
export 'src/utils/frequency.dart';
export 'src/utils/trie.dart';