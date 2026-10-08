import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mambo/core/api/api_client.dart';
import 'package:mambo/core/api/api_exception.dart';
import 'package:mambo/services/graphql_service.dart';

/// Builds a service whose backend answers every request with [data] and
/// records the GraphQL documents and variables it was sent.
({GraphQLService service, List<Map<String, dynamic>> requests}) fakeBackend(
  Map<String, dynamic> data, {
  List<Map<String, dynamic>>? errors,
}) {
  final requests = <Map<String, dynamic>>[];
  final client = ApiClient(
    endpoint: Uri.parse('https://backend.test/graphql'),
    httpClient: MockClient((request) async {
      requests.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response.bytes(
        utf8.encode(jsonEncode({'data': data, 'errors': ?errors})),
        200,
      );
    }),
  );
  return (service: GraphQLService(client: client), requests: requests);
}

void main() {
  group('walk operations', () {
    test('keep the {data: ...} shape the walk pages read', () async {
      final backend = fakeBackend({
        'walk': {'Id': 'w1', 'status': 'in_progress'},
      });

      final result = await backend.service.getWalk(walkId: 'w1');

      expect(result['data']['walk']['Id'], 'w1');
    });

    test('a custom keyword containing a quote cannot break the query', () async {
      final backend = fakeBackend({
        'generateWalkWithGpt': {'walk': null},
      });

      await backend.service.generateWalk(
        userId: 'u1',
        location: '22.28, 114.15',
        keywords: ['🍽️ 美食', 'the "old" town'],
        duration: 45,
      );

      final document = backend.requests.single['query'] as String;
      expect(document, contains(r'keywords: "🍽️ 美食 the \"old\" town"'));
      expect(document, contains('duration: 45'));
      expect(document, contains('userId: "u1"'));
    });

    test('verifyTaskWithGpt sends coordinates as numbers when known', () async {
      final backend = fakeBackend({
        'verifyTaskWithGpt': {'success': true, 'message': 'ok'},
      });

      await backend.service.verifyTaskWithGpt(
        walkId: 'w1',
        imageUrl: 'https://img.test/a.jpg',
        latitude: 22.28,
        longitude: 114.15,
      );
      await backend.service.verifyTaskWithGpt(
        walkId: 'w1',
        imageUrl: 'https://img.test/a.jpg',
      );

      final withCoordinates = backend.requests[0]['query'] as String;
      final without = backend.requests[1]['query'] as String;
      expect(withCoordinates, contains('latitude: 22.28'));
      expect(withCoordinates, contains('longitude: 114.15'));
      expect(without, isNot(contains('latitude')));
    });

    test('selectLocations sends the indexes as a GraphQL list', () async {
      final backend = fakeBackend({
        'selectLocations': {'walk': null},
      });

      await backend.service.selectLocations(
        walkId: 'w1',
        locationIndexes: [0, 2, 5],
      );

      expect(
        backend.requests.single['query'] as String,
        contains('locationIndexes: [0, 2, 5]'),
      );
    });

    test('GraphQL errors surface as an exception, not as missing data', () async {
      final backend = fakeBackend(
        {'walk': null},
        errors: [
          {'message': 'Walk not found'},
        ],
      );

      await expectLater(
        backend.service.getWalk(walkId: 'missing'),
        throwsA(isA<ApiGraphQLException>()),
      );
    });
  });

  group('log operations', () {
    test('addLogEntry sends variables and omits coordinates it does not have', () async {
      final backend = fakeBackend({
        'addLogEntry': {
          'success': true,
          'log': {'id': 'log1', 'logEntries': <dynamic>[]},
        },
      });

      final result = await backend.service.addLogEntry(
        userId: 'u1',
        imageUrl: 'https://img.test/a.jpg',
        timestamp: '2026-10-08T10:00:00Z',
      );

      final variables = backend.requests.single['variables'] as Map;
      expect(variables['userId'], 'u1');
      expect(variables['timestamp'], '2026-10-08T10:00:00Z');
      expect(variables.containsKey('lat'), isFalse);
      expect(variables.containsKey('lng'), isFalse);
      expect(result['log']['id'], 'log1');
    });

    test('addLogEntry throws with the backend message when it reports failure', () async {
      final backend = fakeBackend({
        'addLogEntry': {'success': false, 'message': 'quota exceeded'},
      });

      await expectLater(
        backend.service.addLogEntry(userId: 'u1', imageUrl: 'x'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('quota exceeded'),
          ),
        ),
      );
    });

    test('updateReflectionAnswers only sends the answers that were given', () async {
      final backend = fakeBackend({
        'updateReflectionAnswers': {
          'log': {'id': 'log1'},
        },
      });

      final log = await backend.service.updateReflectionAnswers(
        logId: 'log1',
        overallAnswer: '很放松',
      );

      expect(backend.requests.single['variables'], {
        'logId': 'log1',
        'overallAnswer': '很放松',
      });
      expect(log, {'id': 'log1'});
    });

    test('addLogTrackingPoint returns the session points, skipping bad ones', () async {
      final backend = fakeBackend({
        'addLogTrackingPoint': {
          'success': true,
          'latestSession': [
            {'lat': 22.28, 'lng': 114.15},
            {'lat': '22.29', 'lng': '114.16'},
            {'lat': null, 'lng': 114.17},
          ],
        },
      });

      final points = await backend.service.addLogTrackingPoint(
        logId: 'log1',
        userId: 'u1',
        lat: 22.28,
        lng: 114.15,
        timestamp: '2026-10-08T10:00:00Z',
      );

      expect(points, hasLength(2));
      expect(points![1].latitude, 22.29);
      expect(points[1].longitude, 114.16);
    });

    test('addLogTrackingPoint returns null when the point was not accepted', () async {
      final backend = fakeBackend({
        'addLogTrackingPoint': {'success': false, 'latestSession': null},
      });

      expect(
        await backend.service.addLogTrackingPoint(
          logId: 'log1',
          userId: 'u1',
          lat: 1,
          lng: 2,
          timestamp: 't',
        ),
        isNull,
      );
    });

    test('generateLogScrapbookImage returns the URL only on success', () async {
      final ok = fakeBackend({
        'generateLogScrapbookImage': {'success': true, 'imageUrl': 'https://img.test/c.png'},
      });
      final failed = fakeBackend({
        'generateLogScrapbookImage': {'success': false, 'imageUrl': null},
      });

      expect(
        await ok.service.generateLogScrapbookImage(logId: 'l', userId: 'u'),
        'https://img.test/c.png',
      );
      expect(
        await failed.service.generateLogScrapbookImage(logId: 'l', userId: 'u'),
        isNull,
      );
    });
  });
}
