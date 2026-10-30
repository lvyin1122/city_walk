import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The single entry point for reporting uncaught application errors.
abstract interface class ErrorReporter {
  void report(Object error, StackTrace? stack, {String? context});
}

class DebugErrorReporter implements ErrorReporter {
  @override
  void report(Object error, StackTrace? stack, {String? context}) {
    debugPrint('Unhandled error${context == null ? '' : ' ($context)'}: $error');
    if (stack != null) debugPrintStack(stackTrace: stack);
  }
}

class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({super.key});

  @override
  Widget build(BuildContext context) => const Material(
    child: Center(child: Text('这里出了点问题')),
  );
}

/// Installs handlers before any startup path can build a widget.
void installErrorHandlers(ErrorReporter reporter) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reporter.report(
      details.exception,
      details.stack,
      context: details.context?.toString(),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.report(error, stack);
    return true;
  };
  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const AppErrorWidget();
  }
}
