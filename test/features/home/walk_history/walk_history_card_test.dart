import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/features/home/walk_history/walk_history.dart';
import 'package:mambo/features/walk/domain/walk.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, Walk walk) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: WalkHistoryCard(walk: walk))),
    );
  }

  const position = GeoPoint(22.33, 114.16);

  testWidgets('shows the walk title, real duration, distance and counts', (
    tester,
  ) async {
    await pumpCard(
      tester,
      Walk(
        id: 'w1',
        title: 'Authentic Sham Shui Po Walk',
        createdAt: DateTime.utc(2026, 10, 7, 6, 30),
        timeSpent: const Duration(minutes: 75),
        distanceKm: 2.37,
        userAddress: '1 Yen Chow Street, Sham Shui Po, Kowloon, Hong Kong',
        stops: const [
          WalkStop(index: 0, name: 'A', position: position, selected: true, collected: true),
          WalkStop(index: 1, name: 'B', position: position, selected: true, collected: true),
          WalkStop(index: 2, name: 'C', position: position, selected: true),
        ],
        tasks: const [
          WalkTask(description: 't', status: 'completed'),
          WalkTask(description: 'u', status: 'in_progress'),
        ],
        surprises: const [SurpriseSpot(position: position, photoUrl: 'x')],
      ),
    );

    expect(find.text('Authentic Sham Shui Po Walk'), findsOneWidget);
    expect(find.text('Sham Shui Po, Kowloon'), findsOneWidget);
    // 75 minutes: the old formatter showed "75:00".
    expect(find.text('1:15:00'), findsOneWidget);
    expect(find.text('2.4 km'), findsOneWidget);
    // Collected stops, completed tasks, surprises.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
  });

  testWidgets('falls back gracefully when data is missing', (tester) async {
    await pumpCard(tester, const Walk(id: 'w2', plannedMinutes: 45));

    expect(find.text('城市漫步'), findsOneWidget);
    expect(find.text('45 分钟'), findsOneWidget);
    expect(find.text('--'), findsWidgets);
    expect(find.textContaining('null'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekday is shown in Chinese, not as an English abbreviation', (
    tester,
  ) async {
    await pumpCard(tester, Walk(id: 'w3', createdAt: DateTime(2026, 10, 8, 12)));

    // 8 October 2026 is a Thursday.
    expect(find.text('周四'), findsOneWidget);
    expect(find.text('10/8'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
  });
}
