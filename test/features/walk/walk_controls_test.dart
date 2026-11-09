import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/features/walk/domain/walk.dart';
import 'package:mambo/features/walk/widgets/walk_controls.dart';
import 'package:mambo/features/walk/widgets/walk_panels.dart';
import 'package:mambo/theme/app_theme.dart';

const _stop = WalkStop(index: 0, name: '附近公园', position: GeoPoint(22, 114));
const _photoStop = WalkStop(index: 1, name: '老街', description: '一条安静的老街',
  position: GeoPoint(22, 114), photoUrls: ['https://example.com/a.jpg']);
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
      // A bounded screen, as on the walk page: cards never scroll as a whole.
      child: Scaffold(body: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(alignment: Alignment.topCenter, child: child),
      )),
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
  testWidgets('a tapped stop shows distance and walking time, with no order', (tester) async {
    await _pump(tester, StopCard(stop: _stop, distanceMeters: 320, onClose: _nothing));
    expect(find.text('附近公园'), findsOneWidget);
    expect(find.text('320 米 · 步行约 4 分钟'), findsOneWidget);
    expect(find.textContaining('下一站'), findsNothing);
    expect(find.textContaining('第'), findsNothing);
    await _pump(tester, const StopCard(stop: _stop, onClose: _nothing));
    expect(find.text('正在定位…'), findsOneWidget);
    await _pump(tester, const StopCard(stop: _stop, distanceMeters: 4, onClose: _nothing));
    expect(find.text('10 米 · 就在附近'), findsOneWidget);
  });

  testWidgets('check-in takes precedence over directions and calls the action', (tester) async {
    var checkedIn = 0;
    var navigated = 0;
    await _pump(tester, StopCard(stop: _stop, canCheckIn: true, onClose: _nothing,
      onCheckIn: () => checkedIn++, onNavigate: () => navigated++));
    expect(find.text('导航'), findsNothing);
    expect(tester.getSize(find.widgetWithText(FilledButton, '我到了')).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('我到了'));
    expect(checkedIn, 1);
    await _pump(tester, StopCard(stop: _stop, onClose: _nothing, onNavigate: () => navigated++));
    expect(tester.getSize(find.widgetWithText(OutlinedButton, '导航')).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('导航'));
    expect(navigated, 1);
  });

  testWidgets('a reached stop says so and offers no action', (tester) async {
    await _pump(tester, StopCard(stop: _stop, reached: true, canCheckIn: true,
      distanceMeters: 10, onClose: _nothing, onCheckIn: _nothing, onNavigate: _nothing));
    expect(find.text('已到达'), findsOneWidget);
    expect(find.byType(ButtonStyleButton), findsNothing);
  });

  testWidgets('close, report and photos call back; blank names have a fallback', (tester) async {
    var closed = 0;
    var reported = 0;
    var photos = 0;
    await _pump(tester, StopCard(stop: _photoStop, onClose: () => closed++,
      onReport: () => reported++, onShowPhotos: () => photos++));
    expect(find.text('一条安静的老街'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.tap(find.byTooltip('报告这个地点'));
    await tester.tap(find.byTooltip('看看照片'));
    expect([closed, reported, photos], [1, 1, 1]);
    await _pump(tester, StopCard(stop: _stop, onClose: _nothing, onShowPhotos: _nothing));
    expect(find.byTooltip('看看照片'), findsNothing);
    await _pump(tester, const StopCard(
      stop: WalkStop(index: 2, name: '', position: GeoPoint(0, 0)), onClose: _nothing));
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

  testWidgets('a long task scrolls inside its card; header and camera stay put', (tester) async {
    final longTask = WalkTask(description: '长' * 300, photosRequired: 3);
    await _pump(tester, MapPanel(child: _taskCard(task: longTask)));
    final scroller = find.descendant(
      of: find.byType(TaskCard), matching: find.byType(SingleChildScrollView));
    expect(scroller, findsOneWidget);
    final state = tester.state<ScrollableState>(
      find.descendant(of: scroller, matching: find.byType(Scrollable)));
    expect(state.position.maxScrollExtent, greaterThan(0));
    final header = tester.getTopLeft(find.text('拍摄任务'));
    final camera = tester.getRect(find.widgetWithText(FilledButton, '拍任务照片'));
    await tester.drag(scroller, const Offset(0, -80));
    await tester.pump();
    expect(state.position.pixels, greaterThan(0));
    expect(tester.getTopLeft(find.text('拍摄任务')), header);
    expect(tester.getRect(find.widgetWithText(FilledButton, '拍任务照片')), camera);
  });

  testWidgets('a new task starts scrolled to its beginning', (tester) async {
    final longTask = WalkTask(description: '长' * 300, photosRequired: 3);
    await _pump(tester, MapPanel(child: _taskCard(task: longTask)));
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -80));
    await tester.pump();
    await _pump(tester, MapPanel(child: _taskCard(task: WalkTask(description: '新' * 300))));
    final state = tester.state<ScrollableState>(find.descendant(
      of: find.byType(TaskCard), matching: find.byType(Scrollable)));
    expect(state.position.pixels, 0);
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

  testWidgets('large text and long stop and task fit a 360x640 phone without scrolling the panel', (tester) async {
    final longStop = WalkStop(index: 0, name: '长' * 40, description: '长' * 200,
      position: const GeoPoint(22, 114), photoUrls: const ['https://example.com/a.jpg']);
    final longTask = WalkTask(description: '长' * 150, photosRequired: 3);
    // The bottom of the walk page: the panel takes what is left above the
    // action bar, and only the texts inside the cards give way.
    await _pump(tester, Column(children: [
      const SizedBox(height: 120),
      Flexible(child: MapPanel(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: StopCard(stop: longStop, distanceMeters: 320,
          onClose: _nothing, onNavigate: _nothing, onReport: _nothing, onShowPhotos: _nothing)),
        const Divider(),
        Flexible(child: _taskCard(task: longTask, onReport: _nothing)),
      ]))),
      _actions(),
    ]), scale: 1.3);
    expect(tester.takeException(), isNull);
    const screen = Rect.fromLTWH(0, 0, 360, 640);
    for (final label in ['导航', '拍任务照片', '结束']) {
      final rect = tester.getRect(find.text(label));
      expect(screen.contains(rect.topLeft) && screen.contains(rect.bottomRight - const Offset(1, 1)),
        isTrue, reason: label);
    }
    expect(find.descendant(of: find.byType(StopCard), matching: find.byType(SingleChildScrollView)),
      findsOneWidget);
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
