/// Regex that matches runs of CJK Unified Ideographs U+4E00–U+9FA5. The
/// same range snownlp uses; characters outside it are split as whitespace.
/// Note: uses a capturing group so :func:`splitKeeping` can preserve
/// matches the way Python's `re.split` does.
final RegExp reZh = RegExp(r'([\u4E00-\u9FA5]+)');

/// Regex matching the sentence delimiters used by snownlp:
/// `，。？！；`.
final RegExp _delimiter = RegExp(r'[，。？！；]');

/// Regex matching line breaks (`\r` or `\n`).
final RegExp _lineBreak = RegExp(r'[\r\n]');

/// Returns true when the regex's source pattern contains at least one
/// unescaped capturing `(` (i.e. *not* `(?:`, `(?=`, `(?!`).
bool _hasCapturingGroup(RegExp re) {
  final src = re.pattern;
  var i = 0;
  while (i < src.length) {
    final c = src[i];
    if (c == r'\') {
      i += 2;
      continue;
    }
    if (c == '[') {
      // skip character class
      i++;
      while (i < src.length && src[i] != ']') {
        if (src[i] == r'\') i++;
        i++;
      }
      i++;
      continue;
    }
    if (c == '(') {
      // Check if it's a non-capturing group.
      if (i + 1 < src.length && src[i + 1] == '?') {
        // (?...), skip
        i += 2;
        continue;
      }
      return true;
    }
    i++;
  }
  return false;
}

/// Splits a string on a regex. When the regex has capturing groups, the
/// matched substrings are preserved in the output (Python `re.split`
/// semantics). Otherwise the matches are discarded like `String.split`.
List<String> splitKeeping(RegExp re, String s) {
  final keep = _hasCapturingGroup(re);
  final parts = <String>[];
  var last = 0;
  for (final m in re.allMatches(s)) {
    if (m.start > last) parts.add(s.substring(last, m.start));
    if (keep) parts.add(m.group(0)!);
    last = m.end;
  }
  if (last < s.length) parts.add(s.substring(last));
  return parts;
}

/// Splits a document into sentences on the same boundary characters that
/// snownlp's `normal.get_sentences` uses.
List<String> getSentences(String doc) {
  final sentences = <String>[];
  for (final line in splitKeeping(_lineBreak, doc)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    for (final sent in splitKeeping(_delimiter, trimmed)) {
      final t = sent.trim();
      if (t.isNotEmpty) sentences.add(t);
    }
  }
  return sentences;
}

/// True if `s` is a run of Han characters (matches `re_zh`).
bool isChinese(String s) => reZh.hasMatch(s) && reZh.matchAsPrefix(s) != null;