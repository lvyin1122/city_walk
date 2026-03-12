import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local quota for scrapbook image generation: 2 per day.
/// Uses SharedPreferences. Resets at midnight (local date).
class ScrapbookQuotaService {
  static const String _keyDate = 'scrapbook_gen_date';
  static const String _keyCount = 'scrapbook_gen_count';
  static const int _maxPerDay = 2;

  static String _todayKey() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  /// Returns true if the user can generate a scrapbook image today.
  static Future<bool> canGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_keyDate);
    final today = _todayKey();
    if (savedDate != today) {
      return true; // New day, full quota
    }
    final count = prefs.getInt(_keyCount) ?? 0;
    return count < _maxPerDay;
  }

  /// Records a generation. Call after a successful generation.
  static Future<void> recordGeneration() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final savedDate = prefs.getString(_keyDate);
    int count;
    if (savedDate != today) {
      count = 1; // New day, reset
    } else {
      count = (prefs.getInt(_keyCount) ?? 0) + 1;
    }
    await prefs.setString(_keyDate, today);
    await prefs.setInt(_keyCount, count);
  }

  /// Returns how many generations remain for today.
  static Future<int> getRemainingToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_keyDate);
    final today = _todayKey();
    if (savedDate != today) {
      return _maxPerDay;
    }
    final count = prefs.getInt(_keyCount) ?? 0;
    return (_maxPerDay - count).clamp(0, _maxPerDay);
  }
}
