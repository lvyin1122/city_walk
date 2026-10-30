import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/features/consent/ai_consent.dart';
import 'package:mambo/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpEntry(
    WidgetTester tester,
    void Function(BuildContext context) request, {
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => request(context),
              child: const Text('Request'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('agreement persists and the next request needs no dialog', (
    tester,
  ) async {
    Future<bool>? result;
    await pumpEntry(tester, (context) => result = ensureAiConsent(context));
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    expect(find.byType(AiConsentDialog), findsOneWidget);

    await tester.tap(find.text('同意并继续'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(await AiConsent.isGranted(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('ai_consent_v1'), isTrue);

    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(AiConsentDialog), findsNothing);
  });

  testWidgets('declining stores nothing and tapping outside cannot dismiss', (
    tester,
  ) async {
    Future<bool>? result;
    await pumpEntry(tester, (context) => result = ensureAiConsent(context));
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.byType(AiConsentDialog), findsOneWidget);

    await tester.tap(find.text('不同意'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    expect(await AiConsent.isGranted(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('ai_consent_v1'), isFalse);
  });

  testWidgets('revocation makes the dialog appear again', (tester) async {
    await AiConsent.grant();
    expect(await AiConsent.isGranted(), isTrue);
    await AiConsent.revoke();
    expect(await AiConsent.isGranted(), isFalse);

    Future<bool>? result;
    await pumpEntry(tester, (context) => result = ensureAiConsent(context));
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    expect(find.byType(AiConsentDialog), findsOneWidget);
    await tester.tap(find.text('不同意'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  for (final action in ['同意并继续', '不同意']) {
    testWidgets('small phone at 1.3 text scale can tap $action', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<bool>? result;
      await pumpEntry(
        tester,
        (context) => result = ensureAiConsent(context),
        scale: 1.3,
      );
      await tester.tap(find.text('Request'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.ensureVisible(find.text(action));
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(await result, action == '同意并继续');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('concurrent entry points share one consent decision', (
    tester,
  ) async {
    Future<bool>? first;
    Future<bool>? second;
    await pumpEntry(tester, (context) {
      first = ensureAiConsent(context);
      second = ensureAiConsent(context);
    });
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    expect(find.byType(AiConsentDialog), findsOneWidget);
    await tester.tap(find.text('同意并继续'));
    await tester.pumpAndSettle();
    expect(await first, isTrue);
    expect(await second, isTrue);
  });

  testWidgets('a disposed entry point cannot open a consent dialog', (
    tester,
  ) async {
    BuildContext? entryContext;
    await pumpEntry(tester, (context) => entryContext = context);
    await tester.tap(find.text('Request'));
    await tester.pumpWidget(const SizedBox());
    expect(await ensureAiConsent(entryContext!), isFalse);
    expect(find.byType(AiConsentDialog), findsNothing);
  });
}
