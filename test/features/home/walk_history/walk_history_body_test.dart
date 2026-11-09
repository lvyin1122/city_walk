import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/features/home/walk_history/walk_history.dart';
import 'package:mambo/features/walk/domain/walk.dart';

void main() {
  Future<int Function()> pumpBody(
    WidgetTester tester, {
    List<Walk> walks = const [],
    String? error,
  }) async {
    var refreshed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalkHistoryBody(
            walks: walks,
            error: error,
            onRefresh: () async => refreshed++,
            onRetry: () {},
          ),
        ),
      ),
    );
    return () => refreshed;
  }

  Future<void> pullDown(WidgetTester tester) async {
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty history can be pulled to refresh', (tester) async {
    final refreshed = await pumpBody(tester);
    expect(find.textContaining('还没有完成的步行'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    await pullDown(tester);
    expect(refreshed(), 1);
  });

  testWidgets('a failed load can be pulled to refresh and keeps retry', (
    tester,
  ) async {
    final refreshed = await pumpBody(tester, error: '加载已完成的步行失败');
    expect(find.text('重试'), findsOneWidget);
    await pullDown(tester);
    expect(refreshed(), 1);
  });

  testWidgets('a short list can be pulled to refresh', (tester) async {
    final refreshed = await pumpBody(
      tester,
      walks: const [Walk(id: 'w1', title: '海边漫步')],
    );
    expect(find.text('海边漫步'), findsOneWidget);
    await pullDown(tester);
    expect(refreshed(), 1);
  });
}
