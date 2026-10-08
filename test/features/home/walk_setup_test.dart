import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/features/home/keywords.dart';
import 'package:mambo/features/home/walk_setup.dart';

void main() {
  Future<void> pumpSetup(
    WidgetTester tester, {
    String? userName,
    List<bool>? selected,
    double minutes = 30,
    ValueChanged<List<bool>>? onKeywordsChanged,
    ValueChanged<List<String>>? onCustomKeywordsChanged,
    VoidCallback? onGenerate,
    VoidCallback? onStartFreeRecord,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalkSetup(
            selectedKeywords:
                selected ?? List<bool>.filled(travelKeywords.length, false),
            sliderValue: minutes,
            userName: userName,
            onKeywordsChanged: onKeywordsChanged ?? (_) {},
            onSliderChanged: (_) {},
            onCustomKeywordsChanged: onCustomKeywordsChanged ?? (_) {},
            onGenerate: onGenerate ?? () {},
            onStartFreeRecord: onStartFreeRecord,
          ),
        ),
      ),
    );
  }

  testWidgets('greets by name and never shows "null"', (tester) async {
    await pumpSetup(tester, userName: '小明');
    expect(find.text('欢迎，小明！'), findsOneWidget);

    await pumpSetup(tester);
    expect(find.text('欢迎！'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('has an explicit button that starts generation', (tester) async {
    var generated = 0;
    await pumpSetup(tester, onGenerate: () => generated++);

    await tester.ensureVisible(find.text('生成路线'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生成路线'));
    expect(generated, 1);
  });

  testWidgets('reports a new keyword selection without mutating the input', (
    tester,
  ) async {
    final original = List<bool>.filled(travelKeywords.length, false);
    List<bool>? reported;
    await pumpSetup(
      tester,
      selected: original,
      onKeywordsChanged: (value) => reported = value,
    );

    await tester.tap(find.text(travelKeywords[2]));
    expect(reported, isNotNull);
    expect(reported![2], isTrue);
    expect(original.every((selected) => !selected), isTrue);
  });

  testWidgets('parses custom keywords typed with Chinese punctuation', (
    tester,
  ) async {
    List<String>? reported;
    await pumpSetup(tester, onCustomKeywordsChanged: (value) => reported = value);

    await tester.enterText(find.byType(TextField), '咖啡、书店，夜景');
    expect(reported, ['咖啡', '书店', '夜景']);
  });

  testWidgets('shows the free-record entry only when a handler is given', (
    tester,
  ) async {
    await pumpSetup(tester);
    expect(find.text('不需要路线？直接开始记录'), findsNothing);

    var started = 0;
    await pumpSetup(tester, onStartFreeRecord: () => started++);
    await tester.ensureVisible(find.text('不需要路线？直接开始记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('不需要路线？直接开始记录'));
    expect(started, 1);
  });

  testWidgets('duration slider cannot go below the minimum', (tester) async {
    await pumpSetup(tester, minutes: minWalkMinutes);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, minWalkMinutes);
    expect(slider.min, greaterThan(0));
  });
}
