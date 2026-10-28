import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguageMode { system, english, chinese }

class LocalePreferenceService {
  static const String _languageModeKey = 'app_language_mode';

  Future<AppLanguageMode> getLanguageMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_languageModeKey);
    switch (mode) {
      case 'english':
        return AppLanguageMode.english;
      case 'chinese':
        return AppLanguageMode.chinese;
      default:
        return AppLanguageMode.system;
    }
  }

  Future<void> setLanguageMode(AppLanguageMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageModeKey, _toStorageValue(mode));
  }

  String _toStorageValue(AppLanguageMode mode) {
    switch (mode) {
      case AppLanguageMode.english:
        return 'english';
      case AppLanguageMode.chinese:
        return 'chinese';
      case AppLanguageMode.system:
        return 'system';
    }
  }
}
