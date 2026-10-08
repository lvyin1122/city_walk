import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mambo/core/api/api_client.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/features/walk/data/walk_repository.dart';
import 'package:mambo/features/walk/domain/walk.dart';
import 'package:mambo/features/walk/walk_preview.dart';
import 'package:mambo/services/graphql_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('estimateWalkMinutes', () {
    const origin = GeoPoint(22.2800, 114.1580);
    // About 500 m north of the origin: 6 minutes at 5 km/h.
    const stop = WalkStop(index: 0, name: 'A', position: GeoPoint(22.2845, 114.1580));

    test('is zero without stops', () {
      expect(estimateWalkMinutes(origin, const []), 0);
    });

    test('adds walking time and ten minutes per stop', () {
      expect(estimateWalkMinutes(origin, [stop]), 16);
    });

    test('grows with every extra stop', () {
      const second = WalkStop(index: 1, name: 'B', position: GeoPoint(22.2890, 114.1580));
      expect(estimateWalkMinutes(origin, [stop, second]), 32);
    });
  });

  group('WalkRepository.getSummary', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    ({WalkRepository repository, int Function() calls}) repositoryWriting(
      List<String> stories,
    ) {
      var calls = 0;
      final client = ApiClient(
        endpoint: Uri.parse('https://backend.test/graphql'),
        httpClient: MockClient((request) async {
          final story = stories[calls++];
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'data': {
                  'generateWalkSummary': {'summary': story},
                },
              }),
            ),
            200,
          );
        }),
      );
      return (
        repository: WalkRepository(api: GraphQLService(client: client)),
        calls: () => calls,
      );
    }

    test('asks the backend once and then serves the same story', () async {
      final fake = repositoryWriting(['第一次写的故事', '第二次写的故事']);

      final first = await fake.repository.getSummary('walk-1');
      final second = await fake.repository.getSummary('walk-1');

      expect(first, '第一次写的故事');
      expect(second, '第一次写的故事');
      expect(fake.calls(), 1);
    });

    test('keeps a separate story per walk', () async {
      final fake = repositoryWriting(['walk one', 'walk two']);

      expect(await fake.repository.getSummary('walk-1'), 'walk one');
      expect(await fake.repository.getSummary('walk-2'), 'walk two');
    });

    test('does not cache an empty story, so a later attempt can succeed', () async {
      final fake = repositoryWriting(['', '现在写好了']);

      expect(await fake.repository.getSummary('walk-1'), '');
      expect(await fake.repository.getSummary('walk-1'), '现在写好了');
      expect(fake.calls(), 2);
    });
  });
}
