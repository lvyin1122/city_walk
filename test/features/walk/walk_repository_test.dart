import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mambo/core/api/api_client.dart';
import 'package:mambo/core/api/api_exception.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/features/walk/data/walk_repository.dart';
import 'package:mambo/services/graphql_service.dart';

import 'walk_model_test.dart' show walkJson;

/// A repository whose backend answers each request with the next entry of
/// [responses] (the GraphQL `data` object) and records the documents sent.
({WalkRepository repository, List<String> documents}) fakeRepository(
  List<Map<String, dynamic>?> responses,
) {
  final documents = <String>[];
  var call = 0;
  final client = ApiClient(
    endpoint: Uri.parse('https://backend.test/graphql'),
    httpClient: MockClient((request) async {
      documents.add((jsonDecode(request.body) as Map)['query'] as String);
      final data = responses[call++];
      return http.Response.bytes(utf8.encode(jsonEncode({'data': data})), 200);
    }),
  );
  return (
    repository: WalkRepository(api: GraphQLService(client: client)),
    documents: documents,
  );
}

void main() {
  test('generateWalk sends the origin and returns the walk', () async {
    final fake = fakeRepository([
      {
        'generateWalkWithGpt': {'walk': walkJson()},
      },
    ]);

    final walk = await fake.repository.generateWalk(
      userId: 'user-1',
      origin: const GeoPoint(22.3303, 114.1602),
      keywords: ['🍽️ 美食'],
      minutes: 50,
    );

    expect(walk.id, 'walk-1');
    expect(walk.stops, hasLength(3));
    expect(fake.documents.single, contains('location: "22.3303, 114.1602"'));
    expect(fake.documents.single, contains('duration: 50'));
  });

  test('generateWalk fails clearly when the backend returns no walk', () async {
    final fake = fakeRepository([
      {
        'generateWalkWithGpt': {'walk': null},
      },
    ]);

    await expectLater(
      fake.repository.generateWalk(
        userId: 'user-1',
        origin: const GeoPoint(0, 0),
        keywords: const [],
        minutes: 30,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('getCompletedWalks sorts newest first and puts undated walks last', () async {
    final fake = fakeRepository([
      {
        'completedWalksByUserId': [
          {'Id': 'old', 'createdAt': '2026-09-01T00:00:00Z'},
          {'Id': 'undated'},
          {'Id': 'new', 'createdAt': '2026-10-01T00:00:00Z'},
        ],
      },
    ]);

    final walks = await fake.repository.getCompletedWalks('user-1');

    expect(walks.map((walk) => walk.id), ['new', 'old', 'undated']);
  });

  test('getInProgressWalkId returns null when nothing is in progress', () async {
    final fake = fakeRepository([
      {'latestInProgressWalk': null},
      {
        'latestInProgressWalk': {'Id': 'walk-9'},
      },
    ]);

    expect(await fake.repository.getInProgressWalkId('user-1'), isNull);
    expect(await fake.repository.getInProgressWalkId('user-1'), 'walk-9');
  });

  test('startWalk marks the walk in progress, then selects the stops', () async {
    final fake = fakeRepository([
      {
        'updateWalkStatus': {'walk': null},
      },
      {
        'selectLocations': {'walk': null},
      },
    ]);

    await fake.repository.startWalk('walk-1', [0, 2]);

    expect(fake.documents[0], contains('status: "in_progress"'));
    expect(fake.documents[1], contains('locationIndexes: [0, 2]'));
  });

  test('abandonWalk moves the walk out of the in-progress state', () async {
    final fake = fakeRepository([
      {
        'updateWalkStatus': {'walk': null},
      },
    ]);

    await fake.repository.abandonWalk('walk-1');

    expect(fake.documents.single, contains('status: "pending"'));
  });

  test('getTrack, getSurprises and getTaskPhotoUrls skip malformed items', () async {
    final fake = fakeRepository([
      {
        'walkTracking': {
          'coordinates': [
            {'latitude': 22.33, 'longitude': 114.16},
            {'latitude': null, 'longitude': 114.16},
            {'latitude': 22.34, 'longitude': 114.17},
          ],
        },
      },
      {
        'getFavoriteLocations': {
          'favoriteLocations': [
            {'latitude': 22.33, 'longitude': 114.16, 'photoUrl': 'https://img.test/s.jpg'},
            {'photoUrl': 'https://img.test/no-position.jpg'},
          ],
        },
      },
      {
        'getAllTasksImages': {
          'images': [
            {'url': 'https://img.test/t.jpg'},
            {'url': null},
          ],
        },
      },
    ]);

    expect(await fake.repository.getTrack('walk-1'), hasLength(2));
    expect(await fake.repository.getSurprises('walk-1'), hasLength(1));
    expect(await fake.repository.getTaskPhotoUrls('walk-1'), ['https://img.test/t.jpg']);
  });

  test('backend failures surface as ApiException', () async {
    final fake = fakeRepository([null]);

    await expectLater(
      fake.repository.getWalk('walk-1'),
      throwsA(isA<ApiException>()),
    );
  });
}
