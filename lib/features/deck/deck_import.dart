import 'dart:convert';

/// Supported delimiters when parsing imported card files.
enum CardDelimiter {
  tab('\t', 'タブ区切り'),
  comma(',', 'カンマ区切り'),
  semicolon(';', 'セミコロン区切り'),
  pipe('|', 'パイプ区切り');

  const CardDelimiter(this.value, this.label);

  final String value;
  final String label;
}

/// A pair of strings parsed from a single line.
class ImportedCard {
  const ImportedCard({required this.front, required this.back});
  final String front;
  final String back;
}

/// Parses raw file content into front/back pairs using [delimiter].
///
/// - Lines starting with `#` are treated as comments and skipped (Anki convention).
/// - Empty lines are skipped.
/// - Lines with no delimiter are skipped (need at least 2 columns).
/// - Only the first two columns are used; extra columns are ignored.
List<ImportedCard> parseImportedCards(String content, CardDelimiter delimiter) {
  final result = <ImportedCard>[];
  for (final raw in const LineSplitter().convert(content)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) continue;
    final parts = line.split(delimiter.value);
    if (parts.length < 2) continue;
    final front = parts[0].trim();
    final back = parts[1].trim();
    if (front.isEmpty || back.isEmpty) continue;
    result.add(ImportedCard(front: front, back: back));
  }
  return result;
}

/// Detects the most likely delimiter by counting lines that contain it.
CardDelimiter detectDelimiter(String content) {
  final sample =
      const LineSplitter().convert(content).take(50).toList();
  CardDelimiter best = CardDelimiter.tab;
  int bestCount = -1;
  for (final d in CardDelimiter.values) {
    final count = sample.where((l) => l.contains(d.value)).length;
    if (count > bestCount) {
      best = d;
      bestCount = count;
    }
  }
  return best;
}
