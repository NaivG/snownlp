// Convert the JSON models produced by `tool/export_models.py` into the
// compact gzipped-binary format consumed by the Dart runtime.
//
// Usage (from project root):
//   dart run tool/build_models.dart
//
// Reads from lib/src/data/*.json and writes lib/src/data/*.bin.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:snownlp/src/utils/binary_format.dart';

final _dataDir = p.join('lib', 'src', 'data');

Map<String, dynamic> _readJson(String name) {
  final file = File(p.join(_dataDir, '$name.json'));
  if (!file.existsSync()) {
    stderr.writeln('snownlp: missing ${file.path}. '
        'Run `python tool/export_models.py` first.');
    exit(1);
  }
  return json.decode(file.readAsStringSync(encoding: utf8))
      as Map<String, dynamic>;
}

void _writeBin(String name, int fileType, Uint8List payload) {
  final out = File(p.join(_dataDir, '$name.bin'));
  final full = BinaryFormat.writeFile(fileType, payload);
  out.writeAsBytesSync(full);
  final jsonSize =
      File(p.join(_dataDir, '$name.json')).lengthSync();
  final ratio = jsonSize == 0 ? 0 : (full.length / jsonSize);
  print('  ${name.padRight(22)} '
      'json=${jsonSize.toString().padLeft(10)}  '
      'bin=${full.length.toString().padLeft(10)}  '
      'ratio=${(ratio * 100).toStringAsFixed(1)}%');
}

BaseProbData _baseProb(Map<String, dynamic> j) {
  return BaseProbData(
    total: (j['total'] as num?)?.toDouble() ?? 0,
    none: (j['none'] as num?)?.toInt() ?? 0,
    d: ((j['d'] as Map?)?.cast<String, dynamic>() ?? const {})
        .map((k, v) => MapEntry(k, (v as num).toInt())),
  );
}

void buildSentiment() {
  final j = _readJson('sentiment');
  final classes = <String, ClassProb>{};
  for (final entry
      in (j['d'] as Map).cast<String, dynamic>().entries) {
    final p = entry.value as Map;
    classes[entry.key] = ClassProb(
      total: (p['total'] as num).toDouble(),
      none: (p['none'] as num).toInt(),
      d: (p['d'] as Map)
          .cast<String, dynamic>()
          .map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }
  _writeBin('sentiment', BinaryFormat.typeSentiment,
      BinaryFormat.writeSentiment(SentimentData(
        total: (j['total'] as num).toDouble(),
        classes: classes,
      )));
}

void buildSeg() {
  final j = _readJson('seg');
  _writeBin('seg', BinaryFormat.typeSeg,
      BinaryFormat.writeSeg(SegData(
        l1: (j['l1'] as num).toDouble(),
        l2: (j['l2'] as num).toDouble(),
        l3: (j['l3'] as num).toDouble(),
        status: (j['status'] as List).cast<String>(),
        uni: _baseProb((j['uni'] as Map).cast<String, dynamic>()),
        bi: _baseProb((j['bi'] as Map).cast<String, dynamic>()),
        tri: _baseProb((j['tri'] as Map).cast<String, dynamic>()),
      )));
}

void buildTag() {
  final j = _readJson('tag');
  final word = <String, List<String>>{};
  for (final entry
      in (j['word'] as Map).cast<String, dynamic>().entries) {
    word[entry.key] = (entry.value as List).cast<String>();
  }
  final trans = <String, double>{};
  for (final entry
      in (j['trans'] as Map).cast<String, dynamic>().entries) {
    trans[entry.key] = (entry.value as num).toDouble();
  }
  _writeBin('tag', BinaryFormat.typeTag,
      BinaryFormat.writeTag(TagData(
        n: (j['N'] as num).toInt(),
        l1: (j['l1'] as num).toDouble(),
        l2: (j['l2'] as num).toDouble(),
        l3: (j['l3'] as num).toDouble(),
        status: (j['status'] as List).cast<String>(),
        wd: _baseProb((j['wd'] as Map).cast<String, dynamic>()),
        eos: _baseProb((j['eos'] as Map).cast<String, dynamic>()),
        eosd: _baseProb((j['eosd'] as Map).cast<String, dynamic>()),
        uni: _baseProb((j['uni'] as Map).cast<String, dynamic>()),
        bi: _baseProb((j['bi'] as Map).cast<String, dynamic>()),
        tri: _baseProb((j['tri'] as Map).cast<String, dynamic>()),
        word: word,
        trans: trans,
      )));
}

void buildStopwords() {
  final j = _readJson('stopwords');
  _writeBin('stopwords', BinaryFormat.typeStopwords,
      BinaryFormat.writeStopwords((j['words'] as List).cast<String>()));
}

void buildZh2Hans() {
  final j = _readJson('zh2hans');
  _writeBin('zh2hans', BinaryFormat.typeZh2Hans,
      BinaryFormat.writeZh2Hans((j['map'] as Map).cast<String, String>()));
}

void buildPinyin() {
  final j = _readJson('pinyin');
  final entries = (j['entries'] as List)
      .cast<Map<String, dynamic>>()
      .map((e) => PinyinEntry(
            hanzi: e['h'] as String,
            pinyin: (e['p'] as List).cast<String>(),
          ))
      .toList();
  _writeBin('pinyin', BinaryFormat.typePinyin,
      BinaryFormat.writePinyin(entries));
}

void main(List<String> args) {
  final dataDir = Directory(_dataDir);
  if (!dataDir.existsSync()) {
    stderr.writeln('snownlp: missing data directory ${dataDir.path}');
    exit(1);
  }
  print('Building ${dataDir.path}/*.bin from .json sources...');
  buildSentiment();
  buildSeg();
  buildTag();
  buildZh2Hans();
  buildPinyin();
  buildStopwords();
  print('Done.');
}
