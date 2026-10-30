import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mambo/core/api/api_client.dart';
import 'package:mambo/core/api/api_exception.dart';
import 'package:mambo/features/report/report_dialog.dart';
import 'package:mambo/features/report/report_repository.dart';
import 'package:mambo/features/walk/widgets/summary_sections.dart';
import 'package:mambo/services/graphql_service.dart';
import 'package:mambo/theme/app_theme.dart';

typedef SentReport = ({
  ReportKind kind,
  String walkId,
  int? stopIndex,
  String? detail,
});

GraphQLService serviceReturning(Object? payload) => GraphQLService(
  client: ApiClient(
    endpoint: Uri.parse('https://backend.test/graphql'),
    httpClient: MockClient(
      (_) async => http.Response(
        jsonEncode({
          'data': {'reportContent': payload},
        }),
        200,
      ),
    ),
  ),
);

class FakeReportRepository extends ReportRepository {
  FakeReportRepository({this.action}) : super(serviceReturning(null));

  final Future<void> Function()? action;
  SentReport? sent;

  @override
  Future<void> send({
    required ReportKind kind,
    required String walkId,
    int? stopIndex,
    String? detail,
  }) async {
    sent = (kind: kind, walkId: walkId, stopIndex: stopIndex, detail: detail);
    await action?.call();
  }
}

Future<void> openReport(
  WidgetTester tester,
  ReportKind kind,
  FakeReportRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showReportDialog(
              context,
              kind: kind,
              walkId: 'walk-1',
              stopIndex: 2,
              repository: repository,
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

void main() {
  test('report kinds retain the backend wire names', () {
    expect(ReportKind.values.map((kind) => kind.wireName), [
      'place',
      'task',
      'story',
    ]);
  });

  test(
    'repository accepts success and rejects every unsuccessful payload',
    () async {
      await ReportRepository(serviceReturning({'success': true}))
          .send(kind: ReportKind.task, walkId: 'walk');
      for (final payload in [
        null,
        false,
        {'success': false},
        {'success': 'true'},
      ]) {
        await expectLater(
          ReportRepository(serviceReturning(payload))
              .send(kind: ReportKind.story, walkId: 'walk'),
          throwsA(isA<ApiResponseFormatException>()),
        );
      }
    },
  );

  testWidgets('submit is disabled until a reason is selected', (tester) async {
    await openReport(tester, ReportKind.task, FakeReportRepository());
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '提交'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('其他'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '提交'))
          .onPressed,
      isNotNull,
    );
  });

  for (final kind in ReportKind.values) {
    testWidgets('place-only reason is shown appropriately for ${kind.name}', (
      tester,
    ) async {
      await openReport(tester, kind, FakeReportRepository());
      expect(
        find.text('地点不存在、已关闭或不安全'),
        kind == ReportKind.place ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets(
    'success sends the selected reason and note, closes and thanks the user',
    (tester) async {
      final repository = FakeReportRepository();
      await openReport(tester, ReportKind.place, repository);
      await tester.tap(find.text('和实际情况不符'));
      await tester.enterText(find.byType(TextField), '  不在这里  ');
      await tester.tap(find.text('提交'));
      await tester.pumpAndSettle();
      expect(repository.sent, (
        kind: ReportKind.place,
        walkId: 'walk-1',
        stopIndex: 2,
        detail: '和实际情况不符\n不在这里',
      ));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('已收到，谢谢你的反馈'), findsOneWidget);
    },
  );

  testWidgets('network failure keeps the dialog open and allows a retry', (
    tester,
  ) async {
    final repository = FakeReportRepository(
      action: () async => throw const ApiNetworkException('offline'),
    );
    await openReport(tester, ReportKind.story, repository);
    await tester.tap(find.text('其他'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text(const ApiNetworkException('offline').userMessage),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '提交'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('pending submission disables actions and cannot be dismissed', (
    tester,
  ) async {
    final completion = Completer<void>();
    final repository = FakeReportRepository(action: () => completion.future);
    await openReport(tester, ReportKind.task, repository);
    await tester.tap(find.text('其他'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
          .onPressed,
      isNull,
    );
    completion.complete();
    await tester.pumpAndSettle();
    expect(repository.sent?.detail, '其他');
  });

  testWidgets('story reporting is offered only for a loaded story', (
    tester,
  ) async {
    for (final state in [
      (story: 'story', failed: false),
      (story: null, failed: false),
      (story: 'story', failed: true),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: WalkStoryCard(
              story: state.story,
              failed: state.failed,
              onRetry: () {},
              onReport: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('报告这个故事'),
        state.story != null && !state.failed ? findsOneWidget : findsNothing,
      );
    }
  });
}
