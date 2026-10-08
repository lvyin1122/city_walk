const List<String> travelKeywords = [
  '🏃 探险',
  '🏙️ 街头文化',
  '🎉 独特体验',
  '🏛️ 地标',
  '🌆 本地氛围',
  '🎭 文化',
  '🌿 自然',
  '🍽️ 美食',
  '🗿 历史遗迹',
];

final RegExp _keywordSeparators = RegExp(r'[,，、;；\n]');

/// Splits free-text keywords typed by the user.
///
/// Accepts the separators a Chinese or Latin keyboard naturally produces:
/// half-width and full-width commas, the enumeration comma (、), semicolons
/// and line breaks.
List<String> parseCustomKeywords(String input) {
  return input
      .split(_keywordSeparators)
      .map((keyword) => keyword.trim())
      .where((keyword) => keyword.isNotEmpty)
      .toList();
}
