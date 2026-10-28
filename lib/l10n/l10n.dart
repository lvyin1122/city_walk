import 'package:flutter/material.dart';
import 'package:mambo/l10n/app_localizations.dart';
export 'package:mambo/l10n/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

class AppL10n {
  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  static String intlLocaleName(Locale locale) {
    return locale.languageCode == 'zh' ? 'zh_CN' : 'en_US';
  }
}
