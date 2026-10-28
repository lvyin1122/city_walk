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

const List<String> travelKeywordsEn = [
  '🏃 Adventure',
  '🏙️ Street Culture',
  '🎉 Unique Experiences',
  '🏛️ Landmarks',
  '🌆 Local Vibes',
  '🎭 Culture',
  '🌿 Nature',
  '🍽️ Food',
  '🗿 Historical Sites',
];

List<String> travelKeywordLabels(bool isChinese) {
  return isChinese ? travelKeywords : travelKeywordsEn;
}