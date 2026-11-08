import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the AI-written story of each walk on the device.
///
/// The backend writes a new story on every request, which is slow, costs a
/// language-model call and gives a different text each time. A finished walk
/// should keep the story it got.
class WalkSummaryCache {
  static String _key(String walkId) => 'walk_summary_$walkId';

  /// Texts the backend returns when it could not write a story
  /// (`fallback_summary` in mambo_backend/app/llm/walk_summary.py). It does
  /// not save them, so asking again later can still give the real story.
  static const _fallbacks = {
    '谢谢你今天和 Mambo 一起漫步，路线和照片都已保存。',
    '謝謝你今天和 Mambo 一起漫步，路線和照片都已保存。',
    'Thanks for walking with Mambo today. Your route and photos are saved.',
  };

  static bool _keep(String? summary) =>
      summary != null && summary.isNotEmpty && !_fallbacks.contains(summary);

  Future<String?> read(String walkId) async {
    final prefs = await SharedPreferences.getInstance();
    final summary = prefs.getString(_key(walkId));
    return _keep(summary) ? summary : null;
  }

  Future<void> write(String walkId, String summary) async {
    if (!_keep(summary)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(walkId), summary);
  }
}
