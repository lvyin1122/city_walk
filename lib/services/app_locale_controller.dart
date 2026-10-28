import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'locale_preference_service.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController(this._preferenceService);

  final LocalePreferenceService _preferenceService;

  AppLanguageMode _mode = AppLanguageMode.system;

  AppLanguageMode get mode => _mode;

  Locale? get userPreferredLocale {
    switch (_mode) {
      case AppLanguageMode.system:
        return null;
      case AppLanguageMode.english:
        return const Locale('en');
      case AppLanguageMode.chinese:
        return const Locale('zh');
    }
  }

  Future<void> load() async {
    _mode = await _preferenceService.getLanguageMode();
    await _syncIntlLocale();
    notifyListeners();
  }

  Future<void> setMode(AppLanguageMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    await _preferenceService.setLanguageMode(mode);
    await _syncIntlLocale();
    notifyListeners();
  }

  Locale resolveLocale(Locale? systemLocale) {
    if (_mode == AppLanguageMode.english) {
      return const Locale('en');
    }
    if (_mode == AppLanguageMode.chinese) {
      return const Locale('zh');
    }

    if (systemLocale == null) {
      return const Locale('en');
    }
    return systemLocale.languageCode.toLowerCase().startsWith('zh')
        ? const Locale('zh')
        : const Locale('en');
  }

  Future<void> onSystemLocaleChanged(List<Locale>? locales) async {
    if (_mode != AppLanguageMode.system) return;
    await _syncIntlLocale(locales?.first);
    notifyListeners();
  }

  Future<void> _syncIntlLocale([Locale? systemLocale]) async {
    final locale = resolveLocale(systemLocale ?? PlatformDispatcher.instance.locale);
    final localeName = locale.languageCode == 'zh' ? 'zh_CN' : 'en_US';
    await initializeDateFormatting(localeName);
    Intl.defaultLocale = localeName;
  }
}
