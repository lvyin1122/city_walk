import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mambo/core/api/api_client.dart';
import 'package:mambo/services/graphql_service.dart';
import 'package:mambo/services/log_service.dart';

Map<String, dynamic> logJson({String id = 'log-1'}) => {
  'id': id,
  'startTimestamp': '2026-10-07T02:00:00Z',
  'logEntries': [
    {
      'timestamp': '2026-10-07T02:10:00Z',
      'imageUrl': 'https://img.test/1.jpg',
      'reflectionText': '巷子里的猫',
      'question': '这里让你想起什么？',
      'lat': 22.28,
      'lng': '114.15',
      'address': '',
    },
    {'timestamp': 'not a date', 'imageUrl': 'https://img.test/bad.jpg'},
    {'timestamp': '2026-10-07T03:00:00Z', 'imageUrl': 'https://img.test/3.jpg'},
  ],
  'overallQuestion': '今天最难忘的是什么？',
  'quickReplies': ['街角', '', null, '海边'],
  'followUpQuestion': '',
  'overallAiSummary': '',
  'scrapbookImageUrl': 'https://img.test/cover.png',
  'logTracking': {
    'logId': id,
    'sessions': [
      {
        'points': [
          {'lat': 22.28, 'lng': 114.15, 'timestamp': '2026-10-07T02:00:00Z'},
          {'lat': null, 'lng': 114.16, 'timestamp': '2026-10-07T02:00:10Z'},
        ],
      },
      {'points': <dynamic>[]},
    ],
  },
};

void main() {
  group('Log.fromJson', () {
    test('reads entries, skipping those without a valid timestamp', () {
      final log = Log.fromJson(logJson());

      expect(log.entries, hasLength(2));
      // Ids keep the position in the backend list, including skipped ones.
      expect(log.entries.map((entry) => entry.id), ['log-1_0', 'log-1_2']);
      expect(log.entries.first.description, '巷子里的猫');
      expect(log.entries.first.lng, 114.15);
      expect(log.entries.first.address, isNull);
      expect(log.entries.last.description, isNull);
    });

    test('treats empty strings as absent', () {
      final log = Log.fromJson(logJson());

      expect(log.quickReplies, ['街角', '海边']);
      expect(log.overallAiSummary, isNull);
      expect(log.scrapbookImageUrl, 'https://img.test/cover.png');
    });

    test('keeps only tracking sessions and points that are usable', () {
      final tracking = Log.fromJson(logJson()).tracking!;

      expect(tracking.sessions, hasLength(1));
      expect(tracking.sessions.single.points, hasLength(1));
    });

    test('has no tracking when nothing usable was recorded', () {
      final json = logJson()..['logTracking'] = {'logId': 'x', 'sessions': <dynamic>[]};
      expect(Log.fromJson(json).tracking, isNull);
    });

    test('falls back to the legacy list of reflection questions', () {
      final json =
          logJson()
            ..['overallQuestion'] = ''
            ..['reflectionQuestions'] = [
              {'question': 'Q1', 'answer': 'A1'},
              {'question': 'Q2', 'answer': 'A2'},
            ];

      final log = Log.fromJson(json);

      expect(log.overallQuestion, 'Q1');
      expect(log.overallAnswer, 'A1');
      expect(log.followUpQuestion, 'Q2');
      expect(log.followUpAnswer, 'A2');
    });

    test('rejects a log without a start time', () {
      expect(
        () => Log.fromJson(logJson()..remove('startTimestamp')),
        throwsFormatException,
      );
      expect(Log.tryParse(logJson()..['startTimestamp'] = 'yesterday'), isNull);
    });
  });

  group('LogService', () {
    LogService serviceReturning(Map<String, dynamic> data, {String? userId = 'u1'}) {
      final client = ApiClient(
        endpoint: Uri.parse('https://backend.test/graphql'),
        httpClient: MockClient(
          (request) async => http.Response.bytes(
            utf8.encode(jsonEncode({'data': data})),
            200,
          ),
        ),
      );
      return LogService(
        api: GraphQLService(client: client),
        currentUserId: () => userId,
      );
    }

    test('getLogs returns newest first and skips unparsable logs', () async {
      final service = serviceReturning({
        'logs': [
          logJson(id: 'older')..['startTimestamp'] = '2026-10-01T00:00:00Z',
          {'id': 'broken'},
          logJson(id: 'newer'),
        ],
      });

      final logs = await service.getLogs();

      expect(logs.map((log) => log.id), ['newer', 'older']);
    });

    test('getLogs is empty when signed out', () async {
      final service = serviceReturning({'logs': [logJson()]}, userId: null);
      expect(await service.getLogs(), isEmpty);
    });

    test('getLogForReview returns null when there is no log for the date', () async {
      final service = serviceReturning({
        'getLogForReview': {'log': null},
      });
      expect(await service.getLogForReview('2026-10-07', 480), isNull);
    });
  });
}
