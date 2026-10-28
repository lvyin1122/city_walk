import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/features/walk/domain/walk.dart';

/// A walk shaped like the backend's `walk` query result.
Map<String, dynamic> walkJson() => {
  'Id': 'walk-1',
  'userId': 'user-1',
  'totalDuration': 50,
  'title': 'Authentic Sham Shui Po Walk',
  'description': 'Hidden food gems within a 1 km radius.',
  'createdAt': '2026-10-07T06:30:00Z',
  'status': 'completed',
  'timeSpent': 4500,
  'distanceTraveled': 2.37,
  'userAddress': '1 Yen Chow Street, Sham Shui Po, Kowloon, Hong Kong',
  'locations': [
    {
      'name': 'Yen Chow Street Hawker Bazaar',
      'description': 'Street vendors.',
      'selected': true,
      'collected': true,
      'photoUrls': ['https://img.test/1.jpg', ''],
      'coordinates': {'latitude': 22.3303, 'longitude': 114.1602},
    },
    {
      'name': 'Golden Computer Arcade',
      'description': 'Electronics.',
      'selected': true,
      'collected': false,
      'photoUrls': null,
      'coordinates': {'latitude': 22.3312, 'longitude': 114.1623},
    },
    {
      'name': 'Apliu Street',
      'selected': false,
      'collected': false,
      'coordinates': {'latitude': '22.3296', 'longitude': '114.1634'},
    },
  ],
  'tasks': [
    {
      'description': '拍摄2张街头涂鸦',
      'photosRequired': 2,
      'photosFulfilled': 2,
      'status': 'completed',
      'images': [
        {'url': 'https://img.test/t1.jpg'},
        {'url': 'https://img.test/t2.jpg'},
      ],
    },
    {
      'description': '找一家老字号',
      'photosRequired': 1,
      'photosFulfilled': 0,
      'status': 'in_progress',
    },
  ],
  'favoriteLocations': [
    {'latitude': 22.3305, 'longitude': 114.1610, 'photoUrl': 'https://img.test/s1.jpg'},
  ],
};

void main() {
  group('Walk.fromJson', () {
    test('reads the walk fields', () {
      final walk = Walk.fromJson(walkJson());

      expect(walk.id, 'walk-1');
      expect(walk.title, 'Authentic Sham Shui Po Walk');
      expect(walk.status, WalkStatus.completed);
      expect(walk.plannedMinutes, 50);
      expect(walk.timeSpent, const Duration(minutes: 75));
      expect(walk.distanceKm, 2.37);
      expect(walk.createdAt!.toUtc(), DateTime.utc(2026, 10, 7, 6, 30));
    });

    test('createdAt is shown in device time', () {
      final walk = Walk.fromJson(
        walkJson()..['createdAt'] = '2026-10-07T06:30:00+00:00',
      );

      expect(walk.createdAt!.isUtc, isFalse);
      expect(walk.createdAt!.toUtc(), DateTime.utc(2026, 10, 7, 6, 30));
    });

    test('reads task progress the backend now fills in', () {
      final walk = Walk.fromJson(
        walkJson()
          ..['tasks'] = [
            {
              'createdTime': '2026-10-07T06:40:00+00:00',
              'description': 'Photograph a doorway',
              'photosRequired': 3,
              'photosFulfilled': 1,
              'status': 'in_progress',
            },
          ],
      );

      final task = walk.tasks.single;
      expect(task.photosRequired, 3);
      expect(task.photosFulfilled, 1);
      expect(task.isCompleted, isFalse);
    });

    test('accepts a lower-case id as well', () {
      final json = walkJson()
        ..remove('Id')
        ..['id'] = 'walk-2';
      expect(Walk.fromJson(json).id, 'walk-2');
    });

    test('numbers the stops by their position in the backend list', () {
      final walk = Walk.fromJson(walkJson());

      expect(walk.stops.map((stop) => stop.index), [0, 1, 2]);
      expect(walk.stops[0].position, const GeoPoint(22.3303, 114.1602));
      // Coordinates sent as strings still parse.
      expect(walk.stops[2].position, const GeoPoint(22.3296, 114.1634));
    });

    test('a stop without coordinates is dropped but keeps the others indexed', () {
      final json = walkJson();
      (json['locations'] as List)[1] = {'name': 'Nowhere', 'selected': true};

      final walk = Walk.fromJson(json);

      expect(walk.stops.map((stop) => stop.name), [
        'Yen Chow Street Hawker Bazaar',
        'Apliu Street',
      ]);
      // The index sent back to the backend must be the original position.
      expect(walk.stops.map((stop) => stop.index), [0, 2]);
    });

    test('derives the summary numbers', () {
      final walk = Walk.fromJson(walkJson());

      expect(walk.selectedStops, hasLength(2));
      expect(walk.collectedStops, hasLength(1));
      expect(walk.completedTaskCount, 1);
      expect(walk.surprises.single.photoUrl, 'https://img.test/s1.jpg');
    });

    test('drops empty photo URLs and collects task images', () {
      final walk = Walk.fromJson(walkJson());

      expect(walk.stops[0].photoUrls, ['https://img.test/1.jpg']);
      expect(walk.stops[1].photoUrls, isEmpty);
      expect(walk.tasks[0].imageUrls, hasLength(2));
      expect(walk.tasks[1].imageUrls, isEmpty);
    });

    test('a freshly generated walk has no progress yet', () {
      final walk = Walk.fromJson({
        'Id': 'walk-3',
        'title': 'New',
        'totalDuration': '30',
        'locations': <dynamic>[],
      });

      expect(walk.plannedMinutes, 30);
      expect(walk.timeSpent, isNull);
      expect(walk.distanceKm, isNull);
      expect(walk.createdAt, isNull);
      expect(walk.stops, isEmpty);
      expect(walk.tasks, isEmpty);
      expect(walk.surprises, isEmpty);
    });
  });
}
