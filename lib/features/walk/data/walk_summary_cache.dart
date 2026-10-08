import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the AI-written story of each walk on the device.
///
/// The backend writes a new story on every request, which is slow, costs a
/// language-model call and gives a different text each time. A finished walk
/// should keep the story it got.
class WalkSummaryCache {
  static String _key(String walkId) => 'walk_summary_$walkId';

  Future<String?> read(String walkId) async {
    final prefs = await SharedPreferences.getInstance();
    final summary = prefs.getString(_key(walkId));
    return summary == null || summary.isEmpty ? null : summary;
  }

  Future<void> write(String walkId, String summary) async {
    if (summary.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(walkId), summary);
  }
}
