import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/app/error_reporting.dart';

class _Reporter implements ErrorReporter {
  Object? error;
  StackTrace? stack;
  String? context;

  @override
  void report(Object error, StackTrace? stack, {String? context}) {
    this.error = error;
    this.stack = stack;
    this.context = context;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final flutterHandler = FlutterError.onError;
    final platformHandler = PlatformDispatcher.instance.onError;
    final widgetBuilder = ErrorWidget.builder;
    addTearDown(() {
      FlutterError.onError = flutterHandler;
      PlatformDispatcher.instance.onError = platformHandler;
      ErrorWidget.builder = widgetBuilder;
    });
  });

  test('Flutter errors retain their stack and context', () {
    final reporter = _Reporter();
    final error = StateError('widget failed');
    final stack = StackTrace.current;
    installErrorHandlers(reporter);

    FlutterError.onError!(FlutterErrorDetails(
      exception: error,
      stack: stack,
      context: ErrorDescription('building the walk'),
      silent: true,
    ));

    expect(reporter.error, same(error));
    expect(reporter.stack, same(stack));
    expect(reporter.context, 'building the walk');
  });

  test('platform errors reach the reporter and are handled', () {
    final reporter = _Reporter();
    final error = StateError('async failed');
    final stack = StackTrace.current;
    installErrorHandlers(reporter);

    expect(PlatformDispatcher.instance.onError!(error, stack), isTrue);
    expect(reporter.error, same(error));
    expect(reporter.stack, same(stack));
  });

  testWidgets('the fallback renders a readable message', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppErrorWidget()));
    expect(find.text('这里出了点问题'), findsOneWidget);
  });

  test('debug builds retain the existing error widget builder', () {
    final builder = ErrorWidget.builder;
    installErrorHandlers(_Reporter());
    expect(ErrorWidget.builder, same(builder));
  });
}
