import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/core/api/api_exception.dart';
import 'package:mambo/features/account/delete_account_dialog.dart';
import 'package:mambo/theme/app_theme.dart';

Future<void> openDialog(
  WidgetTester tester,
  Future<void> Function() onDelete,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => DeleteAccountDialog(onDelete: onDelete),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester) async {
  await tester.tap(find.text('继续'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '删除');
  await tester.pump();
}

void main() {
  testWidgets('requires a second step and an exact, trimmed confirmation', (
    tester,
  ) async {
    var deleted = false;
    await openDialog(tester, () async => deleted = true);
    expect(find.text('删除后，你的漫步记录、照片和轨迹都会被永久删除，无法恢复。'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(find.text('请输入「删除」确认'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '永久删除'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '永久删除'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), ' 删除 ');
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '永久删除'))
          .onPressed,
      isNotNull,
    );
    expect(deleted, isFalse);
    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
    expect(find.byType(DeleteAccountDialog), findsNothing);
  });

  testWidgets('a failed delete shows its readable error and enables retry', (
    tester,
  ) async {
    await openDialog(
      tester,
      () async => throw const ApiNetworkException('offline'),
    );
    await confirm(tester);
    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountDialog), findsOneWidget);
    expect(
      find.text(const ApiNetworkException('offline').userMessage),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '永久删除'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('pending deletion disables controls and blocks system back', (
    tester,
  ) async {
    final pending = Completer<void>();
    await openDialog(tester, () => pending.future);
    await confirm(tester);
    await tester.tap(find.text('永久删除'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '永久删除'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
          .onPressed,
      isNull,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(DeleteAccountDialog), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountDialog), findsNothing);
  });

  testWidgets('cancel never invokes deletion', (tester) async {
    var deleted = false;
    await openDialog(tester, () async => deleted = true);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(deleted, isFalse);
    expect(find.byType(DeleteAccountDialog), findsNothing);
  });
}
