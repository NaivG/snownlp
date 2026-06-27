// Smoke test: read each .bin file and print a summary.
import 'package:path/path.dart' as p;
import 'package:snownlp/src/utils/binary_format.dart';

void main() {
  final dataDir = p.join('lib', 'src', 'data');
  print('Reading .bin files from $dataDir');

  // sentiment
  {
    final gz = BinaryFormat.readPayloadFromFile(
        p.join(dataDir, 'sentiment.bin'), BinaryFormat.typeSentiment);
    final d = BinaryFormat.readSentiment(gz);
    print('sentiment: total=${d.total} classes=${d.classes.keys} '
        'keys=${d.classes.map((k, v) => MapEntry(k, v.d.length))}');
  }

  // seg
  {
    final gz = BinaryFormat.readPayloadFromFile(
        p.join(dataDir, 'seg.bin'), BinaryFormat.typeSeg);
    final d = BinaryFormat.readSeg(gz);
    print('seg: l1=${d.l1} l2=${d.l2} l3=${d.l3} '
        'status=${d.status} sizes={'
        'uni: ${d.uni.d.length}, '
        'bi: ${d.bi.d.length}, '
        'tri: ${d.tri.d.length}}');
  }

  // tag
  {
    final gz = BinaryFormat.readPayloadFromFile(
        p.join(dataDir, 'tag.bin'), BinaryFormat.typeTag);
    final d = BinaryFormat.readTag(gz);
    print('tag: N=${d.n} status.len=${d.status.length} '
        'prob={wd: ${d.wd.d.length}, eos: ${d.eos.d.length}, '
        'eosd: ${d.eosd.d.length}, uni: ${d.uni.d.length}, '
        'bi: ${d.bi.d.length}, tri: ${d.tri.d.length}} '
        'word=${d.word.length} trans=${d.trans.length}');
  }

  // stopwords
  {
    final gz = BinaryFormat.readPayloadFromFile(
        p.join(dataDir, 'stopwords.bin'), BinaryFormat.typeStopwords);
    final d = BinaryFormat.readStopwords(gz);
    print('stopwords: ${d.length} words');
  }

  // zh2hans
  {
    final gz = BinaryFormat.readPayloadFromFile(
        p.join(dataDir, 'zh2hans.bin'), BinaryFormat.typeZh2Hans);
    final d = BinaryFormat.readZh2Hans(gz);
    print('zh2hans: ${d.length} mappings');
  }

  // pinyin
  {
    final gz = BinaryFormat.readPayloadFromFile(
        p.join(dataDir, 'pinyin.bin'), BinaryFormat.typePinyin);
    final d = BinaryFormat.readPinyin(gz);
    final maxReadings = d
        .map((e) => e.pinyin.length)
        .fold<int>(0, (a, b) => a > b ? a : b);
    print('pinyin: ${d.length} entries, max readings=$maxReadings');
  }

  print('All .bin files read successfully.');
}
