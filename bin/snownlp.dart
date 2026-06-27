// ignore_for_file: avoid_print

import 'dart:io';

import 'package:snownlp/snownlp.dart';

const _usage = '''\
snownlp — a Simplified Chinese NLP CLI

Usage:
  dart run bin/snownlp.dart <command> [text ...]

Commands:
  sentiment <text>   Print P(positive) in [0, 1].
  seg       <text>   Print the CBGM-segmented tokens, space-separated.
  tag       <text>   Print word/tag pairs, one per line.
  han       <text>   Print the simplified-Chinese conversion.
  pinyin    <text>   Print the pinyin readings, space-separated.
  summary   <text>   Print the top-3 sentences chosen by TextRank.
  keywords  <text>   Print the top-5 keywords chosen by KeywordTextRank.
  words     <text>   Alias for `seg`.
  help                Show this message.
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == 'help' || args.first == '-h') {
    stdout.writeln(_usage);
    return;
  }
  final command = args.first;
  final rest = args.sublist(1);
  final text = rest.join(' ');

  switch (command) {
    case 'sentiment':
      _print((await SnowNLP(text).sentiments).toStringAsFixed(6));
    case 'seg':
    case 'words':
      _print((await seg(text)).join(' '));
    case 'tag':
      final s = SnowNLP(text);
      final pairs = await s.tags;
      for (final pair in pairs) {
        _print('${pair.$1}\t${pair.$2}');
      }
    case 'han':
      _print(await SnowNLP(text).han);
    case 'pinyin':
      _print((await SnowNLP(text).pinyin).join(' '));
    case 'summary':
      for (final s in await SnowNLP(text).summary(limit: 3)) {
        _print('- $s');
      }
    case 'keywords':
      for (final k in await SnowNLP(text).keywords(limit: 5)) {
        _print('- $k');
      }
    default:
      stderr.writeln('Unknown command: $command');
      stderr.writeln(_usage);
      exitCode = 2;
  }
}

void _print(String s) {
  stdout.writeln(s);
}
