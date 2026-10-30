import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/features/walk/domain/walk.dart';
import 'package:mambo/features/walk/widgets/walk_controls.dart';
import 'package:mambo/features/walk/widgets/walk_panels.dart';
import 'package:mambo/theme/app_theme.dart';

const _stop = WalkStop(index: 0, name: '附近公园', position: GeoPoint(22, 114));
const _task = WalkTask(description: '找一片树叶，拍下它的纹理', photosRequired: 3);
void _nothing() {}

Future<void> _pump(WidgetTester tester, Widget child, {double scale = 1}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(size: const Size(360, 640), textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(16), child: child,
      ))),
    ),
  ));
}

TaskCard _taskCard({WalkTask? task = _task, bool loading = false,
    bool uploading = false, VoidCallback? onReport}) => TaskCard(
  task: task, loading: loading, uploading: uploading, photosFulfilled: 1,
  onAddPhoto: _nothing, onNewTask: _nothing, onReport: onReport,
);

WalkActionBar _actions({bool marked = false, bool uploading = false,
    VoidCallback? onPause, VoidCallback? onSurprise, VoidCallback? onFinish}) => WalkActionBar(
  surpriseMarked: marked, uploadingSurprise: uploading,
  onPause: onPause ?? _nothing, onSurprise: onSurprise ?? _nothing,
  onFinish: onFinish ?? _nothing,
);

void main() {
  testWidgets('next stop shows its number, walking time and unknown distance', (tester) async {
    await _pump(tester, const NextStopCard(stop: _stop, number: 2, distanceMeters: 320));
    expect(find.text('下一站 · 第 2 站'), findsOneWidget);
    expect(find.text('320 米 · 步行约 4 分钟'), findsOneWidget);
    await _pump(tester, const NextStopCard(stop: _stop));
    expect(find.text('正在定位…'), findsOneWidget);
    await _pump(tester, const NextStopCard(stop: _stop, distanceMeters: 4));
    expect(find.text('10 米 · 就在附近'), findsOneWidget);
  });

  testWidgets('check-in takes precedence over directions and calls the action', (tester) async {
    var checkedIn = 0;
    var navigated = 0;
    await _pump(tester, NextStopCard(stop: _stop, canCheckIn: true,
      onCheckIn: () => checkedIn++, onNavigate: () => navigated++));
    expect(find.text('导航'), findsNothing);
    expect(tester.getSize(find.widgetWithText(FilledButton, '我到了')).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('我到了'));
    expect(checkedIn, 1);
    await _pump(tester, NextStopCard(stop: _stop, onNavigate: () => navigated++));
    expect(tester.getSize(find.widgetWithText(OutlinedButton, '导航')).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('导航'));
    expect(navigated, 1);
  });

  testWidgets('completed route has no action and blank names have a fallback', (tester) async {
    await _pump(tester, const NextStopCard(stop: null));
    expect(find.text('所有地点都到达了'), findsOneWidget);
    expect(find.byType(ButtonStyleButton), findsNothing);
    await _pump(tester, const NextStopCard(stop: WalkStop(index: 1, name: '', position: GeoPoint(0, 0))));
    expect(find.text('未命名地点'), findsOneWidget);
  });

  testWidgets('camera action is at least 56 high and disabled without a task', (tester) async {
    await _pump(tester, _taskCard(task: null));
    final button = find.widgetWithText(FilledButton, '拍任务照片');
    expect(tester.getSize(button).height, greaterThanOrEqualTo(56));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await _pump(tester, _taskCard());
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(find.text('1/3 张'), findsOneWidget);
    await _pump(tester, _taskCard(uploading: true));
    expect(find.text('正在查看照片…'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });

  testWidgets('description expands and collapses, and a new task starts collapsed', (tester) async {
    await _pump(tester, _taskCard());
    final description = find.text(_task.description);
    expect(tester.widget<Text>(description).maxLines, 2);
    await tester.tap(description);
    await tester.pump();
    expect(tester.widget<Text>(description).maxLines, isNull);
    await tester.tap(description);
    await tester.pump();
    expect(tester.widget<Text>(description).maxLines, 2);
    await tester.tap(description);
    await tester.pump();
    await _pump(tester, _taskCard(task: const WalkTask(description: '新的任务')));
    expect(tester.widget<Text>(find.text('新的任务')).maxLines, 2);
  });

  testWidgets('report action is optional and loading disables task changes', (tester) async {
    await _pump(tester, _taskCard());
    expect(find.byTooltip('报告这个任务'), findsNothing);
    await _pump(tester, _taskCard(task: null, loading: true, onReport: _nothing));
    expect(find.byTooltip('报告这个任务'), findsOneWidget);
    expect(find.text('正在想一个新任务…'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byWidgetPredicate((widget) => widget is IconButton && widget.tooltip == '换一个任务')).onPressed, isNull);
  });

  testWidgets('action bar has 48-high buttons, callbacks and surprise states', (tester) async {
    var paused = 0;
    var surprised = 0;
    var finished = 0;
    await _pump(tester, _actions(onPause: () => paused++, onSurprise: () => surprised++, onFinish: () => finished++));
    for (final element in find.byType(OutlinedButton).evaluate()) {
      expect(tester.getSize(find.byWidget(element.widget)).height, greaterThanOrEqualTo(48));
    }
    await tester.tap(find.text('暂停'));
    await tester.tap(find.text('这里让我惊喜'));
    await tester.tap(find.text('结束'));
    expect([paused, surprised, finished], [1, 1, 1]);
    await _pump(tester, _actions(marked: true));
    expect(find.text('已记下惊喜'), findsOneWidget);
    await _pump(tester, _actions(uploading: true));
    expect(find.text('上传中…'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '上传中…')).onPressed, isNull);
  });

  testWidgets('large text and long names/tasks fit a 360-wide phone', (tester) async {
    final longStop = WalkStop(index: 0, name: '长' * 40, position: const GeoPoint(22, 114));
    final longTask = WalkTask(description: '长' * 150, photosRequired: 3);
    await _pump(tester, Column(children: [
      MapPanel(child: NextStopCard(stop: longStop, number: 1, distanceMeters: 320, onNavigate: _nothing)),
      MapPanel(child: _taskCard(task: longTask, onReport: _nothing)),
      _actions(),
    ]), scale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon controls have hit areas of at least 48 square', (tester) async {
    await _pump(tester, Column(children: [
      _taskCard(onReport: _nothing),
      const MapButton(icon: Icons.info_outline, tooltip: '使用说明', onPressed: _nothing),
    ]));
    for (final element in find.byType(IconButton).evaluate()) {
      final size = tester.getSize(find.byWidget(element.widget));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(tester.getSize(find.byType(MapButton)), const Size(48, 48));
  });

  testWidgets('location notice exposes the message and retry action', (tester) async {
    var retried = false;
    await _pump(tester, LocationNotice(message: '定位未开启', actionLabel: '重试', onAction: () => retried = true));
    expect(find.text('定位未开启'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retried, isTrue);
  });

  testWidgets('stats include readable stop count and semantics', (tester) async {
    await _pump(tester, const WalkStatsLine(elapsed: Duration(minutes: 4), distanceKm: 1.2, stops: '1/3'));
    expect(find.text('1/3'), findsOneWidget);
    expect(find.bySemanticsLabel('地点 1/3'), findsOneWidget);
    expect(tester.widget<Text>(find.text('1/3')).style!.fontWeight, FontWeight.w400);
  });
}
