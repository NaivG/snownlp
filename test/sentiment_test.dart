import 'dart:convert';
import 'dart:io';

import 'package:snownlp/snownlp.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final golden = json.decode(
    File(p.join('test', 'golden', 'sentiment.json')).readAsStringSync(),
  ) as Map<String, dynamic>;

  for (final entry in golden.entries) {
    test('sentiment: ${entry.key}', () async {
      final expected = (entry.value as num).toDouble();
      expect(await SnowNLP(entry.key).sentiments, closeTo(expected, 1e-9));
    });
  }

  test('strong positive phrase scores above 0.5', () async {
    expect(await SnowNLP('我喜欢这本书').sentiments, greaterThan(0.5));
  });

  test('negative phrase scores below 0.5', () async {
    expect(await SnowNLP('这家店太糟糕了').sentiments, lessThan(0.5));
    expect(await SnowNLP('质量差').sentiments, lessThan(0.5));
  });
}
