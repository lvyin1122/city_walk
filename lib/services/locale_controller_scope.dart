import 'package:flutter/widgets.dart';

import 'app_locale_controller.dart';

class LocaleControllerScope extends InheritedNotifier<AppLocaleController> {
  const LocaleControllerScope({
    super.key,
    required AppLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLocaleController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<LocaleControllerScope>();
    assert(scope != null, 'LocaleControllerScope not found in widget tree.');
    return scope!.notifier!;
  }
}
